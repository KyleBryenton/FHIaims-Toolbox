#!/bin/bash

# ProcessGMTKN55.sh
# Kyle Bryenton - 2025-05-16
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


# For Groups "basic+ssmall, iso.+large, etc..." select which DeltaEBar_Mean to use:
# 0 = Use the same as the full GMTKN55 (how Grimme presented his stats in the original work)
# 1 = Recalculate DeltaEBar_Mean for each subset
deltaEBarMean_Type=0

# Print full partial stats report
# 0 = true
# 1 = false
partialStatsReport=0

# Rearrange rows to change the subset ordering in the output.
# Comment out a row to exclude that subset from the output.
# All errors will adjust accordingly, automatically.
#     Column 1: Subset Name
#     Column 2: Number of systems in the subset
#     Column 3: Average relative absolute energy \bar{|\Delta E|} in kcal/mol        [Used for WTMAD-2]
#     Column 4: Weight (=10.0 if deltaE < 7.5, =0.1 if deltaE > 75, = 1.0 otherwise) [Used for WTMAD-1]
#     Column 5: Indexing (0 = basicsmall, 1 = isolarge, 2 = barriers, 3 = intermolNCI, 4 = intramolNCI)
GMTKN55_info=(
  "AL2X6        6     35.88     1.0    0"
  "ALK8         8     62.60     1.0    0"
  "ALKBDE10    10    100.69     0.1    0"
  "BH76RC      30     21.39     1.0    0"
  "DC13        13     54.98     1.0    0"
  "DIPCS10     10    654.26     0.1    0"
  "FH51        51     31.01     1.0    0"
  "G21EA       25     33.62     1.0    0"
  "G21IP       36    257.61     0.1    0"
  "G2RC        25     51.26     1.0    0"
  "HEAVYSB11   11     58.02     1.0    0"
  "NBPRC       12     27.71     1.0    0"
  "PA26        26    189.05     0.1    0"
  "RC21        21     35.70     1.0    0"
  "SIE4x4      16     33.72     1.0    0"
  "TAUT15      15      3.05    10.0    0"
  "W4-11      140    306.91     0.1    0"
  "YBDE18      18     49.28     1.0    0"
  "BSR36       36     16.20     1.0    1"
  "C60ISO       9     98.25     0.1    1"
  "CDIE20      20      4.06    10.0    1"
  "DARC        14     32.47     1.0    1"
  "ISO34       34     14.57     1.0    1"
  "ISOL24      24     21.92     1.0    1"
  "MB16-43     43    414.73     0.1    1"
  "PArel       20      4.63    10.0    1"
  "RSE43       43      7.60     1.0    1"
  "BH76        76     18.61     1.0    2"
  "BHDIV10     10     45.33     1.0    2"
  "BHPERI      26     20.87     1.0    2"
  "BHROT27     27      6.27    10.0    2"
  "INV24       24     31.85     1.0    2"
  "PX13        13     33.36     1.0    2"
  "WCPT18      18     34.99     1.0    2"
  "ADIM6        6      3.36    10.0    3"
  "AHB21       21     22.49     1.0    3"
  "CARBHB12    12      6.04    10.0    3"
  "CHB6         6     26.79     1.0    3"
  "HAL59       59      4.59    10.0    3"
  "HEAVY28     28      1.24    10.0    3"
  "IL16        16    109.04     0.1    3"
  "PNICO23     23      4.27    10.0    3"
  "RG18        18      0.58    10.0    3"
  "S22         22      7.30    10.0    3"
  "S66         66      5.47    10.0    3"
  "WATER27     27     81.14     0.1    3"
  "ACONF       15      1.83    10.0    4"
  "Amino20x4   80      2.44    10.0    4"
  "BUT14DIOL   64      2.80    10.0    4"
  "ICONF       17      3.27    10.0    4"
  "IDISP        6     14.22     1.0    4"
  "MCONF       51      4.97    10.0    4"
  "PCONF21     18      1.62    10.0    4"
  "SCONF       17      4.60    10.0    4"
  "UPU23       23      5.72    10.0    4"
)

# Group names for partial benchmark statistics
group_names=( "basicsmall" "isolarge" "barriers" "intermolNCI" "intramolNCI" "allNCI" "GMTKN55" )







# Import Data

# Declare associative arrays
declare -A subsets
declare -A systems
declare -A deltEBs
declare -A weights

