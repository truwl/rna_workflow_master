#
# MultiQC: This is a cool little quality aggregation module that parses output from one of the many QC programs into a condenses report
# Prototype method for now as I'm only using fastqc but as we add more this will be handy
# https://multiqc.info/

version 1.0

task multiqc {
    input {
        Array[File] multiqc_src_files
     }

    command <<<
        multiqc `pwd`
    >>>

    output {
        File report = "multiqc_report.html"
        File outdir = "multiqc_data"
    }

    runtime {
        docker: "ewels/multiqc"
    }
}
