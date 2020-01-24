version 1.0
# Copyright 2018 Sequencing Analysis Support Core - Leiden University Medical Center

import "../tasks/subread.wdl" as subread

workflow FC {
    input {
        File bam
        File gtf_annotation
        String sample_name
    }

    call subread.FeatureCountsPaired {
        input:
            bam = bam,
            gtf_annotation = gtf_annotation,
            sample_name = sample_name
    }

}

