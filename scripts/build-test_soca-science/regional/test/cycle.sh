#!/bin/sh
#SBATCH --account=marine-cpu

module purge

cd /work/noaa/ng-godas/cbook/build-test_soca-science/

export DATE=$(date +'%Y%m%d')
export BUILD_DIR=/work/noaa/ng-godas/cbook/build-test_soca-science/builds/${DATE}
export MACHINE=orion.intel
source ${BUILD_DIR}/soca-science/configs/machine/machine.${MACHINE}

export EXP_DIR=/work/noaa/ng-godas/cbook/build-test_soca-science/regional/expdir
cd ${EXP_DIR}
mkdir ${DATE}
cd ${DATE}

cp /work/noaa/ng-godas/cbook/build-test_soca-science/regional/prep/exp.config ./
cp -R ${BUILD_DIR}/soca-science/ .
cp -R /work/noaa/ng-godas/cbook/build-test_soca-science/regional/prep/rst ./
cp -R /work/noaa/ng-godas/cbook/build-test_soca-science/regional/prep/cfg ./
ln -s ./soca-science/scripts/workflow/cycle.sh .

# set the correct soca bin directory in  soca-science exp.config file."
sed -i.SEDBACKUP "s+SOCA_BIN_DIR.*+SOCA_BIN_DIR=${BUILD_DIR}/build/bin+" exp.config

./cycle.sh
