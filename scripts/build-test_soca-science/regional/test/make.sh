#!/bin/sh
#SBATCH --account=marine-cpu

# Required environment variables:
envars=()
envars+=("DATE")
envars+=("MACHINE")
envars+=("BUILD_DIR")
envars+=("EXP_DIR")
envars+=("CRT_BUILD_DIR")
envars+=("CRT_EXP_DIR")

module purge

source ${CRT_BUILD_DIR}/soca-science/configs/machine/machine.${MACHINE}
cd ${CRT_BUILD_DIR}/build

make -j12
