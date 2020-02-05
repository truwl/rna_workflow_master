#!/usr/bin/python
import argparse
import os
import sys
import logging
import csv
from string import Template

__description__ = 'From a CSV generate multiple json input files (one per row) using a base template.'

logging.basicConfig()
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def create_argument_parser():
    """
    Parses the command line arguments.
    """
    default_output_dir = '.'
    parser = argparse.ArgumentParser(description=__description__)
    group1 = parser.add_argument_group("Analysis options")
    group1.add_argument("--csv", "-i", dest="csvFile", default='', type=str, required=True,
                        help="CSV file to read in. Must be comma seperated and top row is header row. Output files will use [first column].json as name!!")
    group1.add_argument("--force", "-f", dest="force", action="store_true", default=False,
                        help="Set to overwrite existing files.")
    group1.add_argument("--output-dir", "-o", dest="outDir", default=default_output_dir, type=str, required=False,
                        help=f"Directory to output all the template outputs into. Default: {default_output_dir}")
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

    if not os.path.isdir(parser_args.outDir):
        logger.error(f"Output directory doesn't exist!@#! : {parser_args.outDir}")

    return parser_args


def main(args):
    csv_file = args.csvFile
    force = args.force
    template_file = args.template
    out_dir = args.outDir

    with open(template_file, 'r') as t_fh:
        logger.debug(f"Loading template from : {template_file}")
        template_str = Template(t_fh.read())
        logger.debug(f"Reading in csv file : {csv_file}")
        with open(csv_file, 'r') as csv_fh:
            reader = csv.DictReader(csv_fh)
            first_row = reader.fieldnames[0]
            logger.debug(f"First row is : {first_row}")
            for row in reader:
                # Do a little sanity checking!
                for key in row.keys():
                    first_row_value = row[first_row]
                    output_file = os.path.join(out_dir, f"{first_row_value}.json")
                    if os.path.isfile(output_file) and not force:
                        logger.error(f"Existing file will be over written please delete if you want this BAILING : {output_file}")
                        sys.exit(2)
                    if row[key] is None:
                        logger.error(f"Found empty key {key} on row : {row[first_row]}")
                        sys.exit(2)

                logger.info(f"Writing out file for : {first_row_value} -> {output_file}")
                with open(output_file, 'w') as out_fh:
                    out_fh.write(template_str.substitute(row))


if __name__ == '__main__':
    args = create_argument_parser()
    main(args)