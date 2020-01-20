#
# Author: Brad Sickler
# Description: Os operations
#

version 1.0

task s3_copy {
    input {
        String s3_path
        File s3_output = basename(s3_path)
    }

    command <<<
        aws s3 cp ~{s3_path} ~{s3_output}
    >>>

    output {
        File s3_out = s3_output
    }

}

task fs_copy {
    input {
        Array[String] Files
        String Destination
    }

    command <<<
        mkdir -p ~{Destination}
        mv ~{sep=' ' Files} ~{Destination}
    >>>

    output {
        Array[String] out = Files
    }
}