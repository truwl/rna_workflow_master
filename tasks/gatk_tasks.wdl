## Tasks for the GATK RNA Best practices pipeline split out an seperated from the main pipeline
version 1.0

task gtfToCallingIntervals {
    input {
        File gtf
        File ref_dict
        String output_name = basename(gtf, ".gtf") + ".exons.interval_list"
        String docker
        String gatk_path
        Int preemptible_count
    }

    command <<<
        Rscript --no-save -<<'RCODE'
            gtf = read.table("~{gtf}", sep="\t")
            gtf = subset(gtf, V3 == "exon")
            write.table(data.frame(chrom=gtf[,'V1'], start=gtf[,'V4'], end=gtf[,'V5']), "exome.bed", quote = F, sep="\t", col.names = F, row.names = F)
        RCODE

        awk '{print $1 "\t" ($2 - 1) "\t" $3}' exome.bed > exome.fixed.bed

        ~{gatk_path} \
            BedToIntervalList \
            -I=exome.fixed.bed \
            -O=~{output_name} \
            -SD=~{ref_dict}
    >>>

    output {
        File interval_list = output_name
    }

    runtime {
        docker: docker
        preemptible: preemptible_count
    }
}

# NOTE: assuming aggregated bams & paired end fastqs
task SamToFastq {
    input {
        File unmapped_bam
        String base_name
        String gatk_path
        String docker
        Int preemptible_count
    }

    command <<<
        ~{gatk_path} \
            SamToFastq \
                --INPUT ~{unmapped_bam} \
                --VALIDATION_STRINGENCY SILENT \
                --FASTQ ~{base_name}.1.fastq.gz \
                --SECOND_END_FASTQ ~{base_name}.2.fastq.gz
    >>>

    output {
        File fastq1 = base_name + ".1.fastq.gz"
        File fastq2 = base_name + ".2.fastq.gz"
    }

    runtime {
        docker: docker
        memory: "4 GB"
        preemptible: preemptible_count
    }
}

task StarGenerateReferences {
    input {
        File ref_fasta
        File ref_fasta_index
        File annotations_gtf
        Int? read_length  ## Should this be an input, or should this always be determined by reading the first line of a fastq input
        Int? num_threads
        Int threads = select_first([num_threads, 8])
        Int? additional_disk
        Int add_to_disk = select_first([additional_disk, 0])
        Int? mem_gb
        Int mem = select_first([100, mem_gb])
        String docker
        Int preemptible_count
    }

    command <<<
        set -e
        mkdir STAR2_5

        STAR \
        --runMode genomeGenerate \
        --genomeDir STAR2_5 \
        --genomeFastaFiles ~{ref_fasta} \
        --sjdbGTFfile ~{annotations_gtf} \
        ~{"--sjdbOverhang "+(read_length-1)} \
        --runThreadN ~{threads}

        ls STAR2_5

        tar -zcvf star-HUMAN-refs.tar.gz STAR2_5
    >>>

    output {
        Array[File] star_logs = glob("*.out")
        File star_genome_refs_zipped = "star-HUMAN-refs.tar.gz"
    }

    runtime {
        docker: docker
        cpu: threads
        memory: mem +" GB"
        preemptible: preemptible_count
    }
}


task StarAlign {
    input {
        File star_genome_refs_zipped
        File fastq1
        File fastq2
        String base_name
        Int? read_length
        Int? num_threads
        Int threads = select_first([num_threads, 8])
        Int? star_mem_max_gb
        Int star_mem = select_first([star_mem_max_gb, 45])
        #Is there an appropriate default for this?
        Int? star_limitOutSJcollapsed
        Int? additional_disk
        Int add_to_disk = select_first([additional_disk, 0])
        String docker
        Int preemptible_count
    }

    command <<<
        set -e

        mkdir STAR2_5

        tar -xvzf ~{star_genome_refs_zipped} -C STAR2_5 --strip-components=1

        STAR \
        --genomeDir STAR2_5 \
        --runThreadN ~{threads} \
        --readFilesIn ~{fastq1} ~{fastq2} \
        --readFilesCommand "gunzip -c" \
        ~{"--sjdbOverhang "+(read_length-1)} \
        --outSAMtype BAM SortedByCoordinate \
        --twopassMode Basic \
        --limitBAMsortRAM ~{star_mem+"000000000"} \
        --limitOutSJcollapsed ~{default=1000000 star_limitOutSJcollapsed} \
        --outFileNamePrefix ~{base_name}.
    >>>

    output {
        File output_bam = base_name + ".Aligned.sortedByCoord.out.bam"
        File output_log_final = base_name + ".Log.final.out"
        File output_log = base_name + ".Log.out"
        File output_log_progress = base_name + ".Log.progress.out"
        File output_SJ = base_name + ".SJ.out.tab"
    }

    runtime {
        docker: docker
        memory: (star_mem+1) + " GB"
        cpu: threads
        preemptible: preemptible_count
    }
}

