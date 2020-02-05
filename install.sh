#!/bin/bash
set -e
set -u


# Check for an existing venv!
SCRIPT_PATH=`realpath $0`
SCRIPT_DIR=`dirname ${SCRIPT_PATH}`
REQUIREMENTS_FILE="${SCRIPT_DIR}/requirements.txt"
ENV_DEST="${SCRIPT_DIR}/opt/venv"
if [[ $# -gt 0 ]]; then
  ENV_DEST=`realpath ${1}`
  echo "Changing default venv dest to : ${ENV_DEST}"
  exit
fi

echo "SCRIPT DIR = ${SCRIPT_DIR}"
echo "ENV DEST = ${ENV_DEST}"

if [[ -d ${ENV_DEST} ]]; then
  echo "Found pre-existing venv in : ${ENV_DEST}"
  echo "I'm OUT!"
  exit
fi
if [[ ! -f ${REQUIREMENTS_FILE} ]]; then
  echo "Unable to find requirements file at : ${REQUIREMENTS_FILE}"
  echo "BAILING!@#!"
  exit
fi

# Install miniconda
echo "Getting miniconda"
MDEST="${SCRIPT_DIR}/miniconda.sh"
miniconda_get_cmd="wget https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ${MDEST}"
echo "Running : ${miniconda_get_cmd}"
eval ${miniconda_get_cmd}
echo "Installing miniconda"
miniconda_install_cmd="bash ${MDEST} -b -p ${ENV_DEST}"
echo "Running : ${miniconda_install_cmd}"
eval ${miniconda_install_cmd}
# Remove install file
rm -fr ${MDEST}

# Install requirements.txt
req_cmd="${ENV_DEST}/bin/conda install --yes --file ${REQUIREMENTS_FILE}"
echo "Running requirements install : ${req_cmd}"
eval ${req_cmd}

# Set the bin dir to executable
chmod a+x ${SCRIPT_DIR}/bin/*

# Pull in cromwwell
echo "Pulling in cromwell"
OUT_DIR="${SCRIPT_DIR}/opt/cromwell"
mkdir -p ${OUT_DIR}
wget -O "${OUT_DIR}/cromwell.jar" https://github.com/broadinstitute/cromwell/releases/download/48/cromwell-48.jar
wget -O "${OUT_DIR}/womtool.jar" https://github.com/broadinstitute/cromwell/releases/download/48/womtool-48.jar

