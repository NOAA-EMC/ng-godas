#!/bin/sh
#SBATCH --account=marine-cpu

module purge
module load git
git lfs install

export DATE=$(date +'%Y%m%d')
mkdir /work/noaa/ng-godas/cbook/build-test_soca-science/builds/${DATE}
export BUILD_DIR=/work/noaa/ng-godas/cbook/build-test_soca-science/builds/${DATE}
cd ${BUILD_DIR}

git clone -b release/stable-nightly https://github.com/JCSDA-internal/soca-science.git

export MACHINE=orion.intel
source $BUILD_DIR/soca-science/configs/machine/machine.${MACHINE}
mkdir ./build
cd build

ecbuild --build=release -DBUILD_PYTHON_BINDINGS=ON -DMPIEXEC_EXECUTABLE="/opt/slurm/bin/srun" -DMPIEXEC_NUMPROC_FLAG="-n" -DBUILD_ECKIT=ON ../soca-science/bundle

