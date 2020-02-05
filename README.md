# ngs_pipe
Bioinformatics Pipelines and related scripts 

# RNA Pipeline
Currently the only pipeline in this package is the RNA pipeline (though pieces will work for others)

The basic workflow of this pipeline is as follows
* You start with paired R1/R2 fastq files. 
* If the fastq files contain mouse + human RNA you can run the `demoused` process to 'separate' those out
* You run the `fastq_to_ubam` process which takes the human fastq files through qc, adapter trimming (soft), and fastqc and outputs a unaligned bam
* If you have multiple fastq pairs for a single sample (say from multiple libraries or lanes) you can either:
  * Concatenate the fastq files together into one big R1 and one big R2 and put them back into S3
  * Or more appropriately, run them through `fastq_to_ubam` independeltly and join them into one ubam using the `merge_bams` process
* Once all this prep is done and you have a human, unaligned bam file of all the sequence for a sample process it using the `rna_master` pipeline   

## Install
All of these pipelines require an install of java (1.8+) and a download of cromwell to run.
To install java run. On most computer this should be installed by default. If not:
 * sudo yum install java-1.8.0-openjdk

Once you download the repo the scripts expect a python environment in /opt/venv and
cromwell to exist in opt/cromwell/cromwell.jar
Running the following script will download and set this up
 * bash install.sh

And docker needs to work. More advanced cromwell integration (AWS/SLURM) is covered separately. 
Look at workflow_options.json for current cluster/docker integration settings.

### S3 credentials
You need valid default S3 credentials for this system to work. On most systems you have default permissions. But you can also use aws config to manually get this to work.

Test by listing and copying from the buckets you'll be using for S3 inputs and outputs in the workflows!

## Run
All of the individual workflows run in the same fashion.
There are three files per workflow
* [WORKFLOW].slurm.sh - A wrapper script to run the workflow, can be run through slurm or locally
* [WORKFLOW].wdl - the actual Workflow Design Language file
* [WORKFLOW].inputs.json - a working example of the workflow input file

To run the workflow.
* Copy and edit your own [WORKFLOW].inputs.json file (can be named anything, one per workflow)
* To run on the local node
  * ```shell script
    java -jar /opt/cromwell/cromwell.jar run --options ../workflow_options.json --inputs [WOFKFLOW].inputs.json [WOFKFLOW].wdl
    ```
  * or more conveniently
    ```shell script
      [WOFKFLOW].slurm.sh fastq_to_ubam.wdl
    ```
* To run on the cluster
  * ```shell script
    sbatch [WOFKFLOW].slurm.sh [WOFKFLOW].inputs.json
    ```
* If you'd like to run a lot of them on the cluster you can do this (every .json file in the local dir)
    ```shell script
    for input in `echo *.json`; do sbatch path/to/[WORKFLOW]./slurm.sh ${input}; done
    ```
* Everything should be in the output_root (of the .json file) after it runs. You'll also have a cromwell-executions and 
cromwell-logs folder in the running dir after it finishes. 
* The user is responsible for cleaning up the cromwell-executions directory after a successful run. Note: This dir gets BIG as it contains all the intermediate files.
* You can regenerate the workflow inputs using the womtool.jar file in opt/cromwell/womtool.jar like so
    ```shell script
      java -jar ../opt/cromwell/womtool.jar inputs [WORKFLOW].wdl > new_inputs.json
    ```

## demoused
Using two S3 fastq inputs, split into human and mouse alignment pairs and copy both to s3 destination. 
The files will be named
* split_human_1.fq
* split_human_2.fq
* split_mouse_1.fq
* split_mouse_2.fq 
* bbsplit_refmap_stats.txt
* bbsplit_scaffold_stats.txt

So be sure to specify a new root so they don't collide with other runs (not sample specific named)

## fastq_processing
Quick WDL to QC fastq files then process them into unaligned bams. 
* Uses Default FastQC to pull fastq metrics while processing.

Output bam will always be named [SAMPLE].unmapped.marked.bam under the root

## merge_bams
Quick script to merge multiple unaligned bams into one file. Use to combine many bams from different read groups into one.
See the inputs.json for example syntax.

## rna_master
Currently a modified version of Broad's RnaSeq best practices. Added feature_counts, kallisto and a ton of picard metrics
to the pipeline. 

* Everything should be in the output_root after it runs
* Metrics will be under output_root/Metrics


# Utility Scripts

## gen_template_from_csv
Given a csv file with named columns and a template with template variables (e.g. ${VARIABLE})
Prints out a file per row of the csv with all the variables from the template replaced with that row's values
Run like so
```shell script
bin/gen_template_from_csv.py -t templates/fastq_to_ubam.template -i templates/example_fastq_to_ubam_planner.csv
```
Run with --help to see full options

## s3_bucket_list
Prints out a filtered s3 bucket.
Run like so
```shell script
bin/s3_bucket_list.sh --bucket cro-vendor.revolutionmedicines.com --prefix 'Champions' --suffix '.fastq.gz'
```
Run with --help to see full options

