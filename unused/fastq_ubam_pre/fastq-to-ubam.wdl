#
# Author: Brad Sickler
# Description: Pipeline that takes R1/R2 fastq's from illumina runs through, fastqc and to a final ubam output for pre-processing
#

#TODO: Make cutadapter optional. Very low priority for RNA
import "../tasks/os_ops.wdl" as os_ops
import "../tasks/cutadapt.wdl" as cutadapt
import "../tasks/fastqc.wdl" as fastqc
import "../tasks/samtools.wdl" as samtools

workflow FastqUbam {
    File read1_fastq
    File read2_fastq
    String sample_name
    String library_name
    String platform_unit
    String read_group
    String output_root

    call picard_fastq_to_ubam {
        input:
            Read1Fastq=read1_fastq,
            Read2Fastq=read2_fastq,
            SampleName=sample_name,
            LibraryName=library_name,
            PlatformUnit=platform_unit,
            ReadGroup=read_group
    }

    call fastqc {
        input:
            Read1Fastq=read1_fastq,
            Read2Fastq=read2_fastq,
            OutDir=sample_name,
    }

    call os_ops.fs_copy {
        input:
            Files=[picard_fastq_to_ubam.uBAM, fastqc.rootDir],
            Destination=output_root
    }
}

task fastqc {
    File Read1Fastq
    File Read2Fastq
    String OutDir

    command {
        mkdir -p ${OutDir}
        fastqc --extract \
            --outdir=${OutDir} \
            ${Read1Fastq} \
            ${Read2Fastq}
    }

    output {
        String rootDir = OutDir
    }

    runtime {
        docker: "quay.io/biocontainers/fastqc:0.11.7--4"
    }
}

task picard_fastq_to_ubam {
    File Read1Fastq     # First Read file of pair
    File Read2Fastq     # Second Read file of pair
    String SampleName   # Unique sample name. Output will be SampleName.bam
    String LibraryName  # Library name, unique
    String PlatformUnit # Usually run_barcode.lane e.g. H0164ALXX140820.2
    String ReadGroup    # Unique unique readgroup name

    command {
    java -Xmx8G -jar /usr/picard/picard.jar FastqToSam \
        FASTQ=${Read1Fastq} \
        FASTQ2=${Read2Fastq} \
        OUTPUT=${SampleName}.unmapped.bam \
        READ_GROUP_NAME=${ReadGroup} \
        SAMPLE_NAME=${SampleName} \
        LIBRARY_NAME=${LibraryName} \
        PLATFORM_UNIT=${PlatformUnit} \
        PLATFORM=illumina \
    }
    output {
        File uBAM = "${SampleName}.unmapped.bam"
    }

    runtime {
        docker: 'broadinstitute/picard'
    }
}

