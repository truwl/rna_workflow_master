#!/bin/bash
#SBATCH --job-name=rna_gatk
#SBATCH --ntasks 8
#SBATCH --mail-type=END
#SBATCH --mail-user=brad.sickler@mode3consulting.com
#SBATCH -e rna_master_pipe.%j.err
#SBATCH -o rna_master_pipe.%j.out

set -e
set -u

if [ -n ${SLURM_JOB_ID} ] ; then
  SCRIPT_PATH=$(scontrol show job ${SLURM_JOBID} | awk -F= '/Command=/{print $2}')
else
  SCRIPT_PATH=$(realpath $0)
fi

SCRIPT_DIR=`dirname ${SCRIPT_PATH} | head -n1`
WDL="${SCRIPT_DIR}/rna_master_pipe.wdl"
WF_ROOT=`realpath ${SCRIPT_DIR}/..`

JAVA_BIN="/usr/bin/java"
CROMWELL_ROOT="${WF_ROOT}/opt/cromwell"
WDL_OPTIONS="${WF_ROOT}/workflow_options.json"
CROMWELL_JAR="${CROMWELL_ROOT}/cromwell.jar"

INPUTS=$1

echo "Running in : ${SCRIPT_DIR}"
echo "Running on : `hostname`"

cromwell_cmd="${JAVA_BIN} -jar ${CROMWELL_JAR} run --options ${WDL_OPTIONS} --inputs ${INPUTS} ${WDL}"
echo ${cromwell_cmd}
eval ${cromwell_cmd}
