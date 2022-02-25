#!/bin/bash

export OPT=/discover/swdev/jcsda/modules
module use $OPT/modulefiles/apps
module use $OPT/modulefiles/core
module purge
module load jedi/gnu-impi/ecbuild35

# modules to only load during runtime
if [[ "$SOCA_SCIENCE_RUNTIME" == T ]]; then
    module load python/GEOSpyD/Min4.8.3_py3.8
    module load cdo
fi


ulimit -s unlimited

export MPIRUN=$(which mpirun)
export WORKLOAD_MANAGER=slurm
