#!/bin/bash

# ProcessGMTKN55.sh
# Kyle Bryenton - 2025-05-05
#    This script is run by supplying a list of paths to *.results files to process
#    The .results files are the output of eval_driver.m
#    Each .results file should contain the error metrics for each of the 55 subset for one basis/functional combination
#    The order you want the results in is located at the top of the file
#    Each .results file will print either the MAE or ME as a column in the output

# Check for input files
if [ $# == 0 ]; then
    echo "ERROR: No *.results files detected. Exiting."                >&2
    echo "USAGE: $0 PBE.results B86bPBE.results BHLYP.results ...)"    >&2
    exit 1
fi
args=("$@")

# Rearrange rows to change the subset ordering in the output:
#     Column 1: Subset Name
#     Column 2: Number of systems in the subset
#     Column 3: Average relative absolute energy \bar{|\Delta E|} in kcal/mol        [Used for WTMAD-2]
#     Column 4: Weight (=10.0 if deltaE < 7.5, =0.1 if deltaE > 75, = 1.0 otherwise) [Used for WTMAD-1]
GMTKN55_info=(
  "AL2X6        6     35.88     1.0"
  "ALK8         8     62.60     1.0"
  "ALKBDE10    10    100.69     0.1"
  "BH76RC      30     21.39     1.0"
  "DC13        13     54.98     1.0"
  "DIPCS10     10    654.26     0.1"
  "FH51        51     31.01     1.0"
  "G21EA       25     33.62     1.0"
  "G21IP       36    257.61     0.1"
  "G2RC        25     51.26     1.0"
  "HEAVYSB11   11     58.02     1.0"
  "NBPRC       12     27.71     1.0"
  "PA26        26    189.05     0.1"
  "RC21        21     35.70     1.0"
  "SIE4x4      16     33.72     1.0"
  "TAUT15      15      3.05    10.0"
  "W4-11      140    306.91     0.1"
  "YBDE18      18     49.28     1.0"
  "BH76        76     18.61     1.0"
  "BHDIV10     10     45.33     1.0"
  "BHPERI      26     20.87     1.0"
  "BHROT27     27      6.27    10.0"
  "INV24       24     31.85     1.0"
  "PX13        13     33.36     1.0"
  "WCPT18      18     34.99     1.0"
  "BSR36       36     16.20     1.0"
  "C60ISO       9     98.25     0.1"
  "CDIE20      20      4.06    10.0"
  "DARC        14     32.47     1.0"
  "ISO34       34     14.57     1.0"
  "ISOL24      24     21.92     1.0"
  "MB16-43     43    414.73     0.1"
  "PArel       20      4.63    10.0"
  "RSE43       43      7.60     1.0"
  "ACONF       15      1.83    10.0"
  "Amino20x4   80      2.44    10.0"
  "BUT14DIOL   64      2.80    10.0"
  "ICONF       17      3.27    10.0"
  "IDISP        6     14.22     1.0"
  "MCONF       51      4.97    10.0"
  "PCONF21     18      1.62    10.0"
  "SCONF       17      4.60    10.0"
  "UPU23       23      5.72    10.0"
  "ADIM6        6      3.36    10.0"
  "AHB21       21     22.49     1.0"
  "CARBHB12    12      6.04    10.0"
  "CHB6         6     26.79     1.0"
  "HAL59       59      4.59    10.0"
  "HEAVY28     28      1.24    10.0"
  "IL16        16    109.04     0.1"
  "PNICO23     23      4.27    10.0"
  "RG18        18      0.58    10.0"
  "S22         22      7.30    10.0"
  "S66         66      5.47    10.0"
  "WATER27     27     81.14     0.1"
)

# Extract the above info, and store as ordered arrays
declare -a subsets
declare -a systems
declare -a deltaEs
declare -a weights
for info in "${GMTKN55_info[@]}" ; do 
    read subset n_syst deltaE weight<<< "$info"
    subsets+=("$subset")
    systems+=("$n_syst")
    deltaEs+=("$deltaE")
    weights+=("$weight")
done

# Print input parameters back to the user
tot_input=$#
tot_subsets=${#subsets[@]}
tot_systems=$(printf "%s\n" "${systems[@]}" | awk '{sum+=$1} END {print sum}')
tot_deltaEs=$(printf "%s\n" "${deltaEs[@]}" | awk '{sum+=$1} END {print sum}')
deltaEBar_tot=$(echo $tot_deltaEs/$tot_subsets | bc -l)
printf "Number of Inputs:   %d\n"   "$tot_input"
printf "Number of Subsets:  %d\n"   "$tot_subsets"
printf "Number of Systems:  %d\n"   "$tot_systems"
printf "DeltaEBar_Total:    %.2f\n" "$deltaEBar_tot"

# Set the column width to max(10, longest input file name)
cw=11
for inFile in "$@" ; do
    lenFilename=$(expr length "${inFile%.results}")
    if [ $((lenFilename + 1)) -gt $cw ] ; then
        cw=$((lenFilename + 1))
    fi
done

# Fetch the Mean Absolute Errors (MAE or MAD) for each input
declare -A mad_array
for i in "${!subsets[@]}" ; do
    subset="${subsets[$i]}"
    n_syst="${systems[$i]}"
    # eval_driver.m prints 9 extra rows of extra data per subset, minus 1 for the din row = n_syst + 8
    n_line=$(($n_syst + 8))
    for j in "${!args[@]}" ; do
        inFile="${args[$j]}"
        mad_value=$(grep -A "$n_line" "^## data dir:.*${subset}$" "$inFile" | grep "MAE" | awk '{print $NF}')
        mad_array["$i,$j"]="$mad_value"
    done
done

# Calculate WTMAD-1
# \text{WTMAD-1} = \frac{1}{55} \sum_{i=1}^{55} w_{i} \cdot \text{MAD}_{i}
declare -a wtmad1
for j in "${!args[@]}" ; do
    wtmad1[$j]=0.0
    for i in "${!subsets[@]}" ; do
        wtmad1_elem=$(echo "${weights[$i]} * ${mad_array["$i,$j"]}" | bc -l)
        wtmad1[$j]=$(echo "${wtmad1[$j]} + $wtmad1_elem" | bc -l)
    done
    wtmad1[$j]=$(echo "${wtmad1[$j]} / $tot_subsets" | bc -l)
done

# Calculate WTMAD-2
#\text{WTMAD-2} = \sum_{i=1}^{55} \frac{N_{i}}{N_{\text{total}}} \cdot \frac{ {\overline{|\Delta E|}_{\text{total}}}  }{\overline{|\Delta E|}_{i}} \cdot \text{MAD}_{i}
declare -a wtmad2
for j in "${!args[@]}" ; do
    wtmad2[$j]=0.0
    for i in "${!subsets[@]}" ; do
        wtmad2_elem=$(echo "${systems[$i]} * $deltaEBar_tot * ${mad_array["$i,$j"]} / ${deltaEs[$i]}" | bc -l)
        wtmad2[$j]=$(echo "${wtmad2[$j]} + $wtmad2_elem" | bc -l)
    done
    wtmad2[$j]=$(echo "${wtmad2[$j]} / $tot_systems" | bc -l)
done

# Calculate WTMAD-3
# \text{WTMAD-3} = \sum_{i=1}^{55} \frac{N_{i}^{\text{damp}}}{N_{\text{total}}} \cdot \frac{ {\overline{|\Delta E|}_{\text{total}}}  }{\overline{|\Delta E|}_{i}} \cdot \text{MAD}_{i}
# N_i^{\text{damp}} = \max(0.1 \, N_{\text{total}} \, , \, N_i)
declare -a wtmad3
ni_max=$(echo "0.01 * $tot_systems" | bc -l)
for j in "${!args[@]}" ; do
    wtmad3[$j]=0.0
    for i in "${!subsets[@]}" ; do
        if (( $(echo "${systems[$i]} > $ni_max" | bc -l) )) ; then
            ni_damp=$ni_max
        else
            ni_damp=${systems[$i]}
        fi
        wtmad3_elem=$(echo " $ni_damp * $deltaEBar_tot * ${mad_array["$i,$j"]} / ${deltaEs[$i]}" | bc -l)
        wtmad3[$j]=$(echo "${wtmad3[$j]} + $wtmad3_elem" | bc -l)
    done
    wtmad3[$j]=$(echo "${wtmad3[$j]} / $tot_systems" | bc -l)
done


# Print Header
printf "%-${cw}s %-${cw}s %-${cw}s | " "Subset" "N.Systems" "DeltaEBar"
for inFile in "$@"; do
    printf "%-${cw}s " "${inFile%.results}"
done
printf "\n"

# Print MAD Rows
for i in "${!subsets[@]}" ; do
    printf "%-${cw}s %-${cw}s %-${cw}s | " "${subsets[$i]}" "${systems[$i]}" "${deltaEs[$i]}"
    for j in "${!args[@]}" ; do
        printf "%-${cw}.2f " ${mad_array["$i,$j"]}
    done
    printf "\n"
done

# Print WTMAD-1 Row
printf "%-${cw}s %-${cw}s %-${cw}s : " " | WTMAD-1" "" ""
for j in "${!args[@]}" ; do
    printf "%-${cw}.2f " "${wtmad1[$j]}"
done
printf "\n"

# Print WTMAD-2 Final Row
printf "%-${cw}s %-${cw}s %-${cw}s : " " | WTMAD-2" "" ""
for j in "${!args[@]}" ; do
    printf "%-${cw}.2f " "${wtmad2[$j]}"
done
printf "\n"

# Print WTMAD-3 Final Row
printf "%-${cw}s %-${cw}s %-${cw}s : " " | WTMAD-3" "" ""
for j in "${!args[@]}" ; do
    printf "%-${cw}.2f " "${wtmad3[$j]}"
done
printf "\n"

