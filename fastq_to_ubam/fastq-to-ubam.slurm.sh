#!/bin/bash
#SBATCH --job-name=fastq_qc
#SBATCH --ntasks 4
#SBATCH --mail-type=END
#SBATCH --mail-user=brad.sickler@mode3consulting.com
#SBATCH -e fastq_qc.%j.err
#SBATCH -o fastq_qc.%j.out

set -e
set -u

if [ -n ${SLURM_JOB_ID} ] ; then
  SCRIPT_PATH=$(scontrol show job ${SLURM_JOBID} | awk -F= '/Command=/{print $2}')
else
  SCRIPT_PATH=$(realpath $0)
fi

SCRIPT_DIR=`dirname ${SCRIPT_PATH} | head -n1`
WDL="${SCRIPT_DIR}/fastq-to-ubam.wdl"
WF_ROOT=`realpath ${SCRIPT_DIR}/..`

JAVA_BIN="/usr/bin/java"
CROMWELL_ROOT="/revmed/user/bsickler/opt/cromwell"
WDL_OPTIONS="${WF_ROOT}/workflow_options.json"
CROMWELL_JAR="${CROMWELL_ROOT}/cromwell-47.jar"

INPUTS=$1

echo "Running in : ${SCRIPT_DIR}"
echo "Running on : `hostname`"


cromwell_cmd="${JAVA_BIN} -jar ${CROMWELL_JAR} run --options ${WDL_OPTIONS} --inputs ${INPUTS} ${WDL}"
echo ${cromwell_cmd}
eval ${cromwell_cmd}
