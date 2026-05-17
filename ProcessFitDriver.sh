#!/bin/bash

version_stamp=2.00

# Kyle R Bryenton 2026-05-16 <kyle.bryenton@gmail.com>
# ProcessFitDriver.sh
# Available at: https://github.com/KyleBryenton/FHIaims-Toolbox
# Version: 2.00
# ChangeLog:
#     v1.00 - 2025-07-31 - Initial implementation, for use with fit_driver from 2019
#     v2.00 - 2026-05-16 - Updated version that works with Z damping. Works with most up-to-date version of fit_driver
#                          Total rewrite from previous version. Some features were discontinued such as output to .params
# Run using:
#     ./ProcessFitDriver.sh <list of paths to fit_driver.m outputs>
#
# Purpose:
#     This script will combine outputs from 50_fit/fit_driver.m from https://github.com/aoterodelaroza/refdata
#     It summarizes them into a convenient table with relevant error metrics and damping parameters.
#     Note that a1<0 and a2<0 are rejected and a warning will be generated to the user However, if BJ0 
#     and BJa20 results are also supplied as input files, it will automatically replace the result with
#     negative a1 or a2 values with the lowest RMSP version that satisfies a1>=0 and a2>=0. 
#     Matching between functionals is done through columns generated from the path in the "## FIT for:" line.
#     Note that BJ damping and Z damping cannot be processed at the same time.


# How many columns to generate based on the directory path from the "## FIT for:" line:
n_cols=3

# Print one output per input fit-driver.m output. (True = 1, False = 0)
partial_print=0



# End of user setable area

