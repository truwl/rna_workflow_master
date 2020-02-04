#
# Author: Brad Sickler
# Description: Os operations
#

version 1.0

task gzip {
    input {
        File to_zip
    }

    command <<<
        gzip --force ~{to_zip}
    >>>

    output {
        File zipped = to_zip + '.gz'
    }
}



task s3_copy {
    input {
        String s3_path
    }

    command <<<
        aws s3 cp --no-progress ~{s3_path} ~{basename(s3_path)}
    >>>

    output {
        File s3_out = basename(s3_path)
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


task s3_push {
    # Should be called in a scatter function
    # https://github.com/openwdl/wdl/blob/master/versions/1.0/SPEC.md#scatter
    # E.g.
    # scatter(f in Files) {
          #  call s3_push{
                         # input:
                           # FileToPush=f
                           # DestinationRoot=destinationRoot
                         #}
    #}
    # If you want to do something with the outputs it'll be a String array from s3_push in this case
    input {
        File FileToPush
        String DestinationRoot
    }
    String FullDestination = DestinationRoot + "/" + basename(FileToPush)

    command <<<
        if [[ -d "~{FileToPush}" ]]; then
            aws s3 cp --no-progress --acl bucket-owner-full-control --recursive ~{FileToPush}  ~{FullDestination}
        else
            aws s3 cp --no-progress --acl bucket-owner-full-control ~{FileToPush}  ~{FullDestination}
        fi
    >>>

    output {
        String S3Path = FullDestination
    }
}

task s3_push_single {
    input {
        File FileToPush
        String Destination
    }

    command <<<
        if [[ -d "~{FileToPush}" ]]; then
            aws s3 cp --no-progress --acl bucket-owner-full-control --recursive ~{FileToPush}  ~{Destination}
        else
            aws s3 cp --no-progress --acl bucket-owner-full-control ~{FileToPush}  ~{Destination}
        fi
    >>>

    output {
        String S3Path = Destination
    }
}

task s3_push_files {
    input {
        Array[String] Files
        String Destination
    }

    command <<<
        for file in ~{sep=' ' Files}  ; do
            bn=$(basename $file)
            if [[ -d "${file}" ]]; then
                aws s3 cp --no-progress --acl bucket-owner-full-control --recursive $file ~{Destination}/${bn}
            else
                aws s3 cp --no-progress --acl bucket-owner-full-control $file ~{Destination}/${bn}
            fi
        done
    >>>

    output {
        Array[String] dest_root = Destination
    }
}
