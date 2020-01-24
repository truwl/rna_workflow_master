version 1.0

task MarkIlluminaAdapters {
    input {
        File inputBam
        String picard_tmp
        String javaXmx = "8G"
    }
    String adapter_metrics_out = "mark_illumina_adapters_metrics.txt"

    command <<<
        java -Xmx~{javaXmx} -jar /usr/picard/picard.jar MarkIlluminaAdapters \
        INPUT=~{inputBam} \
        OUTPUT=~{basename(inputBam, ".bam")}.marked.bam \
        METRICS=~{adapter_metrics_out} \
        TMP_DIR=~{picard_tmp}
    >>>

    output {
        File adapter_metrics = adapter_metrics_out
        File marked_bam = basename(inputBam, ".bam") + ".marked.bam"
    }

    runtime {
        docker: 'broadinstitute/picard'
    }

}


task PicardFastqToUbam {
    input {
        File Read1Fastq     # First Read file of pair
        File Read2Fastq     # Second Read file of pair
        String SampleName   # Unique sample name. Output will be SampleName.bam
        String LibraryName  # Library name, unique
        String PlatformUnit # Usually run_barcode.lane e.g. H0164ALXX140820.2
        String ReadGroup    # Unique unique readgroup name
    }

    command <<<
    java -Xmx8G -jar /usr/picard/picard.jar FastqToSam \
        FASTQ=~{Read1Fastq} \
        FASTQ2=~{Read2Fastq} \
        OUTPUT=~{SampleName}.unmapped.bam \
        READ_GROUP_NAME=~{ReadGroup} \
        SAMPLE_NAME=~{SampleName} \
        LIBRARY_NAME=~{LibraryName} \
        PLATFORM_UNIT=~{PlatformUnit} \
        PLATFORM=illumina \
    >>>

    output {
        File uBAM = SampleName + ".unmapped.bam"
    }

    runtime {
        docker: 'broadinstitute/picard'
    }
}



task BgzipAndIndex {
    input {
        File inputFile
        String outputDir
        String type = "vcf"
        String dockerImage = "quay.io/biocontainers/tabix:0.2.6--ha92aebf_0"
    }

    String outputGz = outputDir + "/" + basename(inputFile) + ".gz"

    command <<<
        set -e
        mkdir -p $(dirname ~{outputGz})
        bgzip -c ~{inputFile} > ~{outputGz}
        tabix ~{outputGz} -p ~{type}
    >>>

    output {
        File compressed = outputGz
        File index = outputGz + ".tbi"
    }

    runtime {
       docker: dockerImage
    }
}

task Index {
    input {
        File bamFile
        String outputBamPath = basename(bamFile)
        String dockerImage = "quay.io/biocontainers/samtools:1.8--h46bd0b3_5"
    }

    # Select_first is needed, otherwise womtool validate fails.
    String bamIndexPath = sub(select_first([outputBamPath]), "\.bam$", ".bai")

    command <<<
        bash -c '
        set -e
        # Make sure outputBamPath does not exist.
        if [ ! -f ~{outputBamPath} ]
        then
            mkdir -p $(dirname ~{outputBamPath})
            ln ~{bamFile} ~{outputBamPath}
        fi
        samtools index ~{outputBamPath} ~{bamIndexPath}
        '
    >>>

    output {
        File indexedBam = outputBamPath
        File index =  bamIndexPath
    }

    runtime {
        docker: dockerImage
    }
}

task Merge {
    input {
        Array[File]+ bamFiles
        String outputBamPath = "merged.bam"
        Boolean force = true

        String dockerImage = "quay.io/biocontainers/samtools:1.8--h46bd0b3_5"
    }
    String indexPath = sub(outputBamPath, "\.bam$",".bai")

    command <<<
        set -e
        mkdir -p $(dirname ~{outputBamPath})
        samtools merge ~{true="-f" false="" force} ~{outputBamPath} ~{sep=' ' bamFiles}
        samtools index ~{outputBamPath} ~{indexPath}
    >>>

    output {
        File outputBam = outputBamPath
        File outputBamIndex = indexPath
    }

    runtime {
        docker: dockerImage
    }
}

task Markdup {
    input {
        File inputBam
        String outputBamPath

        String dockerImage = "quay.io/biocontainers/samtools:1.8--h46bd0b3_5"
    }

    command <<<
        set -e
        mkdir -p $(dirname ~{outputBamPath})
        samtools markdup ~{inputBam} ~{outputBamPath}
    >>>

    output {
        File outputBam = outputBamPath
    }

    runtime {
        docker: dockerImage
    }
}

