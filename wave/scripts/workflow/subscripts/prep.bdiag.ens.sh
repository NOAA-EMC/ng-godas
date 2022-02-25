#!/bin/bash

# (C) Copyright 2021-2021 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

set -e

cat << EOF

#================================================================================
#================================================================================
# prep.bdiag.ens.sh
#   Compute the diagonal of B as the sample variance of an ensemble of (K^-1 X)
#   members and save it to be used in the following VAR cycle
#================================================================================

EOF

# Required environment variables:
envars=()
envars+=("DATE")
envars+=("BKGRST_DIR")
envars+=("BKGRST_ENS_DIR")
envars+=("DA_ENS_SIZE")
envars+=("DA_SEAICE_ENABLED")
envars+=("DA_WAV_ENABLED")
envars+=("DA_VARIABLES")
envars+=("SOCA_DEFAULT_CFGS_DIR")
envars+=("SOCA_BIN_DIR")
envars+=("SOCA_STATIC_DIR")

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

# TODO, check if we can exit early
if [[ -d "$DIAGB_TMP_DIR" && $(ls $DIAGB_TMP_DIR -1q | wc -l) -gt 0 ]]; then
  echo "bdiag.ens has already been created at :"
  echo "$DIAGB_TMP_DIR"
  exit 0
fi


ln -s $SOCA_BIN_DIR/soca_ensvariance.x .

# Set domain
domains='ocn'
if [[ "$DA_SEAICE_ENABLED" =~ [yYtT1] ]]; then
  domains='ocn_ice'
fi
if [[ "$DA_WAV_ENABLED" =~ [yYtT1] ]]; then
  domains='ocn_wav'
fi

# Configure MOM6
ln -s  $MODEL_CFG_DIR/* .
export FCST_RESTART=1
export FCST_START_TIME=$ANA_DATE
export FCST_RST_OFST=24
if [[ "$DA_OBGC_ENABLED" =~ [yYtT1] ]]; then
    . input_bgc.nml.sh > mom_input.nml
else
    . input.nml.sh > mom_input.nml
fi
mkdir -p OUTPUT RESTART
mkdir -p INPUT
(cd INPUT && ln -sf $MODEL_DATA_DIR/* .)
ln -s $MODEL_DATA_DIR/../soca/* . # TODO use proper path
ln -s $SOCA_STATIC_DIR/* .

# Main blocks of the ensemble variance application yaml
cp $SOCA_DEFAULT_CFGS_DIR/{fields_metadata,soca_ensvariance}.yaml .
DA_BKG_DATE=$(date -ud "$ANA_DATE" +"%Y-%m-%dT%H:%M:%SZ")
sed -i "s/__DA_BKG_DATE__/$DA_BKG_DATE/g" soca_ensvariance.yaml
sed -i "s;__DOMAINS__;$domains;g" soca_ensvariance.yaml
sed -i "s;__DA_VARIABLES__;$DA_VARIABLES;g" soca_ensvariance.yaml

# Prepare the ensemble part of yaml
touch ens.tmp
for ens in $(seq -f "%03g" $DA_ENS_SIZE); do
  echo "- <<: *ens_member" >> ens.tmp
  echo "  ocn_filename: bkg_ens/$ens/MOM.res.nc" >> ens.tmp
  if [[ "$DA_SEAICE_ENABLED" =~ [yYtT1] ]]; then
     echo "  ice_filename: bkg_ens/$ens/cice.res.nc" >> ens.tmp
  fi
  if [[ "$DA_WAV_ENABLED" =~ [yYtT1] ]]; then
     echo "  wav_filename: bkg_ens/$ens/wav.res.nc" >> ens.tmp
  fi
done
sed -i "s/^/        /g" ens.tmp
sed -i $'/__ENSEMBLE__/{r ens.tmp\nd}' soca_ensvariance.yaml

# Link ensemble members and deterministic background
mkdir -p Data
ln -sf $BKGRST_DIR bkg
ln -s bkg RESTART_IN
ln -s $BKGRST_ENS_DIR bkg_ens

# Compute variance of (K^-1 X)
export OMP_NUM_THREADS=1
$MPIRUN ./soca_ensvariance.x soca_ensvariance.yaml

# move ensemble variance files
mkdir -p $DIAGB_TMP_DIR
mv Data/*ens_variance*.nc $DIAGB_TMP_DIR

echo "done with BDIAG"
