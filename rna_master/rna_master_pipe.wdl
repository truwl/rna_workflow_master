##
## Workflows for processing RNA data for germline short variant discovery with GATK (v4) and related tools
##
## Requirements/expectations :
## - BAM 
##
## Output :
## - A BAM file and its index.
## - A VCF file and its index. 
## - A Filtered VCF file and its index.
## - Tons of metrics
##

version 1.0

import "../tasks/gatk_tasks.wdl" as gatk
import "../tasks/kallisto.wdl" as kallisto
import "../tasks/picard.wdl" as picard
import "../tasks/subread.wdl" as subread
import "../tasks/os_ops.wdl" as os_ops
import "../tasks/multiqc.wdl" as multiqc

workflow RNAseq {
    input {
        String inputBamS3
        String sampleName = basename(inputBamS3,".bam")
        String sampleName = basename(sampleName,".unmapped.marked")
        String outputRootS3

        File refFasta
        File refFastaIndex
        File refDict

        String? gatk4_docker_override
        String gatk4_docker = select_first([gatk4_docker_override, "broadinstitute/gatk:latest"])
        String? gatk_path_override
        String gatk_path = select_first([gatk_path_override, "/gatk/gatk"])
        String? star_docker_override
        String star_docker = select_first([star_docker_override, "quay.io/humancellatlas/secondary-analysis-star:v0.2.2-2.5.3a-40ead6e"])

        Array[File] knownVcfs
        Array[File] knownVcfsIndices

        File dbSnpVcf
        File dbSnpVcfIndex
        Int? minConfidenceForVariantCalling

        ## Inputs for STAR
        Int? readLength
        File? zippedStarReferences
        File annotationsGTF

        ## Inputs for Kallisto
        File killistoIndex = "/revmed/ref/ngs_pipe/rna/kallisto/GRCh37_homo_sapiens/Homo_sapiens.GRCh37.75.cdna.all.idx"

        ## Optional user optimizations
        Int? haplotypeScatterCount
        Int scatterCount = select_first([haplotypeScatterCount, 6])

        Int? preemptible_tries
        Int preemptible_count = select_first([preemptible_tries, 3])
    }

	call gatk.gtfToCallingIntervals {
	    input:
	        gtf = annotationsGTF,
	        ref_dict = refDict,
	        preemptible_count = preemptible_count,
	        gatk_path = gatk_path,
	        docker = gatk4_docker
	}

	call os_ops.s3_copy as s3_bam_cp {
       input:
         s3_path = inputBamS3
    }

	call gatk.RevertSam {
		input:
			input_bam = s3_bam_cp.s3_out,
			base_name = sampleName + ".reverted",
			sort_order = "queryname",
			preemptible_count = preemptible_count,
			docker = gatk4_docker,
			gatk_path = gatk_path
	}

	call gatk.SamToFastq {
		input:
			unmapped_bam = RevertSam.output_bam,
			base_name = sampleName,
			preemptible_count = preemptible_count,
			docker = gatk4_docker,
			gatk_path = gatk_path
	}

	if (!defined(zippedStarReferences)) {
		call gatk.StarGenerateReferences {
			input:
				ref_fasta = refFasta,
				ref_fasta_index = refFastaIndex,
				annotations_gtf = annotationsGTF,
				read_length = readLength,
				preemptible_count = preemptible_count,
				docker = star_docker
		}
	}

	File starReferences = select_first([zippedStarReferences,StarGenerateReferences.star_genome_refs_zipped,""])
	call gatk.StarAlign {
		input: 
			star_genome_refs_zipped = starReferences,
			fastq1 = SamToFastq.fastq1,
			fastq2 = SamToFastq.fastq2,
			base_name = sampleName + ".star",
			read_length = readLength,
			preemptible_count = preemptible_count,
			docker = star_docker
	}

	call gatk.MergeBamAlignment {
		input: 
			unaligned_bam = RevertSam.output_bam,
			star_bam = StarAlign.output_bam,
			base_name = ".merged",
			ref_fasta = refFasta,
			ref_dict = refDict,
			preemptible_count = preemptible_count,
			docker = gatk4_docker,
			gatk_path = gatk_path
	}

	call gatk.MarkDuplicates {
		input:
			input_bam = MergeBamAlignment.output_bam,
			base_name = sampleName + ".dedupped",
			preemptible_count = preemptible_count,
			docker = gatk4_docker,
			gatk_path = gatk_path
	}

    call gatk.SplitNCigarReads {
        input:
            input_bam = MarkDuplicates.output_bam,
            input_bam_index = MarkDuplicates.output_bam_index,
            base_name = sampleName + ".split",
            ref_fasta = refFasta,
            ref_fasta_index = refFastaIndex,
            ref_dict = refDict,
            interval_list = gtfToCallingIntervals.interval_list,
            preemptible_count = preemptible_count,
            docker = gatk4_docker,
            gatk_path = gatk_path
    }

	call gatk.BaseRecalibrator {
		input:
			input_bam = SplitNCigarReads.output_bam,
			input_bam_index = SplitNCigarReads.output_bam_index,
			recal_output_file = sampleName + ".recal_data.csv",
  			dbSNP_vcf = dbSnpVcf,
  			dbSNP_vcf_index = dbSnpVcfIndex,
  			known_indels_sites_VCFs = knownVcfs,
  			known_indels_sites_indices = knownVcfsIndices,
  			ref_dict = refDict,
  			ref_fasta = refFasta,
  			ref_fasta_index = refFastaIndex,
  			preemptible_count = preemptible_count,
			docker = gatk4_docker,
			gatk_path = gatk_path
	}

	call gatk.ApplyBQSR {
		input:
			input_bam =  SplitNCigarReads.output_bam,
			input_bam_index = SplitNCigarReads.output_bam_index,
			base_name = sampleName + ".aligned.duplicates_marked.recalibrated",
			ref_fasta = refFasta,
			ref_fasta_index = refFastaIndex,
			ref_dict = refDict,
			recalibration_report = BaseRecalibrator.recalibration_report,
			preemptible_count = preemptible_count,
			docker = gatk4_docker,
			gatk_path = gatk_path
	}

    # After BQSR the bam is done. Launch everything relying on that (counts, metrics, etc)
     call kallisto.kallisto {
       input:
         index = killistoIndex,
         reads1 = SamToFastq.fastq1,
         reads2 = SamToFastq.fastq2,
     }

    call subread.FeatureCountsPaired {
        input:
            bam = ApplyBQSR.output_bam,
            gtf_annotation = annotationsGTF,
            sample_name = sampleName
    }

    call picard.CollectMultipleMetrics as picard_metrics {
        input:
            inputBam = ApplyBQSR.output_bam,
            inputBamIndex = ApplyBQSR.output_bam_index,
            referenceFasta = refFasta,
            basename = sampleName
    }

#    Array[File] multiqc_inputs = [
#        picard_metrics.alignmentSummary,
#        picard_metrics.baitBiasDetail,
#        picard_metrics.baitBiasSummary,
#        picard_metrics.baseDistributionByCycle,
#        picard_metrics.baseDistributionByCyclePdf,
#        picard_metrics.errorSummary,
#        picard_metrics.gcBiasDetail,
#        picard_metrics.gcBiasPdf,
#        picard_metrics.gcBiasSummary,
#        picard_metrics.insertSizeHistogramPdf,
#        picard_metrics.insertSize,
#        picard_metrics.preAdapterDetail,
#        picard_metrics.preAdapterSummary,
#        picard_metrics.qualityByCycle,
#        picard_metrics.qualityByCyclePdf,
#        picard_metrics.qualityDistribution,
#        picard_metrics.qualityDistributionPdf,
#        picard_metrics.qualityYield
#    ]
#    call multiqc.multiqc {
#        input:
#            multiqc_src_files = multiqc_inputs
#    }

    call gatk.ScatterIntervalList {
        input:
            interval_list = gtfToCallingIntervals.interval_list,
            scatter_count = scatterCount,
            preemptible_count = preemptible_count,
            docker = gatk4_docker,
            gatk_path = gatk_path
    }

	scatter (interval in ScatterIntervalList.out) {
        call gatk.HaplotypeCaller {
            input:
                input_bam = ApplyBQSR.output_bam,
                input_bam_index = ApplyBQSR.output_bam_index,
                base_name = sampleName + ".hc",
                interval_list = interval,
                ref_fasta = refFasta,
                ref_fasta_index = refFastaIndex,
                ref_dict = refDict,
                dbSNP_vcf = dbSnpVcf,
                dbSNP_vcf_index = dbSnpVcfIndex,
                stand_call_conf = minConfidenceForVariantCalling,
                preemptible_count = preemptible_count,
                docker = gatk4_docker,
                gatk_path = gatk_path
        }

		File HaplotypeCallerOutputVcf = HaplotypeCaller.output_vcf
		File HaplotypeCallerOutputVcfIndex = HaplotypeCaller.output_vcf_index
	}

    call gatk.MergeVCFs {
        input:
            input_vcfs = HaplotypeCallerOutputVcf,
            input_vcfs_indexes =  HaplotypeCallerOutputVcfIndex,
            output_vcf_name = sampleName + ".g.vcf.gz",
            preemptible_count = preemptible_count,
            docker = gatk4_docker,
            gatk_path = gatk_path
    }
	
	call gatk.VariantFiltration {
		input:
			input_vcf = MergeVCFs.output_vcf,
			input_vcf_index = MergeVCFs.output_vcf_index,
			base_name = sampleName + ".variant_filtered.vcf.gz",
			ref_fasta = refFasta,
			ref_fasta_index = refFastaIndex,
			ref_dict = refDict,
			preemptible_count = preemptible_count,
			docker = gatk4_docker,
			gatk_path = gatk_path
	}

    Array[File] OutputFiles = [
        ApplyBQSR.output_bam,
        ApplyBQSR.output_bam_index,
        MergeVCFs.output_vcf,
        MergeVCFs.output_vcf_index,
        VariantFiltration.output_vcf,
        VariantFiltration.output_vcf_index,
        kallisto.abundances_tsv,
        kallisto.abundances_h5,
        kallisto.run_info,
        FeatureCountsPaired.OutputCounts,
        FeatureCountsPaired.OutputCountsSummary,
        picard_metrics.alignmentSummary,
        picard_metrics.baitBiasDetail,
        picard_metrics.baitBiasSummary,
        picard_metrics.baseDistributionByCycle,
        picard_metrics.baseDistributionByCyclePdf,
        picard_metrics.errorSummary,
        picard_metrics.gcBiasDetail,
        picard_metrics.gcBiasPdf,
        picard_metrics.gcBiasSummary,
        picard_metrics.insertSizeHistogramPdf,
        picard_metrics.insertSize,
        picard_metrics.preAdapterDetail,
        picard_metrics.preAdapterSummary,
        picard_metrics.qualityByCycle,
        picard_metrics.qualityByCyclePdf,
        picard_metrics.qualityDistribution,
        picard_metrics.qualityDistributionPdf,
        picard_metrics.qualityYield,
        # multiqc.report,
        # multiqc.outdir,
    ]
    # This will copy them in a scatter gather fashion.
    scatter(of in OutputFiles) {
        call os_ops.s3_push{
            input:
                FileToPush=of,
                DestinationRoot=outputRootS3
        }
    }

	output {
		File recalibrated_bam = ApplyBQSR.output_bam
		File recalibrated_bam_index = ApplyBQSR.output_bam_index
		File merged_vcf = MergeVCFs.output_vcf
		File merged_vcf_index = MergeVCFs.output_vcf_index
		File variant_filtered_vcf = VariantFiltration.output_vcf
		File variant_filtered_vcf_index = VariantFiltration.output_vcf_index
        File kallisto_abundances_tsv = kallisto.abundances_tsv
        File kallisto_abundances_h5 = kallisto.abundances_h5
        File kallisto_run_info = kallisto.run_info
        File featureCountsPaired = FeatureCountsPaired.OutputCounts
        File outputCountsSummary = FeatureCountsPaired.OutputCountsSummary
        File alignmentSummary = picard_metrics.alignmentSummary
        File baitBiasDetail = picard_metrics.baitBiasDetail
        File baitBiasSummary = picard_metrics.baitBiasSummary
        File baseDistributionByCycle = picard_metrics.baseDistributionByCycle
        File baseDistributionByCyclePdf = picard_metrics.baseDistributionByCyclePdf
        File errorSummary = picard_metrics.errorSummary
        File gcBiasDetail = picard_metrics.gcBiasDetail
        File gcBiasPdf = picard_metrics.gcBiasPdf
        File gcBiasSummary = picard_metrics.gcBiasSummary
        File insertSizeHistogramPdf = picard_metrics.insertSizeHistogramPdf
        File insertSize = picard_metrics.insertSize
        File preAdapterDetail = picard_metrics.preAdapterDetail
        File preAdapterSummary = picard_metrics.preAdapterSummary
        File qualityByCycle = picard_metrics.qualityByCycle
        File qualityByCyclePdf = picard_metrics.qualityByCyclePdf
        File qualityDistribution = picard_metrics.qualityDistribution
        File qualityDistributionPdf = picard_metrics.qualityDistributionPdf
        File qualityYield = picard_metrics.qualityYield
#        File multiqcReport = multiqc.report
#        File multiqcOutdir = multiqc.outdir
	}
}
