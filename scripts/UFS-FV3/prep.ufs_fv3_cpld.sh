#!/bin/bash

# set the year, month, day for the RT.
export start_year=2015
export start_month=05
export start_day=15
export start_date=${start_year}${start_month}${start_day}
export nhours_fcst=12

# set paths to FV3, MOM6 ocean, and CICE6 files.
export FV3_SRC_DIR="/work/noaa/marine/Partha.Bhattacharjee/IC_Dir/CFSRfracL127"
export MOM6_SRC_DIR="/work/noaa/marine/Partha.Bhattacharjee/IC_Dir/CPC3Dvar"
export CICE_SRC_DIR="/work/noaa/marine/Partha.Bhattacharjee/IC_Dir/CPC"


# create necessary subdirectories.
mkdir ./RT_${start_date}
cd ./RT_${start_date}
mkdir INPUT RESTART history MOM6_OUTPUT

# link to FV3, MOM6, CICE6 files, as well as prereq. configuration/data files for the RT.
ln -s /work/noaa/marine/Cameron.Book/fv3/RT_setup/INPUT/* ./INPUT
ln -s /work/noaa/marine/Cameron.Book/fv3/RT_setup/MOM6_OUTPUT/* ./MOM6_OUTPUT
ln -s /work/noaa/marine/Cameron.Book/fv3/RT_setup/prep/* .
ln -s $FV3_SRC_DIR/${start_date}00/gfs/C384/INPUT/* ./INPUT
ln -s $MOM6_SRC_DIR/${start_date}00/ocn/025/* ./INPUT
ln -s $CICE_SRC_DIR/${start_date}00/ice/025/cice* ./cice_model.res.nc

# set the correct start date for FV3.
sed -i.SEDBACKUP "s/start_year.*/start_year:              $start_year/" model_configure
sed -i.SEDBACKUP "s/start_month.*/start_month:              $start_month/" model_configure
sed -i.SEDBACKUP "s/start_day.*/start_day:              $start_day/" model_configure

# set the appropriate start date for CICE6.
sed -i.SEDBACKUP "s/year_init.*/year_init      = $start_year/" ice_in
sed -i.SEDBACKUP "s/month_init.*/month_init      = $start_month/" ice_in
sed -i.SEDBACKUP "s/day_init.*/day_init      = $start_day/" ice_in

# submit the job.
sbatch ./job_card
sleep 22m

cd ../

module use -a /work/noaa/da/Cameron.Book/modulefiles
module load anaconda/1.7.2.

# prepare necessary files for a soca-science experiment.
mkdir ./cfg; cd ./cfg/
ln -s /work/noaa/marine/Cameron.Book/fv3/cpld_config/* ./
rm INPUT; mkdir INPUT RESTART; mkdir INPUT/0.25deg RESTART/${start_date}12
ln -s /work/noaa/marine/Cameron.Book/fv3/cpld_config/INPUT/0.25deg/* ./INPUT/0.25deg
ln -s $FV3_SRC_DIR/${start_date}00/gfs/C384/INPUT/gfs* ./INPUT/0.25deg
cd ../RT_${start_date}/RESTART/
cp coupler.res fv_core.res* fv_srf_wnd.res* fv_tracer.res* iced*43200.nc MOM.res.nc MOM.res_* phy_data* sfc_data* ufs*43200.nc ../../cfg/RESTART/${start_date}12
cd ../../
ncks -A -C -v ave_ssh,v ./cfg/RESTART/${start_date}12/MOM.res_1.nc ./cfg/RESTART/${start_date}12/MOM.res.nc
python ./soca-science/tools/seaice/soca_seaice.py -m cice -f ./cfg/RESTART/${start_date}12/iced.${start_year}-${start_month}-${start_day}-43200.nc -a model2soca -o ./cfg/RESTART/${start_date}12/cice.res.nc

# set the correct restart directory and EXP_START_DATE for soca-science exp.config file."
sed -i.SEDBACKUP "s+EXP_START_DATE.*+EXP_START_DATE=${start_date}Z12+" exp.config
sed -i.SEDBACKUP "s+BKGRST_SRC.*+BKGRST_SRC=${EXP_DIR}/cfg/RESTART/${start_date}12+" exp.config
