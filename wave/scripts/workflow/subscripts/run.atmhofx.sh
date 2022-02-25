#!/bin/bash

# (C) Copyright 2020-2020 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

set -e

cat << EOF

#================================================================================
#================================================================================
# run.cplhofx.sh
#   Run stand alone atm h(x) to compute the atm GeoVaLs needed by  the CRTM
#================================================================================

EOF

# Required environment variables:
envars=()
envars+=("BKG_FILE")
envars+=("GEOS_FV3JEDI_STATIC")
envars+=("MODEL_DATA_DIR")
envars+=("MPIRUN_ATM")
envars+=("OBS_DIR")
envars+=("OBS_LIST_ATM")
envars+=("OBS_ATM_OUT_CTRL_DIR")
envars+=("SOCA_BIN_DIR")
envars+=("WORK_DIR")

# make sure required env vars exist
set +u
for v in ${envars[@]}; do
  if [[ -z "${!v}" ]]; then
    echo "ERROR: env var $v is not set."; exit 1
  fi
  printf "%-25s %s\n" " $v " "${!v}"
done
set -u
echo ""

# skip running cplhofx if it has already been run
if [[ -d "$OBS_ATM_OUT_CTRL_DIR" && $(ls $OBS_ATM_OUT_CTRL_DIR -1q | wc -l) -gt 0 ]]; then
  echo "CplHofX has already been created at :"
  echo " $OBS_OUT_CTRL_DIR"
  exit 0
fi


# Prepare the fv3-jedi static files
ln -s $GEOS_FV3JEDI_STATIC/Data .
ln -s $SOCA_BIN_DIR/fv3jedi_hofx_nomodel.x .
cp $SOCA_DEFAULT_CFGS_DIR/{fields_metadata,fv3_hofx_geos_c90_nomodel}.yaml .

# Prepare the configuration file
DA_WINDOW_HW=$((FCST_LEN/2))
DA_WINDOW_START=$(date -ud "$ANA_DATE - $DA_WINDOW_HW hours" +"%Y-%m-%dT%H:%M:%SZ")
sed -i "s/__DA_WINDOW_START__/${DA_WINDOW_START}/g" fv3_hofx_geos_c90_nomodel.yaml
sed -i "s/__DA_WINDOW_LENGTH__/PT${FCST_LEN}H/g" fv3_hofx_geos_c90_nomodel.yaml

# prepare the __OBSERVATIONS__ section of the config yaml
# TODO sigh, this TOO should be move into a common function <--- That
echo "Preparing individual observations:"
touch obs.yaml
for o in $OBS_LIST_ATM; do
    # if obs directory doesn't exist, skip it
    [[ ! -d $OBS_DIR/$o ]] && continue

    # TODO only include obs listed in $OBS_${o}_LIST
    for f in $OBS_DIR/$o/*; do
        odir=$(basename $f)
        odir=${odir%.*}
        plat=${odir#*_}
        plat=${plat%_*}
        odir=${plat}
        printf " %-24s %s\n" ${odir} $f
        mkdir -p obs_out/$odir
        (
            cat $SOCA_DEFAULT_CFGS_DIR/obs/$o.yaml > ob.tmp
            sed -i "s;__OBS_PLAT__;$plat;g" ob.tmp
            sed -i "s;__OBS_IN_FILE__;$f;g" ob.tmp
            sed -i "s;__OBS_OUT_DIR__;obs_out/${odir};g" ob.tmp
            cat ob.tmp >> obs.yaml
        )
    done
done
sed -i "s/^/  /g" obs.yaml
sed -i $'/__OBSERVATIONS__/{r obs.yaml\nd}' fv3_hofx_geos_c90_nomodel.yaml

# Get the background
ln -s $BKG_FILE jedi-geos-c90.geosgcm_traj.nc4

# run h(x)
export OMP_NUM_THREADS=1
$MPIRUN_ATM ./fv3jedi_hofx_nomodel.x fv3_hofx_geos_c90_nomodel.yaml

# concatenate the obs and geovals
for ob_dir in obs_out/*; do
    ob=$(basename $ob_dir)
    echo "  Processing $ob"
    for f in $ob_dir/*_0000.nc; do
        ob_var=${f##*/}
        ob_var=${ob_var%_*}
        # concatenate files
        $MPIRUN ${SOCA_SCIENCE_BIN_DIR}/obs_cat.x -i $ob_dir/${ob_var} -o $ob_var.nc
	rm $ob_dir/${ob_var}_0*
	cp $ob_var.nc $ob_dir
    done
done

# move the results to a directory inside the SCRATCH directory
mkdir -p $OBS_ATM_OUT_CTRL_DIR
mv obs_out/* $OBS_ATM_OUT_CTRL_DIR

echo "done with CplHofX"
