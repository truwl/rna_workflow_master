# ngs_pipe
Bioinformatics Pipelines and related scripts 
A lot of this is sourced from https://github.com/biowdl

## Install
All of these pipelines requre an install of java (1.8+) and a download of cromwell to run.
To install java run 
 * sudo yum install java-1.8.0-openjdk

Then download cromwell and womtool to opt/cromwell
 * bash pull_cromwell.sh

And docker needs to work. More advanced cromwell integration (AWS/SLURM) is covered separately.

## fastq_processing
Quick WDL to QC fastq files then process them into unaligned bams. 
* Uses Default FastQC outputs
* The cutadapt.wdl is a more full featured version of this but still in development.
  
To run
* Copy and edit your own fastq_to_ubam.inputs.json file
* sudo java -jar /opt/cromwell/cromwell-47.jar run --inputs fastq_to_ubam.inputs.json fastq_to_ubam.wdl
* Everything should be in the output_root after it runs

## rna-germline-variant-calling
Currently a modified version of Broad's RnaSeq best practices. In process


