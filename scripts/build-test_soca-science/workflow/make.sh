#!/bin/sh
#SBATCH --account=marine-cpu

module purge

source ${CRT_BUILD_DIR}/soca-science/configs/machine/machine.${MACHINE}
cd ${CRT_BUILD_DIR}/build

make -j12