# Check for input files
if [ $# == 0 ]; then
    echo "ERROR: No *.results files detected. Exiting."                >&2
    echo "USAGE: $0 kb49_energy_bj.results kb49_energy_bj0.results kb49_energy_bja20.results ..."    >&2
    exit 1
fi

declare -a n_entries lens
declare -A Cols a1 a2 z_damp nSet MAD MaxAD MaxAD_Set RMS MAPD MaxAPD MaxAPD_Set RMSP

# Detects damping type by grepping the fit_driver.m outputs.
# Mixing between BJ and Z isn't permitted.
# Set DampType
if grep -q "a1 =" "${1}" && ! grep -q "z_damp =" "${1}" ; then
    dampType=1
elif ! grep -q "a1 =" "${1}" && grep -q "z_damp =" "${1}" ; then
    dampType=2
else
    echo "ERROR: cannot determine dampType" >&2
    exit 1
fi

# Loop through all input files
max_len=0
index=0
for res in "$@" ; do
    
    # Populate Arrays
    myCols=(       $(grep "## FIT for:"    "$res" | awk -F "/" -v n="$n_cols" ' {
        for (i = NF - n + 1; i <= NF; i++) {
            printf $i
            if (i < NF) printf "/" 
        } printf "\n"
    }'))
    mynSet=(       $(grep "Dataset size =" "$res" | awk '{print $NF}'))
    myMAD=(        $(grep "MAD    ="       "$res" | awk '{print $NF}'))
    myMaxAD=(      $(grep "MaxAD  ="       "$res" | awk '{print $(NF-1)}'))
    myMaxAD_Set=(  $(grep "MaxAD  ="       "$res" | awk '{print $NF}'))
    myRMS=(        $(grep "RMS    ="       "$res" | awk '{print $NF}'))
    myMAPD=(       $(grep "MAPD   ="       "$res" | awk '{print $NF}'))
    myMaxAPD=(     $(grep "MaxAPD ="       "$res" | awk '{print $(NF-1)}'))
    myMaxAPD_Set=( $(grep "MaxAPD ="       "$res" | awk '{print $NF}'))
    myRMSP=(       $(grep "RMSP   ="       "$res" | awk '{print $NF}'))
    if (( dampType==1 )) ; then
        mya1=(         $(grep "a1 ="           "$res" | awk '{print $(NF-4)}'))
        mya2=(         $(grep "a2(ang) ="      "$res" | awk '{print $NF}'))
    elif (( dampType==2 )) ; then
        myz_damp=(     $(grep "z_damp ="       "$res" | awk '{print $NF}'))
    fi
    
    # Ensure all are the same length
    n_entries[$index]=${#myCols[@]}
    if ((
      ${#mynSet[@]}       != n_entries ||
      ${#myMAD[@]}        != n_entries ||
      ${#myMaxAD[@]}      != n_entries ||
      ${#myMaxAD_Set[@]}  != n_entries ||
      ${#myRMS[@]}        != n_entries ||
      ${#myMAPD[@]}       != n_entries ||
      ${#myMaxAPD[@]}     != n_entries ||
      ${#myMaxAPD_Set[@]} != n_entries ||
      ${#myRMSP[@]}       != n_entries
    )) ; then
        echo "ERROR: Array length mismatch in $res." >&2
        echo "       Make sure the fit_driver.m results are properly formatted." >&2
        exit 1
    fi
    if (( dampType==1 && (${#mya1[@]} != n_entries || ${#mya2[@]} != n_entries) )) ; then
        echo "ERROR: Array length mismatch in $res." >&2
        echo "       DampType=BJ and a2 array wrong length" >&2
        echo "       Ensure you're not processing both BJ and Z damping simultaneously." >&2
        exit 1
    fi
    if (( dampType==2 && ${#myz_damp[@]} != n_entries )) ; then
        echo "ERROR: Array length mismatch in $res." >&2
        echo "       DampType=Z and z_damp array wrong length." >&2
        echo "       Ensure you're not processing both BJ and Z damping simultaneously." >&2
        exit 1
    fi

    # Copy to associative arrays
    for (( i=0 ; i<${n_entries[$index]} ; i++ )) ; do
       # Col1["$index,$i"]="${myCol1[$i]}"
       # Col2["$index,$i"]="${myCol2[$i]}"
       # Col3["$index,$i"]="${myCol3[$i]}"
        Cols["$index,$i"]="${myCols[$i]}"
        nSet["$index,$i"]="${mynSet[$i]}"
        MAD["$index,$i"]="${myMAD[$i]}"
        MaxAD["$index,$i"]="${myMaxAD[$i]}"
        MaxAD_Set["$index,$i"]="${myMaxAD_Set[$i]}"
        RMS["$index,$i"]="${myRMS[$i]}"
        MAPD["$index,$i"]="${myMAPD[$i]}"
        MaxAPD["$index,$i"]="${myMaxAPD[$i]}"
        MaxAPD_Set["$index,$i"]="${myMaxAPD_Set[$i]}"
        RMSP["$index,$i"]="${myRMSP[$i]}"
        if (( dampType==1 )) ; then
            a1["$index,$i"]="${mya1[$i]}"
            a2["$index,$i"]="${mya2[$i]}"
        elif (( dampType==2 )) ; then
            z_damp["$index,$i"]="${myz_damp[$i]}"
        fi
    done
   
    # If user requested printing partial output, do so.
    if (( partial_print == 1 )) ; then

        # Get max length of first column
        len=7
        for str in "${myCols[@]}" ; do
            if (( ${#str} > len )) ; then
                len=${#str}
            fi
        done

        # Get the max length of all input files.
        if (( len > max_len )) ; then
            max_len=$len
        fi

        # Print File
        if (( dampType==1 )) ; then
            printf "%*s %8s %8s %8s %8s %8s %8s %8s %14s %14s\n" \
            "$len" "Dataset" \
            "nSet" "MAD" "MaxAD" "RMS" "MAPD" "MaxAPD" "RMSP" "a1" "a2(ang)" > "${res}.dat"
        elif (( dampType==2 )) ; then
            printf "%*s %8s %8s %8s %8s %8s %8s %8s %14s\n" \
            "$len" "Dataset" \
            "nSet" "MAD" "MaxAD" "RMS" "MAPD" "MaxAPD" "RMSP" "z_damp(Ha^-1)" > "${res}.dat"
        fi
        for (( i=0 ; i<${n_entries[$index]} ; i++ )) ; do
            printf "%*s " "$len" "${myCols[$i]}" >> "${res}.dat"
            printf "%8d %8.3f %8.3f %8.3f %8.3f %8.3f %8.3f " "${mynSet[$i]}" "${myMAD[$i]}" "${myMaxAD[$i]}" "${myRMS[$i]}" "${myMAPD[$i]}" "${myMaxAPD[$i]}" "${myRMSP[$i]}" >> "${res}.dat"
            if (( dampType==1 )) ; then
                printf "%14.8f %14.8f\n" "${mya1[$i]}" "${mya2[$i]}" >> "${res}.dat"
            elif (( dampType==2 )) ; then
                printf "%14.4f\n" "${myz_damp[$i]}" >> "${res}.dat"
            fi
        done

    fi
    
    # Increment Index
    ((index++))
done



# Join all data into a single output
# I'm lazy, so lets just make a temp file to work with and delete it later.
script_name=${0##*/}
script_name=${script_name%.sh}
if (( dampType==1 )) ; then
    # BJ damping is hard, need to check for a1,a2<0 and scan for valid versions.
    # Print Header
    printf "%*s %8s %8s %8s %8s %8s %8s %8s %14s %14s\n" \
        "$max_len" "Dataset" \
        "nSet" "MAD" "MaxAD" "RMS" "MAPD" "MaxAPD" "RMSP" "a1" "a2(ang)" > "$script_name.temp1"
    # Print Table
    for (( index=0 ; index<$# ; index++ )) ; do
        for (( i=0 ; i<${n_entries[$index]} ; i++ )) ; do
            if (( $(echo "${a1["$index,$i"]} >= 0" | bc ) && $(echo "${a2["$index,$i"]} >= 0" | bc ) )) ; then
                #Then a1,a2>0, so print this result normally.
                printf "%*s %8d %8.3f %8.3f %8.3f %8.3f %8.3f %8.3f %14.8f %14.8f\n" \
                    "$max_len" "${Cols["$index,$i"]}" \
                    "${nSet["$index,$i"]}" "${MAD["$index,$i"]}" "${MaxAD["$index,$i"]}" "${RMS["$index,$i"]}" \
                    "${MAPD["$index,$i"]}" "${MaxAPD["$index,$i"]}" "${RMSP["$index,$i"]}" \
                    "${a1["$index,$i"]}" "${a2["$index,$i"]}" >> "$script_name.temp1"
            else
                # If either a1<0 or a2<0, then this isn't a valid match, so search for one and print it
                # Looping over all Cols isn't very efficient, but this should be a rare occurance and isn't bottleneck
                # Would be faster to use a lookup array, if ever needed.
                Cols_temp=${Cols["$index,$i"]}
                for (( index2=0 ; index2<$# ; index2++ )) ; do
                    for (( i2=0 ; i2<${n_entries[$index2]} ; i2++ )) ; do
                        if [[ "$Cols_temp" == "${Cols["$index2,$i2"]}" ]] ; then
                            if (( $(echo "${a1["$index2,$i2"]} >= 0" | bc ) && $(echo "${a2["$index2,$i2"]} >= 0" | bc ) )) ; then
                                # A match was found, print it, then continue to next i in n_entries[index]
                                printf "%*s %8d %8.3f %8.3f %8.3f %8.3f %8.3f %8.3f %14.8f %14.8f\n" \
                                    "$max_len" "${Cols["$index2,$i2"]}" \
                                    "${nSet["$index2,$i2"]}" "${MAD["$index2,$i2"]}" "${MaxAD["$index2,$i2"]}" "${RMS["$index2,$i2"]}" \
                                    "${MAPD["$index2,$i2"]}" "${MaxAPD["$index2,$i2"]}" "${RMSP["$index2,$i2"]}" \
                                    "${a1["$index2,$i2"]}" "${a2["$index2,$i2"]}" >> "$script_name.temp1"
                                continue 3 # Loops are index, i, index2, i2. So continue 3 takes us back to i.
                            fi
                        fi
                    done
                done
                # No match was found, just print the negative version I suppose and warn user.
                echo "WARNING: No version of '$Cols_temp' found with both a1,a2 >= 0" >&2
                printf "%*s %8d %8.3f %8.3f %8.3f %8.3f %8.3f %8.3f %14.8f %14.8f\n" \
                    "$max_len" "${Cols["$index,$i"]}" \
                    "${nSet["$index,$i"]}" "${MAD["$index,$i"]}" "${MaxAD["$index,$i"]}" "${RMS["$index,$i"]}" \
                    "${MAPD["$index,$i"]}" "${MaxAPD["$index,$i"]}" "${RMSP["$index,$i"]}" \
                    "${a1["$index,$i"]}" "${a2["$index,$i"]}" >> "$script_name.temp1"
            fi
        done
    done
elif (( dampType==2 )) ; then
    # Z damping is the easy one. Just shove all tables together.
    index=0
    # Print Header
    printf "%*s %8s %8s %8s %8s %8s %8s %8s %14s\n" \
        "$max_len" "Dataset" \
        "nSet" "MAD" "MaxAD" "RMS" "MAPD" "MaxAPD" "RMSP" "z_damp(Ha^-1)" > "$script_name.temp1"
    # Print Table
    for (( index=0 ; index<$# ; index++ )) ; do
        for (( i=0 ; i<${n_entries[$index]} ; i++ )) ; do
            printf "%*s %8d %8.3f %8.3f %8.3f %8.3f %8.3f %8.3f %14.4f\n" \
                "$max_len" "${Cols["$index,$i"]}" \
                "${nSet["$index,$i"]}" "${MAD["$index,$i"]}" "${MaxAD["$index,$i"]}" "${RMS["$index,$i"]}" \
                "${MAPD["$index,$i"]}" "${MaxAPD["$index,$i"]}" "${RMSP["$index,$i"]}" \
                "${z_damp["$index,$i"]}" >> "$script_name.temp1"
        done
    done
fi

# Refine this file so it's easier to work with:
# 1. Tail it to take all but the header, we will reprint this later.
# 2. Sort this file, then we can walk through it with O(N) first by dataset, then by RMSP value
# 3. Since it's sorted by RMSP within datasets, only the first (and lowest) is used. 
#    Awk can print the first time the dataset is seen, efficiently merging BJ/BJ0/BJa20 data
# 4. Break the first column up into `n_cols` parts by replacing `/`->` `
tail +2 "$script_name.temp1" | sort -k1,1 -k8,8n \
                            | awk '!seen[$1]++' \
                            | sed "s/\// /g" \
                            > "$script_name.temp2"

# For the first `n_cols` columns, and count the max length within each one.
for (( i=1 ; i<=$n_cols ; i++ )) ; do
    
    # Extract ith column
    myCol=($(awk -v i=$i '{print $i}' "$script_name.temp2"))

    # Get max length of the ith column
    len=7
    for str in "${myCol[@]}" ; do
        if (( ${#str} > len )) ; then
            len=${#str}
        fi
    done

    # Save value
    lens[$i]=$len
done

# Print File
# Start with header:
rm -f "$script_name.temp3" 
for (( i=1 ; i<=$n_cols ; i++ )) ; do
    printf "%*s  " ${lens[$i]} "Dir_$i" >> "$script_name.temp3"
done
printf "%8s  %8s  %8s  %8s  %8s  %8s  %8s  " "nSet" "MAD" "MaxAD" "RMS" "MAPD" "MaxAPD" "RMSP" >> "$script_name.temp3"
if (( dampType==1 )) ; then
    printf "%14s  %14s  \n" "a1" "a2(ang)" >> "$script_name.temp3"
elif (( dampType==2 )) ; then
    printf "%14s  \n" "z_damp(Ha^-1)" >> "$script_name.temp3"
fi

# Now print the table
awk -v n=$n_cols -v lens_str="${lens[*]}" -v d=$dampType '
BEGIN {
    # Have to split lens[@] into a string, then read it within awk
    # This splits it up using space as the delimeter, and sets it to 'w' variable
    split(lens_str, w, " ")
}
{
    # Print the variable-width columns
    for ( i=1 ; i <= n ; i++ )
        printf "%*s  ", w[i], $i

    # Print the n_set column
    printf "%8d  ", $(n+1)

    # Print the 6 error columns
    for ( i=n+2 ; i <= n+7 ; i++ )
        printf "%8.4f  ", $i

    # If BJ damping, print BJ elements, else print Z element
    if ( d == 1 ) {
        printf "%14.8f  %14.8f  \n", $(n+8), $(n+9)
    } else {
        printf "%14.4f  \n", $(n+8)
    }
}
' "$script_name.temp2" >> "$script_name.temp3"

# Print header:
echo "-----------------------------------------------"
echo "Starting $script_name Version $version_stamp"
echo "$(pwd)"
echo "$(TZ=America/Halifax date +"%Y-%m-%d %H:%M:%S")"
echo "-----------------------------------------------"


# Re-sort just in case, and remove temp files. Output to standard output.
# Sort the first 7 columns, surely that will get all the header columns and doesn't matter beyond there.
head -n 1 "$script_name.temp3" 
tail -n +2 "$script_name.temp3" | sort -k1,1 -k2,2 -k3,3 -k4,4 -k5,5 -k6,6 -k7,7

# Clean up temp files
rm "$script_name.temp1" "$script_name.temp2" "$script_name.temp3"

