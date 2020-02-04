#
# Author: Brad Sickler
# Description: Pipeline that takes R1/R2 fastq's from illumina runs through bbsplit to seperate mouse from human
#

version 1.0

# merge bam pipeline, merge multiple bams on S3 into one big one.
import "../tasks/os_ops.wdl" as os_ops
import "../tasks/samtools.wdl" as samtools

workflow MergeBams {
    input {
        Array[File] s3_bam_files
        String s3_output_bam
    }

    scatter(s3_bam in s3_bam_files) {
        call os_ops.s3_copy as s3_copy {
            input:
                s3_path = s3_bam
        }
    }
    # This should return s3_copy.s3_out - Array[Files]

    call samtools.MergeNoIndex as MergeNoIndex {
        input:
            bamFiles = s3_copy.s3_out
    }

    call os_ops.s3_push_single as s3_push_single {
        input:
            FileToPush = MergeNoIndex.outputBam,
            Destination = s3_output_bam
    }

    output {
        File OutputBam = s3_push_single.S3Path
	}
}
