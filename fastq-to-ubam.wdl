

workflow fastq_to_ubam {
    # TODO: Copying of FASTQC outputs to final output dir is a little finicky under cromwell. Fix this
    File read1_fastq
    File read2_fastq
    String sample_name
    String library_name
    String platform_unit
    String read_group
    String output_root

    call picard_fastq_to_ubam {
        input:
            Read1Fastq=read1_fastq,
            Read2Fastq=read2_fastq,
            SampleName=sample_name,
            LibraryName=library_name,
            PlatformUnit=platform_unit,
            ReadGroup=read_group
    }

    call fastqc {
        input:
            Read1Fastq=read1_fastq,
            Read2Fastq=read2_fastq,
            OutDir=sample_name,
    }

    call copy {
        input:
            Files=[picard_fastq_to_ubam.uBAM, fastqc.rootDir],
            Destination=output_root
    }
}

task fastqc {
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
        docker: "quay.io/biocontainers/fastqc:0.11.7--4"
    }
}

task picard_fastq_to_ubam {
    File Read1Fastq     # First Read file of pair
    File Read2Fastq     # Second Read file of pair
    String SampleName   # Unique sample name. Output will be SampleName.bam
    String LibraryName  # Library name, unique
    String PlatformUnit # Usually run_barcode.lane e.g. H0164ALXX140820.2
    String ReadGroup    # Unique unique readgroup name

    command {
    java -Xmx8G -jar /usr/picard/picard.jar FastqToSam \
        FASTQ=${Read1Fastq} \
        FASTQ2=${Read2Fastq} \
        OUTPUT=${SampleName}_fastqtosam.bam \
        READ_GROUP_NAME=${ReadGroup} \
        SAMPLE_NAME=${SampleName} \
        LIBRARY_NAME=${LibraryName} \
        PLATFORM_UNIT=${PlatformUnit} \
        PLATFORM=illumina \
    }
    output {
        File uBAM = "${SampleName}_fastqtosam.bam"
    }

    runtime {
        docker: 'broadinstitute/picard'
    }
}

task copy {
    Array[String] Files
    String Destination

    command {
        mkdir -p ${Destination}
        mv ${sep=' ' Files} ${Destination}
    }

    output {
        Array[String] out = Files
    }
}