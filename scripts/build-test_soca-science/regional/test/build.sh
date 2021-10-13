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
module load git
git lfs install

git clone -b release/stable-nightly https://github.com/JCSDA-internal/soca-science.git ${CRT_EXP_DIR}/soca-science

cd ${CRT_BUILD_DIR}

git clone -b release/stable-nightly https://github.com/JCSDA-internal/soca-science.git

source ${CRT_BUILD_DIR}/soca-science/configs/machine/machine.${MACHINE}
mkdir ./build
cd build

ecbuild --build=release -DBUILD_PYTHON_BINDINGS=ON -DMPIEXEC_EXECUTABLE="/opt/slurm/bin/srun" -DMPIEXEC_NUMPROC_FLAG="-n" -DBUILD_ECKIT=ON ../soca-science/bundle

