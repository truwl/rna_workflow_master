#
# Author: Brad Sickler
# Description: Pipeline that takes R1/R2 fastq's from illumina runs through, fastqc and to a final ubam output for pre-processing
#

version 1.0

# cutadapter pipeline Very low priority for RNA
import "../tasks/os_ops.wdl" as os_ops
import "../tasks/fastqc.wdl" as fastqc
import "../tasks/samtools.wdl" as samtools


workflow FastqCutUbam {
    input {
        String s3_read1_fastq
        String s3_read2_fastq
        String sample_name
        String library_name
        String platform_unit
        String read_group
        String output_root
        String picard_tmp = '/tmp'
        String? adapterForward = "AGATCGGAAGAG"  # Illumina universal adapter
        String? adapterReverse = "AGATCGGAAGAG"  # Illumina universal adapter
    }

     call os_ops.s3_copy as s3_cp_r1 {
       input:
         s3_path = s3_read1_fastq
     }

     call os_ops.s3_copy as s3_cp_r2 {
       input:
         s3_path = s3_read2_fastq
     }

    call samtools.PicardFastqToUbam as PicardFastqToUbam {
        input:
            Read1Fastq=s3_cp_r1.s3_out,
            Read2Fastq=s3_cp_r2.s3_out,
            SampleName=sample_name,
            LibraryName=library_name,
            PlatformUnit=platform_unit,
            ReadGroup=read_group
    }

    call samtools.MarkIlluminaAdapters as MarkIlluminaAdapters {
        input:
            inputBam = PicardFastqToUbam.uBAM,
            picard_tmp = picard_tmp
    }

    call fastqc.Fastqc_Light as Fastqc_Light {
        input:
            Read1Fastq=s3_cp_r1.s3_out,
            Read2Fastq=s3_cp_r2.s3_out,
    }

    # This variable defines the output files that we're interested in keeping
    Array[File] OutputFiles = [MarkIlluminaAdapters.adapter_metrics, MarkIlluminaAdapters.marked_bam, Fastqc_Light.rootDir]
    # This will copy them in a scatter gather fashion.
    scatter(of in OutputFiles) {
        call os_ops.s3_push{
            input:
                FileToPush=of,
                DestinationRoot=output_root
        }
    }

    output {
		File adapter_metrics = MarkIlluminaAdapters.adapter_metrics
		File ubam = MarkIlluminaAdapters.marked_bam
		File fastqc_dir = Fastqc_Light.rootDir
	}

}

