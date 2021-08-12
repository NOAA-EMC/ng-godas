#!/bin/bash

# required environment variables:
envars=()
envars+=("FCST_RESTART")      # =1 if a restart file is used, otherwise T/S IC file is used
envars+=("FCST_START_TIME")   # start of forecast (in any appropriate "date" command format)
envars+=("MACHINE_CONFIG_FILE") # workflow/soca modules
envars+=("MODEL_CFG_DIR")     # UFS resource files & MOM data
envars+=("MODEL_DATA_DIR")    # path to input model static data (ocean_topo.nc, tideamp.nc, ...)
envars+=("MODEL_EXE")         # path to UFS executable
envars+=("WAV_MODEL_RES")     # Model resolution
envars+=("DA_WAV_ENABLED")
envars+=("MODEL_RST_DIR_IN")  # path to restart files from previous cycle (if FCST_RESTART==1)
envars+=("MODEL_RST_DIR_OUT")
envars+=("FV3_RST_DIR")
envars+=("BKGRST_ENS_DIR")
envars+=("JOB_NPES")
envars+=("FCST_LEN")
envars+=("FORC_SRC")
envars+=("FORC_GEN_SOURCE")
envars+=("SOCA_BIN_DIR")
envars+=("UFS_SCRATCH")
envars+=("WW3_BIN_DIR")

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
#
export NEXT_DATE=$(date -ud "$FCST_START_TIME + $FCST_LEN hours" +%Y%m%d%H)
#export NDATE=$(date -ud "${NEXT_DATE}" +%Y%m%d%H)
export NYEAR=${NEXT_DATE:0:4}
export NMONTH=${NEXT_DATE:4:2}
export NDAY=${NEXT_DATE:6:2}
export NHOUR=${NEXT_DATE:8:2}
echo $NEXT_DATE
echo $NYEAR
echo $NMONTH
echo $NDAY
echo $NHOUR


# prepare the working directory (which we assume we are already in)
mkdir -p OUTPUT

# output restarts
# TODO, make sure above this level that directory exists
mkdir -p $MODEL_RST_DIR_OUT
ln -s $MODEL_RST_DIR_OUT RESTART

#
mkdir -p INPUT
ln -fs $MODEL_DATA_DIR/* ./INPUT

# main configuration files
ln -sf $MODEL_CFG_DIR/* ./

# prepare resource files for ufs
cp -r $UFS_SCRATCH/* ./
ln -fs $MODEL_RST_DIR_IN/* ./INPUT/
if [[ ${MODEL_RST_DIR_IN: -4} == "ctrl" ]]; then
   echo "control run!"
   ln -fs $FV3_RST_DIR/$SYEAR$SMONTH$SDAY${SHOUR}/ctrl/* ./INPUT/
else
   echo "ens case! check ens folder!"
   echo ${MODEL_RST_DIR_IN} 
   echo ${MODEL_RST_DIR_IN: -3}
   ens_case=${MODEL_RST_DIR_IN: -3}
   ln -fs $FV3_RST_DIR/$SYEAR$SMONTH$SDAY${SHOUR}/ens/${ens_case}/* ./INPUT/ 
fi
if [ -f "$MODEL_RST_DIR_IN/restart001.ww3" ]; then
   echo "restart from ww3uprst!"
   ln -fs $MODEL_RST_DIR_IN/restart001.ww3 ./restart.${WAV_MODEL_RES}
else
   echo "restart from previos restart!"
   ln -fs $MODEL_RST_DIR_IN/*restart.${WAV_MODEL_RES} ./restart.${WAV_MODEL_RES}
fi

# setup model files
sed -i "s+SYEAR+${SYEAR}+g" model_configure
sed -i "s+SMONTH+${SMONTH}+g" model_configure
sed -i "s+SDAY+${SDAY}+g" model_configure
sed -i "s+SHOUR+${SHOUR}+g" model_configure


# load modules
module purge
source ./module-setup.sh
module use $( pwd -P )
module load modules.fv3
module load nco/4.9.3 #TODO only for orion, should change later
export OMP_STACKSIZE=512M
export KMP_AFFINITY=scatter
export OMP_NUM_THREADS=1

# run ufs model
#srun -n ${NTASKS_TOT} ${MODEL_EXE}
$MPIRUN $MODEL_EXE

# move restart files to desired location
echo "check!"
echo $NEXT_DATE
echo $NYEAR
echo $NMONTH
echo $NDAY
echo $NHOUR
rm $MODEL_RST_DIR_OUT/* # We used gefs 12 initial condtions for now
ln -fs ${NYEAR}${NMONTH}${NDAY}.${NHOUR}0000.out_grd.${WAV_MODEL_RES} ./out_grd.ww3
ln -fs mod_def.${WAV_MODEL_RES} ./mod_def.ww3
$WW3_BIN_DIR/ww3_ounf ww3_ounf.inp
ncatted -O -a _FillValue,hs,o,d,0.0 ww3."$NYEAR$NMONTH$NDAY"T${NHOUR}Z.nc ./wav.res.nc
cp ./${NYEAR}${NMONTH}${NDAY}.${NHOUR}0000.restart.${WAV_MODEL_RES} $MODEL_RST_DIR_OUT
cp wav.res.nc $MODEL_RST_DIR_OUT
cp $MODEL_RST_DIR_IN/MOM.res.nc $MODEL_RST_DIR_OUT

#
rm out_grd.ww3
rm mod_def.ww3

#
#hr2sec=$(printf "%05d" $((3600*$SHOUR)))

# Create cice.res.nc (used as input to soca)
#source $MACHINE_CONFIG_FILE
#ice_rst=`ls $MODEL_RST_DIR_OUT/iced.*.nc`
#$SOCA_BIN_DIR/soca_seaice.py -f $ice_rst \
#                             -m cice \
#                             -a model2soca \
#                             -o $MODEL_RST_DIR_OUT/cice.res.nc  # Aggregate ice categories
