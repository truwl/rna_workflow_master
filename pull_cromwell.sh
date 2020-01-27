#!/bin/bash

OUT_DIR="opt/cromwell"
mkdir -p ${OUT_DIR}
wget -O "${OUT_DIR}/cromwell.jar" https://github.com/broadinstitute/cromwell/releases/download/48/cromwell-48.jar
wget -O "${OUT_DIR}/womtool.jar" https://github.com/broadinstitute/cromwell/releases/download/48/womtool-48.jar
