#!/bin/bash
export JEDI_OPT=/work/noaa/da/jedipara/opt/modules
module use $JEDI_OPT/modulefiles/core
module purge
module load jedi/gnu-openmpi/10.2.0

. /work/noaa/da/kritib/soca-shared/soca_python-3.9/bin/activate

# modules to only load during runtime
if [[ "$SOCA_SCIENCE_RUNTIME" == T ]]; then
    module load nco/4.9.3
fi

ulimit -s unlimited

export MPIRUN=$(which srun)
export WORKLOAD_MANAGER=slurm
