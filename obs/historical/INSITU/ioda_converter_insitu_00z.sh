#!/bin/bash

export D=/work/noaa/ng-godas/spaturi
export Dinsitu=$D/WOD_insitu
export IODA=$D/sandbox/20210711/build.intel/bin
source $D/sandbox/20210711/soca-science/configs/machine/machine.orion.intel

for dtg in 2015{07..08}{01..31} 201509{01..30} 201510{01..31} 201511{01..30} 201512{01..31}; do
    year=${dtg:0:4}
    mkdir -p $D/ioda-v1/insitu/${year}/${dtg}
    python ioda_converter_00z_insitu.py -idir $Dinsitu  -d ${dtg}'00' -out $D/ioda-v1/insitu/${year}/${dtg}/insitu_wod_${dtg}.nc
    mkdir -p $D/ioda-v2/insitu/${year}/${dtg}
    ${IODA}/ioda-upgrade.x $D/ioda-v1/insitu/${year}/${dtg}/insitu_wod_${dtg}.nc $D/ioda-v2/insitu/${year}/${dtg}/insitu_wod_${dtg}.nc

done




