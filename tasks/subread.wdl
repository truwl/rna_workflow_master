#
# Subread: RNA read analysis package functions
#
version 1.0

task FeatureCountsPaired {
    input {
        File bam
        File gtf_annotation
        String sample_name
        String? output_counts = sample_name + ".feature_counts.txt"
    }

    command <<<
        /usr/local/bin/featureCounts \
            -p \
            -a ~{gtf_annotation} \
            -t exon \
            -g gene_id \
            -o ~{output_counts} \
            ~{bam}
    >>>

    output {
        File OutputCounts = output_counts
        File OutputCountsSummary = output_counts + ".summary"
    }

    runtime {
        docker: "rssbred/rnacocktail"
    }
}
