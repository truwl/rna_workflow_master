 #!/bin/bash

 sample=$1

 cmd="docker run -v `pwd`:`pwd` -v /revmed/ref:/revmed/ref -w /nfshome/bsickler/Projects/rna_vendor_compare/${sample} pkrusche/hap.py \
     /opt/hap.py/bin/hap.py WES_${sample}.multi_caller.somatic.vcf.gz ${sample}.unmapped.marked.variant_filtered.vcf.gz \
     -o vcf_compare -r /revmed/ref/ngs_pipe/rna/Homo_sapiens_assembly19_1000genomes_decoy.fasta"
 echo "Running ${cmd}"
 eval "${cmd}"