# Declare arrays for holding totals
declare -a subsets_total
declare -a systems_total
declare -a deltEBs_total
declare -a weights_total
declare -a deltEBs_mean

# Initialize arrays
declare -a index
for g in {0..6}; do
    index[$g]=0
    subsets_total[$g]=0
    systems_total[$g]=0
    deltEBs_total[$g]=0.0
    weights_total[$g]=0.0
    deltEBs_mean[$g]=0.0
done

# Loop through the top-level info array
for info in "${GMTKN55_info[@]}"; do
  # Read input line
  read subset system deltEB weight subcat <<< "$info"
  # Assign groups depending on subcat
  case $subcat in
    0) groups=(0 6) ;;
    1) groups=(1 6) ;;
    2) groups=(2 6) ;;
    3) groups=(3 5 6) ;;
    4) groups=(4 5 6) ;;
  esac
  # Loop through groups and gather data
  for g in "${groups[@]}"; do
    # Use "group,index" as key
    subsets["$g,${index[$g]}"]=$subset
    systems["$g,${index[$g]}"]=$system
    deltEBs["$g,${index[$g]}"]=$deltEB
    weights["$g,${index[$g]}"]=$weight
    # Update totals
    (( subsets_total[$g]++ ))
    (( systems_total[$g]+=system ))
    # Use bc for floating point sums
    deltEBs_total[$g]=$(echo "${deltEBs_total[$g]} + $deltEB" | bc -l)
    weights_total[$g]=$(echo "${weights_total[$g]} + $weight" | bc -l)
    # Increment the index for this group
    ((index[$g]++))
  done
done

# Calculate deltaEBar_mean for each group
for g in {0..6}; do
    if (( deltaEBarMean_Type == 0 )) ; then
        deltEBs_mean[$g]=$(echo "${deltEBs_total[6]} / ${subsets_total[6]}" | bc -l)
    elif (( deltaEBarMean_Type == 1 )) ; then
        deltEBs_mean[$g]=$(echo "${deltEBs_total[$g]} / ${subsets_total[$g]}" | bc -l)
    else
        echo "ERROR: DeltaEBarMean Type Not Supported. Exiting..." >&2
        exit 1
    fi
done

# Check for zero subset totals and warn
for g in "${!subsets_total[@]}" ; do
  if [[ "${subsets_total[$g]}" == "0" || -z "${subsets_total[$g]}" ]] ; then
    echo "Warning: subsets_total[$g] is zero or unset. Setting to 1 to avoid division by zero." >&2
    subsets_total[$g]=1
  fi
done

# Print GMTKN55 Input Statistics
printf "%s statistics:\n" "${group_names[6]}"
printf "  Number of Subsets:  %d\n" "${subsets_total[6]}"
printf "  Number of Systems:  %d\n" "${systems_total[6]}"
printf "  DeltaEBar_Total:    %.2f\n" "${deltEBs_total[6]}"
printf "  DeltaEBar_Mean:     %.2f\n" "${deltEBs_mean[6]}" 


# Set the column width to max(12, longest input file name)
cw=12
for inFile in "$@" ; do
    lenFilename=$(expr length "${inFile%.results}")
    if [ $((lenFilename + 1)) -gt $cw ] ; then
        cw=$((lenFilename + 1))
    fi
done

# Fetch the Mean Absolute Errors (MAE or MAD) for each input
declare -A mad_array
for g_i in "${!subsets[@]}"; do  # key is "g_i"
    IFS=',' read -r g i <<< "$g_i"
    subset="${subsets["$g,$i"]}"
    n_syst="${systems["$g,$i"]}"
    # eval_driver.m prints 9 extra rows of extra data per subset, minus 1 for the din row = n_syst + 8
    n_line=$(( n_syst + 8 ))
    for j in "${!args[@]}"; do
        inFile="${args[$j]}"
        mad_value=$(grep -A "$n_line" "^## data dir:.*${subset}$" "$inFile" | grep "MAE" | awk '{print $NF}')
        mad_array["$g,$i,$j"]="$mad_value" 
    done
done







# Calculate Errors

# Initialize wtmad arrays for each group and functional
declare -A wtmad1 wtmad2 wtmad3 wtmad15
for j in "${!args[@]}"; do
  for g in {0..6}; do
    wtmad1["$g,$j"]=0.0
    wtmad2["$g,$j"]=0.0
    wtmad3["$g,$j"]=0.0
    wtmad15["$g,$j"]=0.0
  done
done

