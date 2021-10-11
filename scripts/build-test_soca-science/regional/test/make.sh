#!/bin/sh
#SBATCH --account=marine-cpu

module purge

export DATE=$(date +'%Y%m%d')
export BUILD_DIR=/work/noaa/ng-godas/cbook/build-test_soca-science/builds/${DATE}
export MACHINE=orion.intel
source ${BUILD_DIR}/soca-science/configs/machine/machine.${MACHINE}
cd ${BUILD_DIR}/build

make -j12
