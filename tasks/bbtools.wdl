#
# BBMap: RNA read analysis package functions
# https://jgi.doe.gov/data-and-tools/bbtools/
# https://www.biostars.org/p/143019/
#
# bbsplit.sh in1=reads1.fq in2=feads2.fq ref_x=hg19.fa ref_y=mm10.fa minratio=0.5 maxindel=100000 minhits=1 basename=o%_#.fq
#
version 1.0

task BbSplitMouse {
    input {
        File fastq_r1
        File fastq_r2
        File human_ref
        File mouse_ref
    }

    command <<<
        /usr/local/bin/bbsplit.sh \
            in1=~{fastq_r1} \
            in2=~{fastq_r2} \
            ref_human=~{human_ref} \
            ref_mouse=~{mouse_ref} \
            scafstats=bbsplit_scaffold_stats.txt \
            refstats=bbsplit_refmap_stats.txt \
            basename=split_%_#.fq.gz \
            maxindel=100000
    >>>

    output {
        File ScaffoldStats = "bbsplit_scaffold_stats.txt"
        File ReferenceStats = "bbsplit_refmap_stats.txt"
        File HumanR1 = "split_human_1.fq.gz"
        File HumanR2 = "split_human_2.fq.gz"
        File MouseR1 = "split_mouse_1.fq.gz"
        File MouseR2 = "split_mouse_2.fq.gz"
    }

    runtime {
        docker: "quay.io/biocontainers/bbmap:38.75--h516909a_0"
    }
}
