#!/bin/bash

# (C) Copyright 2020-2020 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

set -e

cat << EOF

#================================================================================
#================================================================================
# prep.obs.sh
#   Prepare the observation files, either by linking to an already existing
#   prepared database given by OBS_SRC, OBS_<ob>_SRC, OBS_<ob>_<plat>_SRC or by
#   downloading and converting from ther internet.
#================================================================================

EOF

# default values
OBS_GEN_ENABLED=${OBS_GEN_ENABLED:-F}
OBS_GEN_DIR=${OBS_GEN_DIR:-$EXP_DIR/obs/#ob#/%Y/%Y%m%d}
OBS_SRC=${OBS_SRC:-$EXP_DIR/obs}
OBS_TOLERATE_FAIL=${OBS_TOLERATE_FAIL:-F}
OBS_SRC_ARCHIVE=${OBS_SRC_ARCHIVE:-%Y/%Y%m%d}

# Required environment variables:
envars=()
envars+=("DATE")
envars+=("OBS_DIR")
envars+=("OBS_GEN_ENABLED")
envars+=("OBS_GEN_DIR")
envars+=("OBS_LIST")
envars+=("OBS_SCRIPT_DIR")
envars+=("OBS_SRC")
envars+=("OBS_TOLERATE_FAIL")
envars+=("R2D2_CFG_DIR")
envars+=("R2D2_DB_DIR")
envars+=("R2D2_ENABLED")
envars+=("SOCA_SCIENCE_BIN_DIR")
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

# subsitute date in certain variables
OBS_GEN_DIR=$(date -ud "$DATE" +"$OBS_GEN_DIR" )
OBS_SRC_ARCHIVE=$(date -ud "$DATE" +"$OBS_SRC_ARCHIVE")

ymd=$(date -ud "$DATE" +%Y%m%d )
ymdh=$(date -ud "$DATE" +%Y%m%d%H )

# If using R2D2 data base
if [[ "$R2D2_ENABLED" =~ [yYtT1] ]]; then
   # setup r2d2 (export config.yaml)
   cp $R2D2_CFG_DIR/r2d2_config.yaml .
   echo $R2D2_DB_DIR
   sed -i "s;\$(R2D2_DB_DIR);$R2D2_DB_DIR;g" r2d2_config.yaml
   export R2D2_CONFIG=$PWD/r2d2_config.yaml

   # create list of obs, abort if list is "ALL"
   cp $R2D2_CFG_DIR/soca_fetch_obs.yaml .
   sed -i "s;\$(START_YYYYMMDD);$ymd;g" soca_fetch_obs.yaml
   sed -i "s;\$(END_YYYYMMDD);$ymd;g" soca_fetch_obs.yaml
   target_dir=$PWD/../obs
   sed -i "s;\$(TARGET_DIR);$target_dir;g" soca_fetch_obs.yaml
   provider="jcsda_soca"
   experiment="soca_ctest"
   sed -i "s;\$(PROVIDER);$provider;g" soca_fetch_obs.yaml
   sed -i "s;\$(EXPERIMENT);$experiment;g" soca_fetch_obs.yaml

   for ob in $OBS_LIST; do
       v_list="OBS_${ob^^}_LIST"
       o_list="${!v_list:-}"
       for plat in $o_list; do
           echo "    - ${ob}_${plat}" >> soca_fetch_obs.yaml
       done
   done

   # fetch from r2d2 database
   $SOCA_SCIENCE_BIN_DIR/soca_fetch_obs.py soca_fetch_obs.yaml

   echo "done with prep.obs"
   exit 0
fi

mkdir -p $OBS_DIR

# for each obs type listed
for ob in $OBS_LIST; do
    echo -e "\nObservation type: $ob"

    # Get the default OBS_LIST and default OBS_{SRC,DWNLD,CNVRT} vars
    v_list="OBS_${ob^^}_LIST"
    v_src="OBS_${ob^^}_SRC"
    v_dwnld="OBS_${ob^^}_DWNLD"
    v_cnvrt="OBS_${ob^^}_CNVRT"
    o_list="${!v_list:-ALL}"
    o_src="${!v_src:-$OBS_SRC}"
    o_src=${o_src/\#ob\#/$ob}
    o_src=$(date -ud "$DATE" +"$o_src")
    o_dwnld="${!v_dwnld:-}"
    o_cnvrt="${!v_cnvrt:-}"
    printf "  %-23s %s\n" ${v_list} "${o_list}"
    printf "  %-23s %s\n" ${v_src} "${o_src}"
    printf "  %-23s %s\n" ${v_dwnld} "${o_dwnld}"
    printf "  %-23s %s\n" ${v_cnvrt} "${o_cnvrt}"


    # clean working obs directory
    obs_dir=$OBS_DIR/$ob
    rm -rf $obs_dir
    mkdir $obs_dir


    # for each platform listed for this observation type
    for plat in $o_list; do
        echo ""
        echo "Searching for $ob platform: $plat"
        if [[ "${plat^^}" == "ALL" ]]; then
            v_plat_src="$v_src"
            v_plat_dwnld="$v_dwnld"
            v_plat_cnvrt="$v_cnvrt"
            o_plat_src_file="*.nc"
        else
            # the _SRC,_DWNLD,_CNVRT vars can be overriden
            v_plat_src="OBS_${ob^^}_${plat^^}_SRC"
            v_plat_dwnld="OBS_${ob^^}_${plat^^}_DWNLD"
            v_plat_cnvrt="OBS_${ob^^}_${plat^^}_CNVRT"
            o_plat_src_file="${ob}_${plat}_${ymdh}.nc"
        fi
        o_plat_src="${!v_plat_src:-$o_src}"
        o_plat_src=${o_plat_src/\#plat\#/$plat}
        o_plat_src=$(date -ud "$DATE" +"$o_plat_src")
        o_plat_dwnld="${!v_plat_dwnld:-$o_dwnld}"
        o_plat_cnvrt="${!v_plat_cnvrt:-$o_cnvrt}"
        printf "  %-23s %s\n" ${v_plat_src} "${o_plat_src}"
        printf "  %-23s %s\n" ${v_plat_dwnld} "${o_plat_dwnld}"
        printf "  %-23s %s\n" ${v_plat_cnvrt} "${o_plat_cnvrt}"


        # 1) check if $OBS_*_SRC points to a zip file
        if [[ "$o_plat_src" =~ .*\.zip$ && -f "$o_plat_src" ]]; then
            echo "Found an archive file to search: $o_plat_src"
            o_src_archive=$OBS_SRC_ARCHIVE
            mkdir -p archive_$ob
            fail=0
	    (cd archive_$ob && unzip -o $o_plat_src $o_src_archive/$o_plat_src_file ) || fail=1
	    if [[ $fail == 0 ]]; then
                ln -s $(readlink -f archive_$ob/$o_src_archive/$o_plat_src_file) $obs_dir/
                # TODO, check to make sure files were created?
                continue
            fi
	fi


        # 2) otherwise, search the $OBS_*_SRC directories
        echo "Searching local directories..."
        obs_src_dir=""
        for ext in "" "/$ymd" "/${ymd:0:4}/$ymdh"; do
            for d in "$o_plat_src$ext" "$o_plat_src/$ob$ext" "$o_plat_src$ext/$ob"; do
                echo "  searching $d"
                if [[ -d $d && $(ls $d/$o_plat_src_file -1q 2>/dev/null | wc -l) -gt 0 ]]; then
                    echo "Observations found at $d"
                    obs_src_dir=$d
                    break
                fi
            done
            [[ "$obs_src_dir" != "" ]] && break
        done
        if [[ "$obs_src_dir" != "" ]]; then
            ln -s $obs_src_dir/$o_plat_src_file $obs_dir
            continue
        fi


        # can't find files so far, are we allowed to generate?
        if [[ ! "$OBS_GEN_ENABLED" =~ [yYtT1] ]]; then
            printf "ERROR: Cannot find observations, set \$OBS_GEN_ENABLED=T or"
            printf " check \$OBS_SRC\n"
            [[ "$OBS_TOLERATE_FAIL" =~ [yYtT1] ]] && continue
            exit 1
        fi


        # 3) otherwise, download and convert
        echo "Downloading from the internet..."

        # find the download script (could be a full path passed in, or assumed
        #  a script in the default obs download script directory)
        o_plat_dwnld_orig=${o_plat_dwnld%% *}
        if [[ ! -f "${o_plat_dwnld%% *}" ]]; then
            o_plat_dwnld="$OBS_SCRIPT_DIR/$o_plat_dwnld"
            if [[ ! -f "${o_plat_dwnld%% *}" ]]; then
                echo "ERROR: cannot find download script ${o_plat_dwnld_orig}"
                exit 1
            fi
        fi

        # Download
        mkdir -p dwnld/$ob
        o_dwnld_plat=${o_plat_dwnld/\%/$plat}
        ${o_dwnld_plat} $ymd dwnld/$ob

        # get list of platforms to convert (needed if ALL)
        plats=$plat
        if [[ "$plats" == "ALL" ]]; then
            cd $WORK_DIR/dwnld/$ob
            plats=$(ls)
            cd $WORK_DIR
        fi

        # convert
        mkdir -p cnvrt/$ob
        for p in $plats; do
            # find the convert script (could be a full path passed in, or assumed
            #  a script in the default soca bin directory)
            obs_cnvrt=${o_plat_cnvrt}
            if [[ ! -f "${obs_cnvrt%% *}" ]]; then
                obs_cnvrt="$SOCA_SCIENCE_BIN_DIR/$o_plat_cnvrt"
                if [[ ! -f "${obs_cnvrt%% *}" ]]; then
                    echo "ERROR: cannot find convert script ${o_plat_cnvrt%% *}"
                    exit 1
                fi
            fi

            # convert
            $obs_cnvrt -i dwnld/$ob/$p/* -o tmp-obs.nc -d ${ymd}00
            $SOCA_SCIENCE_BIN_DIR/ioda-upgrade.x tmp-obs.nc cnvrt/$ob/${ob}_${p}_$ymd.nc

            # move to final location
            obs_gen_dir=${OBS_GEN_DIR/\#ob\#/$ob}
            mkdir -p $obs_gen_dir
            mv cnvrt/$ob/* $obs_gen_dir/
            ln -s $(readlink -f $obs_gen_dir/${ob}_${p}_$ymd.nc) $obs_dir/
        done
    done

    # make sure obs_dir isn't empty... if it is delete it
    # (due to an oversight of other scripts not able to handle and empty
    #  obs_dir)
    if [[ $(ls $obs_dir/* -1q 2>/dev/null | wc -l) -eq 0 ]]; then
        rm $obs_dir -rf
    fi
done

echo "done with prep.obs"
