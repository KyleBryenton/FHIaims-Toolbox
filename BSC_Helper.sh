#!/bin/bash

# Kyle R Bryenton 2025-01-25
# BSC_Helper.sh

# Purpose: 
#     If you order by <Path>/<Basis>/<Functional> like me, then your outputs are not in the requisite
#     order for Alberto's eval_driver_delta.m script, which assumes <Path>/<Functional>/<Basis>.
#     This script will create a BSC folder in the PWD with the appropriate structure.
#
# This shell script performs the following tasks:
# - Creates the BSC folder in PWD
# - Ensures lightdenser/<GGA> exists
#           lightdenser_then_tight/<GGA> exists
#           lightdenser_then_lightdenser/<HYB> exists
# - Creates the BSC/<HYB> folder in PWD
# - Copies the files into the requisite directory structure for eval_driver_delta.m
# - Generates the input directory list to use in eval_driver_delta.m

set -e  # Exit immediately if a command exits with a non-zero status

BSC_Gen() {
    local BSC_gga="${1%/}"
    local BSC_hyb="${2%/}" 

    # Checks if lightdenser/BSC_gga path exists
    if [ ! -d "lightdenser/$BSC_gga" ]; then
        echo "Error: Directory 'lightdenser/$BSC_gga' not found."
        return 1
    fi

    # Checks if lightdenser_then_tight/BSC_gga path exists
    if [ ! -d "lightdenser_then_tight/$BSC_gga" ]; then
        echo "Error: Directory 'lightdenser_then_tight/$BSC_gga' not found."
        return 1
    fi

    # Checks if lightdenser_then_lightdenser/BSC_hyb path exists
    if [ ! -d "lightdenser_then_lightdenser/$BSC_hyb" ]; then
        echo "Error: Directory 'lightdenser_then_lightdenser/$BSC_hyb' not found."
        return 1
    fi
    
    echo "Creating BSC structure for $BSC_hyb..."
    mkdir -p "BSC/$BSC_hyb"
    cp -r "lightdenser/$BSC_gga" "BSC/$BSC_hyb/lightdenser"
    cp -r "lightdenser_then_lightdenser/$BSC_hyb" "BSC/$BSC_hyb/lightdenser_then_lightdenser"
    cp -r "lightdenser_then_tight/$BSC_gga" "BSC/$BSC_hyb/lightdenser_then_tight"
}


echo "___Executing BSC_Helper.sh___"

# Aborts if BSC already exists. 
if [ ! -d "BSC" ]; then
    mkdir "BSC"
else
    echo "ABORTING: 'BSC' directory already exists. "
    echo "Please delete or rename this directory, then re-run."
    exit 1  
fi

######### EDITABLE SECTION ########
BSC_Gen "PBE" "PBE0"
BSC_Gen "PBE" "PBE-50"
BSC_Gen "B86bPBE" "B86bPBE-25"
BSC_Gen "B86bPBE" "B86bPBE-50"
###################################
echo "BSC Structures Created Successfully"

echo "Generating eval_driver_delta.m input directories:"
find "$(pwd)/BSC/" -type d -name "lightdenser" | sed 's/$/",.../' | sed 's/\/home/     "\/home/g' | sort
