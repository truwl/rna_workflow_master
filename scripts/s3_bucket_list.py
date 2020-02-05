#!/usr/bin/python
import argparse
import logging
import boto3

__description__ = 'From a bucket list the contents filtered by prefix and suffix.'

logging.basicConfig()
logger = logging.getLogger(__name__)

def create_argument_parser():
    """
    Parses the command line arguments.
    """
    default_output_dir = '.'
    parser = argparse.ArgumentParser(description=__description__)
    group1 = parser.add_argument_group("Options")
    group1.add_argument("--bucket", "-b", dest="bucket", default='', type=str, required=True,
                        help="s3 bucket to list out")
    group1.add_argument("--prefix", "-p", dest="prefix", default='', type=str, required=False,
                        help=f"Prefix to filter on.")
    group1.add_argument("--suffix", "-s", dest="suffix", default='', type=str, required=False,
                        help="Suffix to filter on")
    group1.add_argument("--verbose", "-v", dest="verbose", action="store_true", default=False,
                        help="Print out extra diagnostic information.")

    parser_args = parser.parse_args()

    if parser_args.verbose:
        logger.setLevel(logging.DEBUG)

    return parser_args


def get_matching_s3_keys(bucket, prefix='', suffix=''):
    """
    Generate the keys in an S3 bucket.

    :param bucket: Name of the S3 bucket.
    :param prefix: Only fetch keys that start with this prefix (optional).
    :param suffix: Only fetch keys that end with this suffix (optional).
    """
    s3 = boto3.client('s3')
    kwargs = {'Bucket': bucket}

    # If the prefix is a single string (not a tuple of strings), we can
    # do the filtering directly in the S3 API.
    if isinstance(prefix, str):
        kwargs['Prefix'] = prefix

    while True:

        # The S3 API response is a large blob of metadata.
        # 'Contents' contains information about the listed objects.
        resp = s3.list_objects_v2(**kwargs)
        for obj in resp['Contents']:
            key = obj['Key']
            if key.startswith(prefix) and key.endswith(suffix):
                yield key

        # The S3 API is paginated, returning up to 1000 keys at a time.
        # Pass the continuation token into the next response, until we
        # reach the final page (when this field is missing).
        try:
            kwargs['ContinuationToken'] = resp['NextContinuationToken']
        except KeyError:
            break


def main(args):
    bucket = args.bucket
    prefix = args.prefix
    suffix = args.suffix

    for key in get_matching_s3_keys(bucket=bucket, prefix=prefix, suffix=suffix):
        print(key)



if __name__ == '__main__':
    args = create_argument_parser()
    main(args)