#!/bin/sh
#SBATCH --account=marine-cpu

# Required environment variables:
envars=()
envars+=("DATE")
envars+=("MACHINE")
envars+=("DOMAIN")
envars+=("CRT_DIR")
envars+=("BUILD_DIR")
envars+=("EXP_DIR")
envars+=("CRT_BUILD_DIR")
envars+=("CRT_EXP_DIR")

module purge

source ${CRT_BUILD_DIR}/soca-science/configs/machine/machine.${MACHINE}

if [[ ! -d ${CRT_EXP_DIR} ]]; then
   mkdir ${CRT_EXP_DIR}
fi

cd ${CRT_EXP_DIR}

cp ${CRT_DIR}/prep/${DOMAIN}/exp.config ./

if [[ "${DOMAIN}" == regional ]]; then
   cp -R /work/noaa/ng-godas/cbook/build-test_soca-science/${DOMAIN}/prep/cfg ./
fi

ln -s ./soca-science/scripts/workflow/cycle.sh .

# set the correct soca bin directory in  soca-science exp.config file."
sed -i.SEDBACKUP "s+SOCA_BIN_DIR.*+SOCA_BIN_DIR=${CRT_BUILD_DIR}/build/bin+" exp.config

./cycle.sh
