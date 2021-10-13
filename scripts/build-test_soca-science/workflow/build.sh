#!/bin/sh
#SBATCH --account=marine-cpu

module purge
module load git
git lfs install

git clone -b ${SOCA_BRANCH}  ${CRT_EXP_DIR}/soca-science

cd ${CRT_BUILD_DIR}

git clone -b ${SOCA_BRANCH}

source ${CRT_BUILD_DIR}/soca-science/configs/machine/machine.${MACHINE}
mkdir ./build
cd build

ecbuild --build=release -DBUILD_PYTHON_BINDINGS=ON -DMPIEXEC_EXECUTABLE="/opt/slurm/bin/srun" -DMPIEXEC_NUMPROC_FLAG="-n" -DBUILD_ECKIT=ON ../soca-science/bundle

