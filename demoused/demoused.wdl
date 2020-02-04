#
# Author: Brad Sickler
# Description: Pipeline that takes R1/R2 fastq's from illumina runs through bbsplit to seperate mouse from human
#

version 1.0

# demoused pipeline. Splits up R1/R2 fastqs into human and mouse components
import "../tasks/bbtools.wdl" as bbtools
import "../tasks/os_ops.wdl" as os_ops

workflow Demoused {
    input {
        String s3_read1_fastq
        String s3_read2_fastq
        File human_ref
        File mouse_ref
        String s3_output_root
    }

     call os_ops.s3_copy as s3_cp_r1 {
       input:
         s3_path = s3_read1_fastq
     }

     call os_ops.s3_copy as s3_cp_r2 {
       input:
         s3_path = s3_read2_fastq
     }

    call bbtools.BbSplitMouse as BbSplitMouse {
        input:
            fastq_r1 = s3_cp_r1.s3_out,
            fastq_r2 = s3_cp_r2.s3_out,
            human_ref = human_ref,
            mouse_ref = mouse_ref
    }

    # Compress things to save a TON of space
    call os_ops.gzip as gzip_human_r1 {
        input:
            to_zip=BbSplitMouse.HumanR1,
    }
    call os_ops.gzip as gzip_human_r2 {
        input:
            to_zip=BbSplitMouse.HumanR2
    }
    call os_ops.gzip as gzip_mouse_r1 {
        input:
            to_zip=BbSplitMouse.MouseR1
    }
    call os_ops.gzip as gzip_mouse_r2 {
        input:
            to_zip=BbSplitMouse.MouseR2
    }

    Array[File] demoused_outputs = [
        BbSplitMouse.ScaffoldStats,
        BbSplitMouse.ReferenceStats,
        gzip_human_r1.zipped,
        gzip_human_r2.zipped,
        gzip_mouse_r2.zipped,
        gzip_mouse_r2.zipped,
    ]

    scatter(of in demoused_outputs) {
        call os_ops.s3_push as metrics_push {
            input:
                FileToPush=of,
                DestinationRoot=s3_output_root
        }
    }

    output {
        File ScaffoldStats = BbSplitMouse.ScaffoldStats
        File ReferenceStats = BbSplitMouse.ReferenceStats
        File HumanR1 = gzip_human_r1.zipped
        File HumanR2 = gzip_human_r2.zipped
        File MouseR1 = gzip_mouse_r2.zipped
        File MouseR2 = gzip_mouse_r2.zipped
	}

}
