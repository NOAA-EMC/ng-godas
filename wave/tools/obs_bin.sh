#!/bin/bash
#
# (C) Copyright 2021-2021 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
#
# Script to perform the binning step of ioda-plots on all available
# observations in the obs_out directory of a given experiment
#================================================================================
set -eu

# get the path to soca-science, based out the location of this script
SOCA_SCIENCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" &> /dev/null && pwd )"

# get command line arguments
expdir=""
sdate=""
edate=""
threads=$(nproc --all)
i=1
while [[ "$i" -le "$#" ]]; do
  case "${!i}" in
    \-e)
      ((i+=1)); edate=${!i} ;;
    \-s)
      ((i+=1)); sdate=${!i} ;;
    \-t)
      ((i+=1)); threads=${!i} ;;
    *)
      [[ "$expdir" != "" ]] && break
      expdir=$(readlink -f ${!i})
  esac
  ((i+=1))
done
if [[ "${expdir}" == "" ]]; then
  echo "USAGE: obs_bin.sh EXP_DIR [-s START_DATE] [-e END_DATE] [-t THREADS]"
  echo "  - Dates are optional, and are in YYYYMMDDHH format."
  echo "  - If the number of threads is not supplied, it will default to the "
  echo "    number of system cores ($(nproc --all) cores)"
  exit 1
fi

# make sure the experiment directory exists
if [[ ! -d "${expdir}/obs_out" ]]; then
    echo "ERROR: $expdir is not a valid experiment directory"
    exit 1
fi

# get / validate the start and end dates
dates=($(ls $expdir/obs_out/*/* -d | sort | xargs -L1 basename))
exp_start=${dates[0]}
exp_end=${dates[-1]}
[[ "$sdate" == "" ]] && sdate=$exp_start
[[ "$edate" == "" ]] && edate=$exp_end
sdate=$(date -ud "${sdate:0:8}Z${sdate:8:2}")
edate=$(date -ud "${edate:0:8}Z${edate:8:2}")

# source the experiment config file (to get DA_MODE)
set +u
export EXP_DIR=$expdir
. $expdir/exp.config
set -u

# clear out old timerseries and merged files
rm -f $expdir/obs_bin/*.{merged,timeseries}.*nc

# bin all the dates
proc_count=0
cdate=$sdate
while [[ $(date -ud "$cdate" +%s) -le $(date -ud "$edate" +%s) ]]; do
  cdate_ymdh=$(date -ud "$cdate" +"%Y%m%d%H")
  ndate=$(date -ud "$cdate + 1 day")
  [[ "$DA_MODE" == "letkf" ]] && ctrl_ens="ens" || ctrl_ens="ctrl"
  obs_out_dir=$expdir/obs_out/${cdate_ymdh:0:4}/$cdate_ymdh/${ctrl_ens}
  if [[ ! -d "$obs_out_dir" ]]; then
    echo "WARNING: $obs_out_dir does not exist, skipping."
    cdate=$ndate
    continue
  fi
  echo "******* Processing $cdate"

  # processe each (valid) platofrm present on this date
  platforms=$(ls $obs_out_dir -1 | xargs -L1 | cut -d_ -f1 | sort -u)
  for platform in $platforms; do
    # make sure a valid config file exists for this platform type
    cfg_src=$SOCA_SCIENCE_DIR/configs/iodaplots/${platform}_binning.yaml
    if [[ ! -f "$cfg_src" ]]; then
      echo "WARNING: no binning config file for $platform, skipping"
      continue
    fi
    out_dir=$expdir/obs_bin/${cdate_ymdh:0:4}/${cdate_ymdh}
    mkdir -p $out_dir

    # create the filled in config file
    cfg=$expdir/obs_bin/${platform}_binning.yaml
    if [[ ! -f "$cfg" ]]; then
      mode=$DA_MODE
      [[ "$mode" == "3dvar" || "$mode" == "3dhyb" ]] && mode=var
      [[ "$mode" == "noda" ]] && mode=hofx
      sed "s/__MODE__/${mode}/g" $cfg_src > $cfg
    fi

    # run the binning!
    files=$obs_out_dir/${platform}_*.nc
    iodaplots bin -c $cfg $files -o $out_dir/${platform}.${cdate_ymdh}.nc &
    ((proc_count+=1))
    [[ "$proc_count" == "$threads" ]] && wait && proc_count=0
  done

  # done, do next cycle
  cdate=$ndate
done
wait

# concatenate the files
echo -e "\nConcatenating into a single timeseries file"
platforms=$(ls $expdir/obs_bin/*_binning.yaml -1 | xargs -L1 basename | cut -d_ -f1)
for platform in $platforms; do
    iodaplots cat \
      $expdir/obs_bin/????/??????????/$platform.*.nc \
      -o $expdir/obs_bin/$platform.timeseries.nc
done
