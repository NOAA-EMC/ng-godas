#!/bin/bash

export dir=/work/noaa/ng-godas/spaturi
export data=/work/noaa/da/Shastri.Paturi/CPC_reanalysis
export IODA=$dir/sandbox/20210711/build.intel/bin

export ADT=$data/adt.nesdis

export OUTPUT=/work/noaa/ng-godas/spaturi/ioda-v1
export OUT_v2=/work/noaa/ng-godas/spaturi/ioda-v2

source $dir/sandbox/20210711/soca-science/configs/machine/machine.orion.intel

if [[ $# -eq 0 ]] ; then
    echo 'usage: ioda_converter_adt_00z.sh cut_dtg (YYYYMMDD)'
    exit 1
fi

cut_dtg=$1

echo $cut_dtg'00'
prv_dtg=$(date -d "$cut_dtg -1 days" +%Y%m%d)
mkdir -p ${OUTPUT}/adt/${cut_dtg:0:4}/${cut_dtg}
mkdir -p ${OUT_v2}/adt/${cut_dtg:0:4}/${cut_dtg}

for fname in `ls $ADT/$cut_dtg`; do
    echo $fname
    sat=${fname:9:2}
    python ${IODA}/rads_adt2ioda.py \
           -i $ADT/$prv_dtg/rads_adt_${sat}_*.nc $ADT/$cut_dtg/rads_adt_${sat}_*.nc \
           -o ${OUTPUT}/adt/${cut_dtg:0:4}/${cut_dtg}/adt_${sat}_${cut_dtg}.nc -d ${cut_dtg}'00'
    ${IODA}/ioda-upgrade.x ${OUTPUT}/adt/${cut_dtg:0:4}/${cut_dtg}/adt_${sat}_${cut_dtg}.nc ${OUT_v2}/adt/${cut_dtg:0:4}/${cut_dtg}/adt_${sat}_${cut_dtg}.nc

done
#

