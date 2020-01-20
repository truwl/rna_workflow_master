#
# Kallisto: RNA read count packager
#

version 1.0

task kallisto {
    input {
        File index
        File reads1
        File reads2
        Int? ncpu
        Int? memGB
    }

    command <<<
        kallisto quant \
            ~{"-i " + index} \
            -o out \
            --rf-stranded \
            ~{"-t " + ncpu} \
            ~{reads1} ~{reads2}
    >>>

    output {
        File abundances_tsv = glob("out/*.tsv")[0]
        File abundances_h5 = glob("out/*.h5")[0]
        File run_info = glob("out/run_info.json")[0]
    }

    runtime {
        docker: "quay.io/encode-dcc/kallisto:latest"
        cpu: select_first([ncpu,4])
        memory: "${select_first([memGB,8])} GB"
    }
}