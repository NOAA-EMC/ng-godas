#!/bin/bash
#
# (C) Copyright 2021-2021 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
#
# Script to perform the plotting step of ioda-plots on a list of given experiments
# This can be run 2 ways: with a single experiment passed in, or 2+ experiments
#  passed in.
#================================================================================
set  -eu

# get the path to soca-science, based out the location of this script
SOCA_SCIENCE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" &> /dev/null && pwd )"

# get command line arguments
out_dir=""
exp_names=()
exp_paths=()
i=1
[[ "$#" -ge 4 ]] && err=0 || err=1
while [[ "$i" -le "$#" && "$err" == 0 ]]; do
    if [[ "${!i}" == "-e" ]]; then # "-e <exp_name> <exp_path>"
        i2=$((i+1))
        i3=$((i+2))
        [[ "$i3" -gt "$#" ]] && err=1 && break
        exp_names+=("${!i2}")
        exp_paths+=("${!i3}")
        ((i+=3))
    else # "<out_dir>"
        [[ "$out_dir" != "" ]] && err=1 && break
        out_dir=${!i}
        ((i+=1))
    fi
done
if [[ "$err" -ne 0 ]]; then
    echo "USAGE: obs_plot OUT_DIR -e EXP_NAME EXP_PATH [ -e ... ]"
    echo "  Note that more than one experiment can be given "
    exit 1
