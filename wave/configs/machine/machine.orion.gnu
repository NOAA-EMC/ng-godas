#!/bin/bash
export JEDI_OPT=/work/noaa/da/grubin/opt/modules
module use $JEDI_OPT/modulefiles/core
module purge
module load jedi/gnu-openmpi/ecbuild35

# modules to only load during runtime
if [[ "$SOCA_SCIENCE_RUNTIME" == T ]]; then
    module unload python/3.7.5
    module use -a /work/noaa/da/kritib/soca-shared/modulefiles
    module load anaconda/2020.11
fi


ulimit -s unlimited

export MPIRUN=$(which srun)
export WORKLOAD_MANAGER=slurm
