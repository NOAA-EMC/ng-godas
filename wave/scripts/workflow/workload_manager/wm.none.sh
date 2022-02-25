#!/bin/bash

# (C) Copyright 2020-2020 UCAR
#
# This software is licensed under the terms of the Apache Licence Version 2.0
# which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.

# the "none" workload manager, for simply running a cycling DA sequentially
# on your own computer

function wm_checktime {
    #return the end time for this job. Since we aren't using a
    # workload manager, just pick a date far off in the future,
    # no one could posssibly still be using this code in 2100!
    # (which i'm sure is the same exact thinking that lead to the Y2K bug)
    echo "2100-01-01T00:00:00"
}

function wm_submitjob {
    echo "ERROR: submitjob should not have been called in wm.none.sh"
    exit 1
}

function wm_init {
    echo ""
    echo "NOT using any workload manager. Directly running the scripts locally."
}