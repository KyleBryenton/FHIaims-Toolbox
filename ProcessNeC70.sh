#!/bin/bash

# ProcessNeC70.sh
# Kyle Bryenton - 2025-02-01
#
# Created for:
# K. Panchagnula, D. Graf, K.R. Bryenton, E.R. Johnson, and A.J.W. Thom
# "Endofullerenes and Dispersion-Corrected Density Functional Approximations: A Cautionary Tale
# (2025)
#
# This script is run by supplying a list of paths to *.out files to process
# Each one processed will be one row in a table of data



# Set as as desired.
z2pm_flag=false
z5pm_flag=true
filename="ProcessNeC70"

if [ $# == 0 ]; then
    echo "ERROR: No *.out files detected. Exiting."                    >&2
    echo "USAGE: $0 \$(find . -name "*.out" | sort --version-sort)"    >&2
    echo "    This appends results to the same file as a single line." >&2
    echo "    You may also list paths manually to *.out files."        >&2
    exit 1
fi

# Partially processes/prunes raw data, again in same order you see in the header.
rm "$filename.po_temp" 2> /dev/null
for inFile in "$@" ; do 
    echo "!! $(echo ${inFile%.out} | awk -F "/" '{print $NF}')" ;
    en_tot_ev=$(grep "| Total energy uncorrected" "$inFile" | awk '{printf "%.15f", $(NF-1)}') ;
    en_xdm_ha=$(grep "| XDM dispersion energy" "$inFile" | awk '{printf "%.15f", $(NF-1)}') ; 
    en_tot_cm=$(echo "$en_tot_ev * 8100.0" | bc -l) ;
    en_xdm_cm=$(echo "$en_xdm_ha * 220000.0" | bc -l) ;
    en_no_xdm=$(echo "$en_tot_cm - $en_xdm_cm" | bc -l) ;
    echo $en_tot_ev ; 
    echo $en_xdm_ha ;
    echo $en_tot_cm ; 
    echo $en_xdm_cm ; 
    echo $en_no_xdm ;
done >> "$filename.NeC70_temp"

# Collapeses each system into a single row of the table, and adds a header
cat "$filename.NeC70_temp" \
    | tr "\n" " " \
    | sed "s/!! /\n/g" \
    | sed '$a\' \
    | sort --version-sort \
    | sed '1s/.*/\System Total_Energy(eV) XDM_Energy(Ha) Total_Energy_(cm^-1) XDM_Energy(cm^-1) Dispersionless_Energy(cm^-1)/' \
    | awk '{printf "%-27s %-27s %-27s %-27s %-27s %-27s \n", $1, $2, $3, $4, $5, $6}' \
    > "${filename}_Absolute.dat"
rm "$filename.NeC70_temp"

# Get data subsets
if [ "$z2pm_flag" = true ] ; then 
    read -a z2pm20 <<< $(grep "Ne@C70z2pm_20" "${filename}_Absolute.dat")
fi
if [ "$z5pm_flag" = true ] ; then
    read -a z5pm20 <<< $(grep "Ne@C70z5pm_20" "${filename}_Absolute.dat")
fi

# Create an array from 2pm_20 reference
if [ "$z2pm_flag" = true ] ; then
    head -n 1 "${filename}_Absolute.dat" \
        | awk '{printf "%-22s %-22s %-22s %-22s %-22s %-22s \n", $1, $2, $3, $4, $5, $6}' \
        >  "${filename}_Relative_z2pm20.dat"                                 # Get Header
    tail -n +2 "${filename}_Absolute.dat" | while read -a line; do           # Loop from row 2 onwards
        printf "%-22s " "${line[0]}" >> "${filename}_Relative_z2pm20.dat"    # Print the system name
        for ((i=1; i<${#line[@]}; i++)); do                                  # Loop from col 2 onwards
            result=$(echo "${line[i]} - ${z2pm20[i]}" | bc -l)               # Array subtract ref value using bc -l
            printf "%-22s " "$result" >> "${filename}_Relative_z2pm20.dat"   # Append result to output file
        done                                                                 
        printf "\n" >> "${filename}_Relative_z2pm20.dat"                                        
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

