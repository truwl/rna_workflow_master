#!/bin/bash

SCRIPT_PATH=$(realpath $0)
BIN_DIR=`dirname ${SCRIPT_PATH} | head -n1`
WF_ROOT=`realpath ${BIN_DIR}/..`
SCRIPT_DIR="${WF_ROOT}/scripts"
PYTHON_BIN="${WF_ROOT}/opt/venv/bin/python"

SCRIPT_NAME="gen_template_from_csv.py"
SCRIPT="${SCRIPT_DIR}/${SCRIPT_NAME}"
eval ${PYTHON_BIN} ${SCRIPT} $@