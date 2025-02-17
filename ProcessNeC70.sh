#!/bin/bash

# ProcessNeC70.sh
# Kyle Bryenton - 2025-02-17
#
# Created for:
# K. Panchagnula, D. Graf, K.R. Bryenton, E.R. Johnson, and A.J.W. Thom
# "Endofullerenes and Dispersion-Corrected Density Functional Approximations: A Cautionary Tale
# (2025)
#
# This script is run by supplying a list of paths to *.out files to process
# Each one processed will be one row in a table of data



# Set as as desired.
z2pm_flag=true
z5pm_flag=true
filename="ProcessNeC70"

#Set these as needed for your code version
E_Tot_Str="| Total energy uncorrected"  # Ensure NF-1 is used for the awk index on line ~39
#E_Disp_Str="Libmbd: Evaluated energy:"  # Ensure NF is used for the awk index on line ~40
E_Disp_Str="| XDM dispersion energy"    # Ensure NF-1 is used for the awk index on line ~40


if [ $# == 0 ]; then
    echo "ERROR: No *.out files detected. Exiting."                    >&2
    echo "USAGE: $0 \$(find . -name "*.out" | sort --version-sort)"    >&2
    echo "    This appends results to the same file as a single line." >&2
    echo "    You may also list paths manually to *.out files."        >&2
    exit 1
fi

# Partially processes/prunes raw data, again in same order you see in the header.
rm "$filename.NeC70_temp" 2> /dev/null
for inFile in "$@" ; do 
    echo "!! $(echo ${inFile%.out} | awk -F "/" '{print $NF}')" ;
    en_tot_ev=$(grep "$E_Tot_Str" "$inFile" | awk '{printf "%.15f", $(NF-1)}') ;
    en_disp_ha=$(grep "$E_Disp_Str" "$inFile" | awk '{printf "%.15f", $(NF-1)}') ;
    en_tot_cm=$(echo "$en_tot_ev * 8100.0" | bc -l) ;
    en_disp_cm=$(echo "$en_disp_ha * 220000.0" | bc -l) ;
    en_nodisp_cm=$(echo "$en_tot_cm - $en_disp_cm" | bc -l) ;
    echo $en_tot_ev ; 
    echo $en_disp_ha ;
    echo $en_tot_cm ; 
    echo $en_disp_cm ; 
    echo $en_nodisp_cm ;
done > "$filename.NeC70_temp"

# Collapeses each system into a single row of the table, and adds a header
cat "$filename.NeC70_temp" \
    | tr "\n" " " \
    | sed "s/!! /\n/g" \
    | sed '$a\' \
    | sort --version-sort \
    | sed '1s/.*/\System E_Total(eV) E_Disp(Ha) E_Total(cm^-1) E_Disp(cm^-1) E_Dispersionless(cm^-1)/' \
    | awk '{printf "%-27s %-27s %-27s %-27s %-27s %-27s \n", $1, $2, $3, $4, $5, $6}' \
    > "${filename}_Absolute.dat"
rm "$filename.NeC70_temp"

# Get data subsets
if [ "$z2pm_flag" = true ] ; then 
    read -a z2pm50 <<< $(grep "Ne@C70z2pm_50" "${filename}_Absolute.dat")
fi
if [ "$z5pm_flag" = true ] ; then
    read -a z5pm20 <<< $(grep "Ne@C70z5pm_20" "${filename}_Absolute.dat")
fi

# Create an array from 2pm_50 reference
if [ "$z2pm_flag" = true ] ; then
    head -n 1 "${filename}_Absolute.dat" \
        | awk '{printf "%-22s %-22s %-22s %-22s %-22s %-22s \n", $1, $2, $3, $4, $5, $6}' \
        >  "${filename}_Relative_z2pm50.dat"                                 # Get Header
    tail -n +2 "${filename}_Absolute.dat" | while read -a line; do           # Loop from row 2 onwards
        printf "%-22s " "${line[0]}" >> "${filename}_Relative_z2pm50.dat"    # Print the system name
        for ((i=1; i<${#line[@]}; i++)); do                                  # Loop from col 2 onwards
            result=$(echo "${line[i]} - ${z2pm50[i]}" | bc -l)               # Array subtract ref value using bc -l
            printf "%-22s " "$result" >> "${filename}_Relative_z2pm50.dat"   # Append result to output file
        done                                                                 
        printf "\n" >> "${filename}_Relative_z2pm50.dat"                                        
    done
fi

# Create an array from 5pm_20 reference
if [ "$z5pm_flag" = true ] ; then
    head -n 1 "${filename}_Absolute.dat" \
        | awk '{printf "%-22s %-22s %-22s %-22s %-22s %-22s \n", $1, $2, $3, $4, $5, $6}' \
        >  "${filename}_Relative_z5pm20.dat"                                 # Get Header
    tail -n +2 "${filename}_Absolute.dat" | while read -a line; do           # Loop from row 2 onwards
        printf "%-22s " "${line[0]}" >> "${filename}_Relative_z5pm20.dat"    # Print the system name
        for ((i=1; i<${#line[@]}; i++)); do                                  # Loop from col 2 onwards
            result=$(echo "${line[i]} - ${z5pm20[i]}" | bc -l)               # Array subtract ref value using bc -l
            printf "%-22s " "$result" >> "${filename}_Relative_z5pm20.dat"   # Append result to output file
        done
        printf "\n" >> "${filename}_Relative_z5pm20.dat"
    done
fi

