#
# Subread: RNA read analysis package functions
#


task featureCounts_paired {
    input {
        File bam
        File gtf_annotation
        String output_counts
        String dockerImage
    }

    command {
        /usr/local/bin/featureCounts \
            -p \
            -a ${gtf_annotation} \
            -t exon \
            -g geneid \
            -o ${output_counts} \
            ${bam}
    }

    output {
        File OutputCounts = output_counts
    }

    runtime {
        docker: "rssbred/rnacocktail"
    }
}
