#!/usr/bin/python
import argparse
import os
import sys
import logging
import csv
from string import Template

__description__ = 'From a CSV generate multiple json input files (one per row) using a base template.'

logging.basicConfig()
logger = logging.getLogger(__name__)

def create_argument_parser():
    """
    Parses the command line arguments.
    """
    parser = argparse.ArgumentParser(description=__description__)
    group1 = parser.add_argument_group("Analysis options")
    group1.add_argument("--csv", "-i", dest="csvFile", default='', type=str, required=True,
                        help="CSV file to read in. Must be comma seperated and top row is header row. Output files will use [first column].json as name!!")
    group1.add_argument("--template", "-t", dest="template", default='', type=str, required=True,
                        help="Template file to use for generating")
    group1.add_argument("--verbose", "-v", dest="verbose", action="store_true", default=False,
                        help="Print out extra diagnostic information.")

    parser_args = parser.parse_args()

    if parser_args.verbose:
        logger.setLevel(logging.DEBUG)

    for file_path in [parser_args.csvFile, parser_args.template]:
        if not os.path.isfile(file_path):
            logger.error(f"Please provide a valid file path argument : {file_path}")
            sys.exit(2)

    return parser_args


def main(args):
    csv_file = args.csvFile
    template_file = args.template

    with open(template_file, 'r') as t_fobj:
        template_str = Template(t_fobj.read())
        with open(csv_file, 'r') as csv_fobj:
            reader = csv.DictReader(csv_fobj)
            for row in reader:
                print(row[0])


if __name__ == '__main__':
    args = create_argument_parser()
    main(args)