# Calculate WTMAD-1
# \text{WTMAD-1} = \frac{1}{N_{\text{Bench}}} \sum_{i=1}^{N_{\text{Bench}}} w_{i} \cdot \text{MAD}_{i}
for j in "${!args[@]}" ; do
    for g_i in "${!subsets[@]}" ; do
        IFS=',' read -r g i <<< "$g_i"
        wtmad1_elem=$(echo "${weights["$g,$i"]} * ${mad_array["$g,$i,$j"]} / ${subsets_total[$g]}" | bc -l)
        wtmad1["$g,$j"]=$(echo "${wtmad1["$g,$j"]} + $wtmad1_elem" | bc -l)
    done
done

# Calculate WTMAD-2
#\text{WTMAD-2} = \sum_{i=1}^{N_{\text{Bench}}} \frac{N_{i}}{N_{\text{total}}} \cdot \frac{ {\overline{|\Delta E|}_{\text{total}}}  }{\overline{|\Delta E|}_{i}} \cdot \text{MAD}_{i}
for j in "${!args[@]}" ; do
    for g_i in "${!subsets[@]}" ; do
        IFS=',' read -r g i <<< "$g_i"
        wtmad2_elem=$(echo "${systems["$g,$i"]} * ${deltEBs_mean[$g]} * ${mad_array["$g,$i,$j"]} / (${deltEBs["$g,$i"]} * ${systems_total[$g]})" | bc -l)
        wtmad2["$g,$j"]=$(echo "${wtmad2["$g,$j"]} + $wtmad2_elem" | bc -l)
    done
done

# Calculate WTMAD-3
# \text{WTMAD-3} = \sum_{i=1}^{N_{\text{Bench}}} \frac{N_{i}^{\text{damp}}}{N_{\text{total}}} \cdot \frac{ {\overline{|\Delta E|}_{\text{total}}}  }{\overline{|\Delta E|}_{i}} \cdot \text{MAD}_{i}
# N_i^{\text{damp}} = \max(0.01 \, N_{\text{total}} \, , \, N_i)
ni_max=$(echo "0.01 * ${systems_total[$g]}" | bc -l)
for j in "${!args[@]}" ; do
    for g_i in "${!subsets[@]}"; do
        IFS=',' read -r g i <<< "$g_i"
        if (( $(echo "${systems["$g,$i"]} < $ni_max" | bc -l) )); then
            ni_damp=${systems["$g,$i"]}
        else
            ni_damp=$ni_max
        fi
        wtmad3_elem=$(echo "$ni_damp * ${deltEBs_mean[$g]} * ${mad_array["$g,$i,$j"]} / (${deltEBs["$g,$i"]} * ${systems_total[$g]})" | bc -l)
        wtmad3["$g,$j"]=$(echo "${wtmad3["$g,$j"]} + $wtmad3_elem" | bc -l)
    done
done

# Calculate WTMAD- 1.5
# Proposed by E R Johnson and K R Bryenton to remove the N_i term entirely so each benchmark is weighted the same.
#\text{WTMAD-1.5} =  \frac{1}{N_{\text{Bench}}} \sum_{i=1}^{N_{\text{Bench}}} \frac{ {\overline{|\Delta E|}_{\text{total}}}  }{\overline{|\Delta E|}_{i}} \cdot \text{MAD}_{i}
for j in "${!args[@]}" ; do
    for g_i in "${!subsets[@]}" ; do
        IFS=',' read -r g i <<< "$g_i"
        wtmad15_elem=$(echo "${deltEBs_mean[$g]} * ${mad_array["$g,$i,$j"]} / (${deltEBs["$g,$i"]} * ${subsets_total[$g]})" | bc -l)
        wtmad15["$g,$j"]=$(echo "${wtmad15["$g,$j"]} + $wtmad15_elem" | bc -l)
    done
done









# Print Output:

# Print Header
printf "%-${cw}s %-${cw}s %-${cw}s | " "Subset" "N.Systems" "DeltaEBar"
for inFile in "$@" ; do
    printf "%-${cw}s " "${inFile%.results}"
done
printf "\n"

# Print MAD rows for full GMTKN55
for (( i=0 ; i<subsets_total[6] ; i++ )) ; do
    printf "%-${cw}s %-${cw}s %-${cw}s | " "${subsets["6,$i"]}" "${systems["6,$i"]}" "${deltEBs["6,$i"]}"
    for j in "${!args[@]}" ; do
        printf "%-${cw}.2f " "${mad_array["6,$i,$j"]}"
    done
    printf "\n"
