## Copyright Broad Institute, 2019
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
##
## Runtime parameters are optimized for Broad's Google Cloud Platform implementation.
## For program versions, see docker containers.
##
## LICENSING :
## This script is released under the WDL source code license (BSD-3) (see LICENSE in
## https://github.com/broadinstitute/wdl). Note however that the programs it calls may
## be subject to different licenses. Users are responsible for checking that they are
## authorized to run all programs before running this script. Please see the docker
## page at https://hub.docker.com/r/broadinstitute/genomes-in-the-cloud/ for detailed
## licensing information pertaining to the included programs. 
version 1.0

import "../tasks/gatk_tasks" as gatk

workflow RNAseq {
    input {
        File inputBam
        String sampleName = basename(inputBam,".bam")

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

	call gatk.RevertSam {
		input:
			input_bam = inputBam,
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

	output {
		File recalibrated_bam = ApplyBQSR.output_bam
		File recalibrated_bam_index = ApplyBQSR.output_bam_index
		File merged_vcf = MergeVCFs.output_vcf
		File merged_vcf_index = MergeVCFs.output_vcf_index
		File variant_filtered_vcf = VariantFiltration.output_vcf
		File variant_filtered_vcf_index = VariantFiltration.output_vcf_index
	}
}