task MergeBamAlignment {
    input {
        File ref_fasta
        File ref_dict
        File unaligned_bam
        File star_bam
        String base_name
        String gatk_path
        String docker
        Int preemptible_count
        #Using default for max_records_in_ram
    }

    command <<<
        ~{gatk_path} \
            MergeBamAlignment \
            --REFERENCE_SEQUENCE ~{ref_fasta} \
            --UNMAPPED_BAM ~{unaligned_bam} \
            --ALIGNED_BAM ~{star_bam} \
            --OUTPUT ~{base_name}.bam \
            --INCLUDE_SECONDARY_ALIGNMENTS false \
            --PAIRED_RUN False \
            --VALIDATION_STRINGENCY SILENT
    >>>

    output {
        File output_bam = base_name + ".bam"
    }

    runtime {
        docker: docker
        memory: "4 GB"
        preemptible: preemptible_count
    }
}

task MarkDuplicates {
    input {
        File input_bam
        String base_name
        String gatk_path
        String docker
        Int preemptible_count
    }

    command <<<
        ~{gatk_path} \
            MarkDuplicates \
            --INPUT ~{input_bam} \
            --OUTPUT ~{base_name}.bam  \
            --CREATE_INDEX true \
            --VALIDATION_STRINGENCY SILENT \
            --METRICS_FILE ~{base_name}.metrics
    >>>

     output {
         File output_bam = base_name + ".bam"
         File output_bam_index = base_name + ".bai"
         File metrics_file = base_name + ".metrics"
     }

    runtime {
        docker: docker
        memory: "4 GB"
        preemptible: preemptible_count
    }
}

task SplitNCigarReads {
    input {
        File input_bam
        File input_bam_index
        String base_name
        File interval_list

        File ref_fasta
        File ref_fasta_index
        File ref_dict

        String gatk_path
        String docker
        Int preemptible_count
    }

    command <<<
        ~{gatk_path} \
            SplitNCigarReads \
            -R ~{ref_fasta} \
            -I ~{input_bam} \
            -O ~{base_name}.bam
    >>>

    output {
        File output_bam = base_name + ".bam"
        File output_bam_index = base_name + ".bai"
    }

    runtime {
        docker: docker
        memory: "4 GB"
        preemptible: preemptible_count
    }
}

task BaseRecalibrator {
    input {
        File input_bam
        File input_bam_index
        String recal_output_file

        File dbSNP_vcf
        File dbSNP_vcf_index
        Array[File] known_indels_sites_VCFs
        Array[File] known_indels_sites_indices

        File ref_dict
        File ref_fasta
        File ref_fasta_index

        String gatk_path

        String docker
        Int preemptible_count
    }

    command <<<
        ~{gatk_path} --java-options "-XX:GCTimeLimit=50 -XX:GCHeapFreeLimit=10 -XX:+PrintFlagsFinal \
            -XX:+PrintGCTimeStamps -XX:+PrintGCDateStamps -XX:+PrintGCDetails \
            -Xloggc:gc_log.log -Xms4000m" \
            BaseRecalibrator \
            -R ~{ref_fasta} \
            -I ~{input_bam} \
            --use-original-qualities \
            -O ~{recal_output_file} \
            -known-sites ~{dbSNP_vcf} \
            -known-sites ~{sep=" --known-sites " known_indels_sites_VCFs}
    >>>

    output {
        File recalibration_report = recal_output_file
    }

    runtime {
        memory: "6 GB"
        docker: docker
        preemptible: preemptible_count
    }
}


task ApplyBQSR {
    input {
        File input_bam
        File input_bam_index
        String base_name
        File recalibration_report

        File ref_dict
        File ref_fasta
        File ref_fasta_index

        String gatk_path

        String docker
        Int preemptible_count
    }

    command <<<
        ~{gatk_path} \
            --java-options "-XX:+PrintFlagsFinal -XX:+PrintGCTimeStamps -XX:+PrintGCDateStamps \
            -XX:+PrintGCDetails -Xloggc:gc_log.log \
            -XX:GCTimeLimit=50 -XX:GCHeapFreeLimit=10 -Xms3000m" \
            ApplyBQSR \
            --add-output-sam-program-record \
            -R ~{ref_fasta} \
            -I ~{input_bam} \
            --use-original-qualities \
            -O ~{base_name}.bam \
            --bqsr-recal-file ~{recalibration_report}
    >>>

    output {
        File output_bam = base_name + ".bam"
        File output_bam_index = base_name + ".bai"
    }

    runtime {
        memory: "3500 MB"
        preemptible: preemptible_count
        docker: docker
    }
}

