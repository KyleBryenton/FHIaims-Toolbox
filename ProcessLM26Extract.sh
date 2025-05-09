#!/bin/bash

# ProcessLM26Extract.sh
# Kyle Bryenton - 2025-05-09
#
# Processes the output of extract_full.m
# The last two columns will be MAE and ME
#
# Usage: You will run extract_full.m per correction / basis / functional like this:
#
#     for disp in */ ; do 
#         cd $disp ; 
#         for basis in */ ; do 
#             cd $basis ; 
#             for funct in */ ; do
#                 cd $funct
#                 ~/scripts/extract_full.m > extract_full.result ; 
#                 cd .. ; 
#             done ; 
#             cd .. ; 
#         done
#         cd .. ; 
#     done
#
# Then you will run this script as follows:
#
#     ProcessLM26Extract.sh */*/*/extract_full.result
#
# It will use the filenames of however many directies deep it is to generate the columns.

# Check if any arguments are provided
if [ $# == 0 ]; then
    echo "ERROR: No result files selected. Exiting."                     >&2
    echo "USAGE: 1) $0 */*/*/extract_full.result  "                      >&2
    echo "       2) $0 \$(find . -name 'extract_full.result' | sort -V)" >&2
    echo                                                                 >&2
    echo "NOTE:  The last two columns will be MAE and ME"                >&2
    exit 1
fi

# Process the files passed as arguments
{
    echo "$PWD"
    (
    for arg in "$@"; do
        # Make sure the file exists
        if [ ! -f "$arg" ]; then
            echo "ERROR: File '$arg' not found." >&2
            continue
        fi
    
        # Extract filename without the extension
        # Removes the leading './' if the user used a find
        # Removes "extract_full" if it was left in, but keeps if renamed
        echo -n "${arg%.result}   " \
          | sed "s/extract_full//" \
          | sed "s|^\./||"
    
        # Extract the MAE and ME values using grep and awk
        grep "MAE " "$arg" | awk '{printf "%s  ", $NF}'
        grep "ME "  "$arg" | awk '{printf "%s  ", $NF}'
    
        # Print the result on a new line
        echo
    done
    ) \
      | sed "s|/| |g" \
      | awk '{ 
          for (i=1 ; i<=NF ; i++) {
              printf "%-12s  ", $i
          }
          printf "\n"
        }' 
} > ProcessLM26Extract.dat
