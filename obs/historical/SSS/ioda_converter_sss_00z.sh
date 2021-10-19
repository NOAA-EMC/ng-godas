#!/bin/bash

export dir=/work/noaa/ng-godas/spaturi
export data=/work/noaa/da/Shastri.Paturi/CPC_reanalysis
export IODA=$dir/sandbox/20210711/build.intel/bin

export SSS_SMOS=$data/SMOS_esa_L2
export SSS_SMAP=$data/SMAP_JPL_h5/L2

export OUTPUT=/work/noaa/ng-godas/spaturi/ioda-v1
export OUT_v2=/work/noaa/ng-godas/spaturi/ioda-v2

source $dir/sandbox/20210711/soca-science/configs/machine/machine.orion.intel

if [[ $# -eq 0 ]] ; then
    echo 'usage: ioda_converter_adt_sss_00z.sh cut_dtg (YYYYMMDD)'
    exit 1
fi

cut_dtg=$1

echo $cut_dtg
prv_dtg=$(date -d "$cut_dtg -1 days" +%Y%m%d)
echo $prv_dtg
#
mkdir -p ${OUTPUT}/sss/${cut_dtg:0:4}/${cut_dtg}
mkdir -p ${OUT_v2}/sss/${cut_dtg:0:4}/${cut_dtg}
#
for sat_typ in SMOS SMAP; do
    if [ $sat_typ == SMOS ]; then
       sat_dir=$SSS_SMOS
       ref=sss_smos.esa
       pyfile=smos_sss2ioda.py
    #fi
    #if [ $cut_dtg >= 20150401 ]; then  
    else
       sat_dir=$SSS_SMAP
       ref=sss_smap.jpl
       pyfile=smap_sss2ioda.py
    fi
    echo $sat_dir
    s="${IODA}/${pyfile} -i "
    for fname in `ls ${sat_dir}/${prv_dtg}/*_${prv_dtg}T{12..23}*`; do
       s+=" ${fname} "
    done
    for fname1 in `ls ${sat_dir}/${cut_dtg}/*_${cut_dtg}T{00..11}*`; do
       s+=" ${fname1} "
    done
    s+=" -o ${OUTPUT}/sss/${cut_dtg:0:4}/${cut_dtg}/${ref}_${cut_dtg}.nc -d ${cut_dtg}'00'"
    eval ${s}
    ${IODA}/ioda-upgrade.x ${OUTPUT}/sss/${cut_dtg:0:4}/${cut_dtg}/${ref}_${cut_dtg}.nc ${OUT_v2}/sss/${cut_dtg:0:4}/${cut_dtg}/${ref}_${cut_dtg}.nc
done