task HaplotypeCaller {
    input {
        File input_bam
        File input_bam_index
        String base_name

        File interval_list

        File ref_dict
        File ref_fasta
        File ref_fasta_index

        File dbSNP_vcf
        File dbSNP_vcf_index

        String gatk_path
        String docker
        Int preemptible_count

        Int? stand_call_conf
    }

    command <<<
        ~{gatk_path} --java-options "-Xms6000m -XX:GCTimeLimit=50 -XX:GCHeapFreeLimit=10" \
        HaplotypeCaller \
        -R ~{ref_fasta} \
        -I ~{input_bam} \
        -L ~{interval_list} \
        -O ~{base_name}.vcf.gz \
        -dont-use-soft-clipped-bases \
        --standard-min-confidence-threshold-for-calling ~{default=20 stand_call_conf} \
        --dbsnp ~{dbSNP_vcf}
    >>>

    output {
        File output_vcf = base_name + ".vcf.gz"
        File output_vcf_index = base_name + ".vcf.gz.tbi"
    }

    runtime {
        docker: docker
        memory: "6.5 GB"
        preemptible: preemptible_count
    }
}

task VariantFiltration {
    input {
        File input_vcf
        File input_vcf_index
        String base_name

        File ref_dict
        File ref_fasta
        File ref_fasta_index

        String gatk_path
        String docker
        Int preemptible_count
    }

    command <<<
        ~{gatk_path} \
            VariantFiltration \
            --R ~{ref_fasta} \
            --V ~{input_vcf} \
            --window 35 \
            --cluster 3 \
            --filter-name "FS" \
            --filter "FS > 30.0" \
            --filter-name "QD" \
            --filter "QD < 2.0" \
            -O ~{base_name}
    >>>

    output {
        File output_vcf = base_name
        File output_vcf_index = base_name + ".tbi"
    }

    runtime {
        docker: docker
        memory: "3 GB"
        preemptible: preemptible_count
    }
}

task MergeVCFs {
    input {
        Array[File] input_vcfs
        Array[File] input_vcfs_indexes
        String output_vcf_name
        String gatk_path
        String docker
        Int preemptible_count
    }

    # Using MergeVcfs instead of GatherVcfs so we can create indices
    # See https://github.com/broadinstitute/picard/issues/789 for relevant GatherVcfs ticket
    command <<<
        ~{gatk_path} --java-options "-Xms2000m"  \
            MergeVcfs \
            --INPUT ~{sep=' --INPUT=' input_vcfs} \
            --OUTPUT ~{output_vcf_name}
    >>>

    output {
        File output_vcf = output_vcf_name
        File output_vcf_index = output_vcf_name + ".tbi"
    }

    runtime {
        memory: "3 GB"
        docker: docker
        preemptible: preemptible_count
    }
}

task ScatterIntervalList {
    input {
        File interval_list
        Int scatter_count
        String gatk_path
        String docker
        Int preemptible_count
    }

    command <<<
        set -e
        mkdir out
        ~{gatk_path} --java-options "-Xms1g" \
            IntervalListTools \
            --SCATTER_COUNT=~{scatter_count} \
            --SUBDIVISION_MODE=BALANCING_WITHOUT_INTERVAL_SUBDIVISION_WITH_OVERFLOW \
            --UNIQUE=true \
            --SORT=true \
            --INPUT=~{interval_list} \
            --OUTPUT=out

        python3 <<CODE
        import glob, os
        # Works around a JES limitation where multiples files with the same name overwrite each other when globbed
        intervals = sorted(glob.glob("out/*/*.interval_list"))
        for i, interval in enumerate(intervals):
          (directory, filename) = os.path.split(interval)
          newName = os.path.join(directory, str(i + 1) + filename)
          os.rename(interval, newName)
        print(len(intervals))
        f = open("interval_count.txt", "w+")
        f.write(str(len(intervals)))
        f.close()
        CODE
    >>>

    output {
        Array[File] out = glob("out/*/*.interval_list")
        Int interval_count = read_int("interval_count.txt")
    }

    runtime {
        memory: "2 GB"
        docker: docker
        preemptible: preemptible_count
    }
}

task RevertSam {
    input {
        File input_bam
        String base_name
        String sort_order
        String gatk_path
        String docker
        Int preemptible_count
    }

    command <<<
        ~{gatk_path} \
            RevertSam \
            --INPUT ~{input_bam} \
            --OUTPUT ~{base_name}.bam \
            --VALIDATION_STRINGENCY SILENT \
            --ATTRIBUTE_TO_CLEAR FT \
            --ATTRIBUTE_TO_CLEAR CO \
            --SORT_ORDER ~{sort_order}
    >>>

    output {
        File output_bam = base_name + ".bam"
    }

    runtime {
        docker: docker
        memory: "4 GB"
        preemptible: preemptible_count
    }
}