fi
num_exps=${#exp_names[@]}


# TODO be able to handle merged/cat files directly and skip looking
#  at the experiment directory?


# calculate the overlapping date for all experiments
exp_starts=()
exp_ends=()
for i in $(seq 0 $((num_exps-1))); do
    # for each experiment get the first and last dates available
    if [[ ! -d "${exp_paths[$i]}/obs_bin" ]]; then
        echo "ERROR: ${exp_paths[$i]} is not a valid experiment path"
        echo " with binned observation stats."
        exit 1
    fi
    dates=($(ls ${exp_paths[$i]}/obs_bin/????/?????????? -d | sort | xargs -L1 basename))
    exp_starts+=("${dates[0]}")
    exp_ends+=("${dates[-1]}")
done
IFS=$'\n'
exp_starts=($(sort <<<"${exp_starts[*]}")) # sort the dates
exp_ends=($(sort <<<"${exp_ends[*]}"))
unset IFS
start=${exp_starts[-1]} # get the latest start date across all exps
end=${exp_ends[0]}      # and the earliest end date
if [[ "$start" -gt "$end" ]]; then
    echo "ERROR: no valid overlapping dates found."
    exit 1
fi
echo "overlapping experiment dates: $start to $end"


# calculate the complete list of platforms across all exps
all_platforms=()
for e in ${exp_paths[@]}; do
    platforms=$(ls $e/obs_bin/????/??????????/*.nc -1 | xargs -L1 basename | cut -d. -f1 | sort -u)
    for platform in $platforms; do
        all_platforms+=("$platform")
    done
done
IFS=$'\n' all_platforms=($(sort -u <<<"${all_platforms[*]}")); unset IFS


#===============================================================================
# for each experiment, merge the obs, if not already done so
# (not done during binning script, because the overlapping dates among
#  experiments has to be known first)
#===============================================================================
for exp_path in ${exp_paths[@]}; do
    obs_bin_dir=$exp_path/obs_bin

    # for each platform
    for platform in ${all_platforms[@]}; do
        merge_file=$obs_bin_dir/$platform.merged.$start.$end.nc
        cat_file=$obs_bin_dir/$platform.timeseries.$start.$end.nc
        if [[ ! -f "$merge_file" ]]; then
            # generate a list of the files to merge
            files=()
            cdate=$start
            while [[ "$cdate" -le "$end" ]]; do
                obfile=$obs_bin_dir/${cdate:0:4}/$cdate/$platform.$cdate.nc
                [[ -f "$obfile" ]] && files+=("$obfile")
                cdate=$(date -ud "${cdate:0:8}Z${cdate:8:2} + 1 day" +"%Y%m%d%H")
            done

            # merge, only if there are files for this platform
            if [[ "${#files[@]}" -gt 0 ]]; then
                echo -e "\ngenerating $merge_file"
                iodaplots merge "${files[@]}" -o $merge_file
            fi
        fi
    done
done


#===============================================================================
#===============================================================================
for platform in ${all_platforms[@]}; do
    echo -e "\n\n"
    echo "=================================================================="

    # make sure the plotting configuration file exists
    cfg_src=$SOCA_SCIENCE_DIR/configs/iodaplots/${platform}_plotting.yaml
    if [[ ! -f "$cfg_src" ]]; then
      echo "WARNING: no plotting config file for $platform, skipping"
      continue
    fi


    # plot single experiment (if only one exp given)
    if [[ "$num_exps" -eq 1 ]]; then
        # merged
        plot_out_dir=$out_dir/${exp_names[0]}/merged/$platform
        mkdir -p $plot_out_dir
        sed "s/__MODE__/one_merged/g" $cfg_src > $plot_out_dir/config.yaml
        iodaplots plot -c $plot_out_dir/config.yaml \
          -e ${exp_names[0]} ${exp_paths[0]}/obs_bin/$platform.merged.$start.$end.nc \
          -o $plot_out_dir/

        # timeseries (and there is no point plotting this if only 1 timeslice)
        if [[ "$start" != "$end" ]]; then
            plot_out_dir=$out_dir/${exp_names[0]}/timeseries/$platform
            mkdir -p $plot_out_dir
            sed "s/__MODE__/one_cat/g" $cfg_src > $plot_out_dir/config.yaml
            iodaplots plot -c $plot_out_dir/config.yaml \
            -e ${exp_names[0]} ${exp_paths[0]}/obs_bin/$platform.timeseries.nc \
            -o $plot_out_dir/
        fi

    else
        all_merged_paths=()
        all_merged_names=()
        all_cat_paths=()
        all_cat_names=()

        # see which merged/cat file exists for which experiments
        do_diff=0 # will =1 if merged file is found for first exp (the reference exp)
        for i in $(seq 0 $((num_exps-1))); do
            exp_name=${exp_names[$i]}
            exp_merged=${exp_paths[$i]}/obs_bin/$platform.merged.$start.$end.nc
            exp_cat=${exp_paths[$i]}/obs_bin/$platform.timeseries.nc
            if [[ -f "$exp_merged" ]]; then
                all_merged_paths+=("$exp_merged")
                all_merged_names+=("$exp_name")
                [[ "$i" == 0 ]] && do_diff=1
            fi
            if [[ -f "$exp_cat" ]]; then
                all_cat_paths+=("$exp_cat")
                all_cat_names+=("$exp_name")
            fi
        done
        [[ "$do_diff" == 1 && "${#all_merged_paths[@]}" -le 1 ]] && do_diff=0

        # plot difference from reference experiment
        if [[ "$do_diff" == 1 ]]; then
            for i in $(seq $((${#all_merged_paths[@]}-1))); do
                plot_out_dir=$out_dir/${all_merged_names[$i]}-${all_merged_names[0]}/merged/$platform
                mkdir -p $plot_out_dir
                sed "s/__MODE__/diff_merged/g" $cfg_src > $plot_out_dir/config.yaml
                iodaplots plot -c $plot_out_dir/config.yaml --diff \
                    -e ${all_merged_names[0]} ${all_merged_paths[0]} \
                    -e ${all_merged_names[$i]} ${all_merged_paths[$i]} \
                    -o $plot_out_dir/
            done
        fi

        # all merged experiments
        args=()
        for i in $(seq 0 $((${#all_merged_paths[@]}-1))); do
            args+=("-e ${all_merged_names[$i]} ${all_merged_paths[$i]}")
        done
        plot_out_dir=$out_dir/all/merged/$platform
        mkdir -p $plot_out_dir
        sed "s/__MODE__/all_merged/g" $cfg_src > $plot_out_dir/config.yaml
        iodaplots plot -c $plot_out_dir/config.yaml ${args[@]} -o $plot_out_dir/

        # all timeseries experiments
        if [[ "$start" != "$end" ]]; then
            args=()
            for i in $(seq 0 $((${#all_cat_paths[@]}-1))); do
                args+=("-e ${all_cat_names[$i]} ${all_cat_paths[$i]}")
            done
            plot_out_dir=$out_dir/all/timeseries/$platform
            mkdir -p $plot_out_dir
            sed "s/__MODE__/all_cat/g" $cfg_src > $plot_out_dir/config.yaml
            iodaplots plot -c $plot_out_dir/config.yaml ${args[@]} -o $plot_out_dir/
        fi
    fi
done