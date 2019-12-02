version 1.0
# Copyright 2018 Sequencing Analysis Support Core - Leiden University Medical Center

import "../tasks/subread.wdl" as subread

workflow FC {
    input {
        File bam
        File gtf_annotation
        String output_counts_file
        Map[String, String] dockerImages = {

        }
    }


    call fastqc.Fastqc as FastqcRead1 {
        input:
            seqFile = read1,
            outdirPath = outputDir + "/",
            dockerImage = dockerImages["fastqc"]
    }

    if (defined(read2)) {
        call fastqc.Fastqc as FastqcRead2 {
            input:
                seqFile = select_first([read2]),
                outdirPath = outputDir + "/",
                dockerImage = dockerImages["fastqc"]
        }
        String read2outputPath = outputDir + "/cutadapt_" + basename(select_first([read2]))
    }

    if (runAdapterClipping) {
        call cutadapt.Cutadapt as Cutadapt {
            input:
                read1 = read1,
                read2 = read2,
                read1output = outputDir + "/cutadapt_" + basename(read1),
                read2output = read2outputPath,
                adapter = select_all([adapterForward]),
                anywhere = contaminations,
                adapterRead2 = adapterReverseDefault,
                anywhereRead2 = if defined(read2) then contaminations else read2,
                reportPath = outputDir + "/" + readgroupName +  "_cutadapt_report.txt",
                dockerImage = dockerImages["cutadapt"]
        }

        call fastqc.Fastqc as FastqcRead1After {
            input:
                seqFile = Cutadapt.cutRead1,
                outdirPath = outputDir + "/",
                dockerImage = dockerImages["fastqc"]
        }

        if (defined(read2)) {
            call fastqc.Fastqc as FastqcRead2After {
                input:
                    seqFile = select_first([Cutadapt.cutRead2]),
                    outdirPath = outputDir + "/",
                    dockerImage = dockerImages["fastqc"]
            }
        }
    }

    output {
        File qcRead1 = if runAdapterClipping then select_first([Cutadapt.cutRead1]) else read1
        File? qcRead2 = if runAdapterClipping then Cutadapt.cutRead2 else read2
        File read1htmlReport = FastqcRead1.htmlReport
        File read1reportZip = FastqcRead1.reportZip
        File? read2htmlReport = FastqcRead2.htmlReport
        File? read2reportZip = FastqcRead2.reportZip
        File? read1afterHtmlReport = FastqcRead1After.htmlReport
        File? read1afterReportZip = FastqcRead1After.reportZip
        File? read2afterHtmlReport = FastqcRead2After.htmlReport
        File? read2afterReportZip = FastqcRead2After.reportZip
        File? cutadaptReport = Cutadapt.report
        Array[File] reports = select_all([
            read1htmlReport,
            read1reportZip,
            read2htmlReport,
            read2reportZip,
            read1afterHtmlReport,
            read1afterReportZip,
            read2afterHtmlReport,
            read2afterReportZip,
            cutadaptReport
            ])
    }
 }

