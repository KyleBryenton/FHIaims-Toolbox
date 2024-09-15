#!/bin/bash

# DenseConstructor.sh
# Kyle Bryenton - 2024-09-15
#
# This script takes two arguments
# <basis dir> = The basis you want to take the basis functions from
# <grids dir> = The basis you want to take the integration grids from
#
# It then generates a new folder and containing basis that combines these two


if [ $# -ne 2 ]; then
    echo "ERROR: Must provide two dirs. One for basis, one for grids. Exiting." >&2
    echo "USAGE: $0 <basis dir> <grids dir>"                                    >&2
    exit 1
fi

# Get input arguments
dir_basis=${1%/}
dir_grids=${2%/}
dir_output="${dir_basis}_with_${dir_grids}"

### Check input to make sure there are no issues
# Ensure no paths have been given, otherwise "dir_output" will dump stuff in random locations
if [[ "$dir_basis" == *"/"* || "$dir_grids" == *"/"* ]]; then
    echo "ERROW: Please provide directory names within the PWD only, not full paths."
    exit 1
fi
# Ensure the dir_output doesn't already exist to prevent overwriting something
if [[ -d "$dir_output" ]] ; then
    echo "ERROR: \"$dir_output\" already exists. Exiting."
    exit 1
else
    mkdir "$dir_output"
fi
# Ensure dir_basis and dir_grids contain exactly the same filenames, you can only combine if you have one of each
basis_files=$(find "$dir_basis" -type f -printf "%P\n" | sort)
grids_files=$(find "$dir_grids" -type f -printf "%P\n" | sort)
if [[ "$basis_files" != "$grids_files" ]]; then
    echo "ERROR: $dir_basis and $dir_grids do not contain the same filenames. Exiting."
    exit 1
fi

# DO WORK
for species in $dir_basis/* ; do
    sed -n '1,/radial_base/{ /radial_base/!p }'                 "${dir_basis}/${species##*/}" > "$dir_output/${species##*/}.temp1"
    sed -n '/radial_base/,/Definition of/{ /Definition of/!p }' "${dir_grids}/${species##*/}" > "$dir_output/${species##*/}.temp2"
    sed -n '/Definition of/,$p'                                 "${dir_basis}/${species##*/}" > "$dir_output/${species##*/}.temp3"
    cat "$dir_output/${species##*/}.temp1" "$dir_output/${species##*/}.temp2" "$dir_output/${species##*/}.temp3" > "$dir_output/${species##*/}"
    rm  "$dir_output/${species##*/}.temp1" "$dir_output/${species##*/}.temp2" "$dir_output/${species##*/}.temp3"
done