done

# Print WTMAD-1
printf "%-${cw}s %-${cw}s %-${cw}s | " "  WTMAD-1" "-" "-"
for j in "${!args[@]}" ; do
    printf "%-${cw}.2f " "${wtmad1["6,$j"]}"
done
printf "\n"

# Print WTMAD-2
printf "%-${cw}s %-${cw}s %-${cw}s | " "  WTMAD-2" "-" "-"
for j in "${!args[@]}" ; do
    printf "%-${cw}.2f " "${wtmad2["6,$j"]}"
done
printf "\n"

# Print WTMAD-3
printf "%-${cw}s %-${cw}s %-${cw}s | " "  WTMAD-3" "-" "-"
for j in "${!args[@]}" ; do
    printf "%-${cw}.2f " "${wtmad3["6,$j"]}"
done
printf "\n"

# Print WTMAD-1.5
printf "%-${cw}s %-${cw}s %-${cw}s | " "  WTMAD-1.5" "-" "-"
for j in "${!args[@]}" ; do
    printf "%-${cw}.2f " "${wtmad15["6,$j"]}"
done
printf "\n"

# Print Summary Table
printf "%s\n" "...Summary Table..."
printf "%-${cw}s " "WTMAD-2"
for g in {0..6} ; do
    printf "%-${cw}s " "${group_names[$g]}"
done
printf "\n"
for j in "${!args[@]}" ; do
    inFile="${args[$j]}"
    printf "%-${cw}s " "${inFile%.results}"
    for g in {0..6} ; do
        printf "%-${cw}.2f " "${wtmad2["$g,$j"]}"
    done
    printf "\n"
done
printf "\n"






# Partial Stats Full Report
if (( partialStatsReport == 0 )) ; then
    printf "\n"
    printf "%s\n" "-------------------"
    printf "%s\n" "   PARTIAL STATS   "
    printf "%s\n" "-------------------"
    if (( deltaEBarMean_Type == 0 )) ; then
        printf "%s\n" "Note: DeltaEBar_Mean fixed to use the 'full subset' value."
    elif (( deltaEBarMean_Type == 1 )) ; then
        printf "%s\n" "Note: DeltaEBar_Mean recalculated for each group."
    else
        echo "ERROR: DeltaEBar_Mean Type Not Supported. Exiting..." >&2
        exit 1
    fi
    printf "\n"
    
    # Print Full GMTKN55 Statistics
    for g in {0..6}; do
    
        # Group and Metrics
        printf "%s statistics:\n" "${group_names[$g]}"
        printf "  Number of Subsets:  %d\n" "${subsets_total[$g]}"
        printf "  Number of Systems:  %d\n" "${systems_total[$g]}"
        printf "  DeltaEBar_Total:    %.2f\n" "${deltEBs_total[$g]}"
        printf "  DeltaEBar_Mean:     %.2f\n" "${deltEBs_mean[$g]}"
    
        # Functional List
        printf "%-${cw}s %-${cw}s %-${cw}s | " "-" "-" "-"
        for inFile in "$@"; do
            printf "%-${cw}s " "${inFile%.results}"
        done
        printf "\n"
    
        # WTMAD-1
        printf "%-${cw}s %-${cw}s %-${cw}s | " "  WTMAD-1" "-" "-"
        for j in "${!args[@]}" ; do
            printf "%-${cw}.2f " "${wtmad1["$g,$j"]}"
        done
        printf "\n"
        
        # WTMAD-2
        printf "%-${cw}s %-${cw}s %-${cw}s | " "  WTMAD-2" "-" "-"
        for j in "${!args[@]}" ; do
            printf "%-${cw}.2f " "${wtmad2["$g,$j"]}"
        done
        printf "\n"
        
        # WTMAD-3
        printf "%-${cw}s %-${cw}s %-${cw}s | " "  WTMAD-3" "-" "-"
        for j in "${!args[@]}" ; do
            printf "%-${cw}.2f " "${wtmad3["$g,$j"]}"
        done
        printf "\n"
        
        # WTMAD-1.5
        printf "%-${cw}s %-${cw}s %-${cw}s | " "  WTMAD-1.5" "-" "-"
        for j in "${!args[@]}" ; do
            printf "%-${cw}.2f " "${wtmad15["$g,$j"]}"
        done
        printf "\n"
    
        printf "\n"
    done
fi