task Flagstat {
    input {
        File inputBam
        String outputPath

        String dockerImage = "quay.io/biocontainers/samtools:1.8--h46bd0b3_5"
    }

    command <<<
        set -e
        mkdir -p $(dirname ~{outputPath})
        samtools flagstat ~{inputBam} > ~{outputPath}
    >>>

    output {
        File flagstat = outputPath
    }

    runtime {
        docker: dockerImage
    }
}

task Fastq {
    input {
        File inputBam
        String outputRead1
        String? outputRead2
        String? outputRead0
        Int? includeFilter
        Int? excludeFilter
        Int? excludeSpecificFilter
        Boolean? appendReadNumber
        Boolean? outputQuality
        Int? compressionLevel

        Int threads = 1
        Int memory = 1
        String dockerImage = "quay.io/biocontainers/samtools:1.8--h46bd0b3_5"
    }

    command <<<
        samtools fastq \
        ~{true="-1" false="-s" defined(outputRead2)} ~{outputRead1} \
        ~{"-2 " + outputRead2} \
        ~{"-0 " + outputRead0} \
        ~{"-f " + includeFilter} \
        ~{"-F " + excludeFilter} \
        ~{"-G " + excludeSpecificFilter} \
        ~{true="-N" false="-n" appendReadNumber} \
        ~{true="-O" false="" outputQuality} \
        ~{"-c " + compressionLevel} \
        ~{"--threads " + threads} \
        ~{inputBam}
    >>>

    output {
        File read1 = outputRead1
        File? read2 = outputRead2
        File? read0 = outputRead0
    }

    runtime {
        cpu: threads
        memory: memory
        docker: dockerImage
    }

    parameter_meta {
        inputBam: "The bam file to process."
        outputRead1: "If only outputRead1 is given '-s' flag is assumed. Else '-1'."
        includeFilter: "Include reads with ALL of these flags. Corresponds to '-f'"
        excludeFilter: "Exclude reads with ONE OR MORE of these flags. Corresponds to '-F'"
        excludeSpecificFilter: "Exclude reads with ALL of these flags. Corresponds to '-G'"
        appendReadNumber: "Append /1 and /2 to the read name, or don't. Corresponds to '-n/N"

    }
}

task Tabix {
    input {
        File inputFile
        String outputFilePath = "indexed.vcf.gz"
        String type = "vcf"
        String dockerImage = "quay.io/biocontainers/tabix:0.2.6--ha92aebf_0"
    }
    # FIXME: It is better to do the indexing on VCF creation. Not in a separate task. With file localization this gets hairy fast.
    command <<<
        set -e
        mkdir -p $(dirname ~{outputFilePath})
        if [ ! -f ~{outputFilePath} ]
        then
            ln ~{inputFile} ~{outputFilePath}
        fi
        tabix ~{outputFilePath} -p ~{type}
    >>>

    output {
        File indexedFile = outputFilePath
        File index = outputFilePath + ".tbi"
    }

    runtime {
       docker: dockerImage
    }
}

task View {
    input {
        File inFile
        File? referenceFasta
        String outputFileName = "view.bam"
        Boolean? uncompressedBamOutput
        Int? includeFilter
        Int? excludeFilter
        Int? excludeSpecificFilter
        Int? MAPQthreshold

        Int threads = 1
        Int memory = 1
        String dockerImage = "quay.io/biocontainers/samtools:1.8--h46bd0b3_5"
    }
    String outputIndexPath = basename(outputFileName) + ".bai"

    # Always output to bam and output header
    command <<<
        set -e
        mkdir -p $(dirname ~{outputFileName})
        samtools view -b \
        ~{"-T " + referenceFasta} \
        ~{"-o " + outputFileName} \
        ~{true="-u " false="" uncompressedBamOutput} \
        ~{"-f " + includeFilter} \
        ~{"-F " + excludeFilter} \
        ~{"-G " + excludeSpecificFilter} \
        ~{"-q " + MAPQthreshold} \
        ~{"--threads " + (threads - 1)} \
        ~{inFile}
        samtools index ~{outputFileName} ~{outputIndexPath}
    >>>

    output {
        File outputBam = outputFileName
        File outputBamIndex = outputIndexPath
    }

    runtime {
        cpu: threads
        memory: memory
        docker: dockerImage
    }
}
