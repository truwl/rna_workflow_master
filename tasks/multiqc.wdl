#
# MultiQC: This is a cool little quality aggregation module that parses output from one of the many QC programs into a condenses report
# Prototype method for now as I'm only using fastqc but as we add more this will be handy
# https://multiqc.info/


task multiqc {
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
        docker: "ewels/multiqc:v1.8"
    }
}
