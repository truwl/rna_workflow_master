version 1.0

import "../tasks/os_ops.wdl" as os_ops
import "../tasks/kallisto.wdl" as kallisto

workflow kallisto_quant {
    input {
         File index
         File reads1
         File reads2
         String? output_root = "kallisto_quant"
     }

     call os_ops.s3_copy as s3_cp_r1 {
       input:
         s3_path = reads1
     }

     call os_ops.s3_copy as s3_cp_r2 {
       input:
         s3_path = reads2
     }

     call kallisto.kallisto {
       input:
         index = index,
         reads1 = s3_cp_r1.s3_out,
         reads2 = s3_cp_r2.s3_out,
     }

     call os_ops.fs_copy {
       input:
         Files=[kallisto.abundances_tsv, kallisto.abundances_h5, kallisto.run_info],
         Destination=output_root
     }
}
