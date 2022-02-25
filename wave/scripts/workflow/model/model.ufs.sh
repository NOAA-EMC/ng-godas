#!/bin/bash

# required environment variables:
envars=()
envars+=("FCST_RESTART")      # =1 if a restart file is used, otherwise T/S IC file is used
envars+=("FCST_START_TIME")   # start of forecast (in any appropriate "date" command format)
envars+=("MACHINE_CONFIG_FILE") # workflow/soca modules
envars+=("MODEL_CFG_DIR")     # UFS resource files & MOM data
envars+=("MODEL_DATA_DIR")    # path to input model static data (ocean_topo.nc, tideamp.nc, ...)
envars+=("MODEL_EXE")         # path to UFS executable
envars+=("MODEL_RES")         # Model resolution
envars+=("MODEL_RST_DIR_IN")  # path to restart files from previous cycle (if FCST_RESTART==1)
envars+=("MODEL_RST_DIR_OUT")
envars+=("BKGRST_ENS_DIR")
envars+=("JOB_NPES")
envars+=("FCST_LEN")
envars+=("FORC_SRC")
envars+=("FORC_GEN_SOURCE")
envars+=("SOCA_BIN_DIR")
envars+=("UFS_SCRATCH")
envars+=("UFS_INSTALL")
envars+=("UFS_MEDPETS")
envars+=("UFS_ATMPETS")
envars+=("UFS_OCNPETS")
envars+=("UFS_ICEPETS")
envars+=("DT_CICE")
envars+=("DATM_NAME")
envars+=("DATM_START_TYPE")

# make sure required env vars exist
set +u
for v in ${envars[@]}; do
    if [[ -z "${!v}" ]]; then
    echo "ERROR: env var $v is not set."; exit 1
    fi
    echo " $v = ${!v}"
done
set -u

# Calculated Variables:
export CDATE=$(date -ud "$FCST_START_TIME" +%Y%m%d%H)
export MDY=${CDATE:0:8}
export SYEAR=${CDATE:0:4}
export SMONTH=${CDATE:4:2}
export SDAY=${CDATE:6:2}
export SHOUR=${CDATE:8:2}

echo "$MODEL_RES"
if [[ "$MODEL_RES" == "0.25deg" ]]; then
   export NTASKS_TOT=${NTASKS_TOT:-"$(( $UFS_ATMPETS+$UFS_OCNPETS+$UFS_ICEPETS ))"}
else
   export NTASKS_TOT=${NTASKS_TOT:-"$(( $UFS_MEDPETS+$UFS_ATMPETS+$UFS_OCNPETS+$UFS_ICEPETS ))"}
fi

# prepare the working directory (which we assume we are already in)
mkdir -p OUTPUT

# output restarts
# TODO, make sure above this level that directory exists
mkdir -p $MODEL_RST_DIR_OUT
ln -s $MODEL_RST_DIR_OUT RESTART

# main configuration files
ln -sf $MODEL_CFG_DIR/* .
. input.nml.sh > input.nml
rm diag_table
rm MOM_input

# prepare resource files for ufs
cp -r $UFS_SCRATCH/* .
mv MOM_input_tmp MOM_input

# setup model files
sh $UFS_INSTALL/ufs_fcst_prep.sh

# load modules
module purge
source ./module-setup.sh
module use $( pwd -P )
module load modules.fv3
module load nco

# run ufs model
srun -n ${NTASKS_TOT} ${MODEL_EXE}

# move restart files to desired location
cp ./DATM_$FORC_GEN_SOURCE.cpl.r.*.nc $MODEL_RST_DIR_OUT
if [ "${DATM_NAME}" = "cdeps" ]; then
   cp ./DATM_$FORC_GEN_SOURCE.datm.r.*.nc $MODEL_RST_DIR_OUT
fi
cp  ./restart/* $MODEL_RST_DIR_OUT
hr2sec=$(printf "%05d" $((3600*$SHOUR)))
rm $MODEL_RST_DIR_OUT/iced.$SYEAR-$SMONTH-$SDAY-$hr2sec.nc
if [ "${DATM_START_TYPE}" = "continue" ]; then
   rm $MODEL_RST_DIR_OUT/DATM_$FORC_GEN_SOURCE.cpl.r.$SYEAR-$SMONTH-$SDAY-$hr2sec.nc
   if [ "${DATM_NAME}" = "cdeps" ]; then
      rm $MODEL_RST_DIR_OUT/DATM_$FORC_GEN_SOURCE.datm.r.$SYEAR-$SMONTH-$SDAY-$hr2sec.nc
   fi
fi
#mv ocn_* $MODEL_RST_DIR_OUT

#
if [[ "$MODEL_RES" == "0.25deg" ]]; then
    ncks -A -C -v ave_ssh,v $MODEL_RST_DIR_OUT/MOM.res_1.nc $MODEL_RST_DIR_OUT/MOM.res.nc
    ncks -A -C -v ave_ssh,v $MODEL_RST_DIR_IN/MOM.res_1.nc $MODEL_RST_DIR_IN/MOM.res.nc
   #tmp fix for letkf & 3dhyb cases
    if [[ -d "$BKGRST_ENS_DIR/${MODEL_RST_DIR_IN:(-3)}" ]]; then
        ncks -A -C -v ave_ssh,v $BKGRST_ENS_DIR/${MODEL_RST_DIR_IN:(-3)}/MOM.res_1.nc $BKGRST_ENS_DIR/${MODEL_RST_DIR_IN:(-3)}/MOM.res.nc
    fi
fi

# Create cice.res.nc (used as input to soca)
source $MACHINE_CONFIG_FILE
ice_rst=`ls $MODEL_RST_DIR_OUT/iced.*.nc`
$SOCA_BIN_DIR/soca_seaice.py -f $ice_rst \
                             -m cice \
                             -a model2soca \
                             -o $MODEL_RST_DIR_OUT/cice.res.nc  # Aggregate ice categories
