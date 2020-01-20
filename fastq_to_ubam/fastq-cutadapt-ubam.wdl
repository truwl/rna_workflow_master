#
# Author: Brad Sickler
# Description: Pipeline that takes R1/R2 fastq's from illumina runs through, fastqc and to a final ubam output for pre-processing
#

version 1.0

# cutadapter pipeline Very low priority for RNA
import "../tasks/os_ops.wdl" as os_ops
import "../tasks/cutadapt.wdl" as cutadapt
import "../tasks/fastqc.wdl" as fastqc
import "../tasks/samtools.wdl" as samtools

workflow fastq_to_ubam {
    input {
        File read1_fastq
        File read2_fastq
        String sample_name
        String library_name
        String platform_unit
        String read_group
        String output_root
        String? adapterForward = "AGATCGGAAGAG"  # Illumina universal adapter
        String? adapterReverse = "AGATCGGAAGAG"  # Illumina universal adapter
    }

    call cutadapt.Cutadapt_Light as Cutadapt_Light {
        input:
            read1 = read1_fastq,
            read2 = read2_fastq,
    }

    call samtools.PicardFastqToUbam as PicardFastqToUbam {
        input:
            Read1Fastq=Cutadapt_Light.cutRead1,
            Read2Fastq=Cutadapt_Light.cutRead2,
            SampleName=sample_name,
            LibraryName=library_name,
            PlatformUnit=platform_unit,
            ReadGroup=read_group
    }

    call fastqc.Fastqc_Light as Fastqc_Light {
        input:
            Read1Fastq=read1_fastq,
            Read2Fastq=read2_fastq,
            OutDir=sample_name,
    }

    call os_ops.fs_copy {
        input:
            Files=[Cutadapt_Light.report, PicardFastqToUbam.uBAM, Fastqc_Light.rootDir],
            Destination=output_root
    }
}

