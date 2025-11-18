#!/bin/bash

# ProcessGMTKN55.sh
# Kyle Bryenton - 2025-11-18
#    This script is run by supplying a list of paths to *.results files to process
#    The .results files are the output of eval_driver.m
#    Each .results file should contain the error metrics for each of the 55 subset for one basis/functional combination
#    The order you want the results in is located at the top of the file
#    Each .results file will print either the MAE or ME as a column in the output
#    The script formally works with any extension. Don't include non-extension periods in your filenames. 
#set -euxo pipefail

# Check for input files
if [ $# == 0 ]; then
    echo "ERROR: No *.results files detected. Exiting."                >&2
    echo "USAGE: $0 PBE.results B86bPBE.results BHLYP.results ...)"    >&2
    exit 1
fi
args=("$@")

### USER SETABLE AREA ###

## FLAG FOR IF YOU WANT PROGRESS REPORTS:
 # 0 = false
 # 1 = true
print_progress=1

## FLAG FOR IF YOU'RE SCRAPING OUTPUTS:
 # This script reads eval_driver.m outputs. It checks for areas in the output matching the subsets in GMTKN55_info() via: 
 #    mad_value=$(grep -A "$n_line" "^## data dir:.*${subset}[[:space:]]*$" "$inFile" | grep "MAE" | awk '{print $NF}')
 # If you're scraping outputs, create a fake eval_driver ouput in the following format:
 # ```
 # ## data dir: ALK2X6
 # MAD 1.2
 # ## data dir: ALK8
 # MAD 3.9
 # ... etc
 # ```
 # This script might be helpful:
 #      for res in *.results ; do sed -i '/^## data dir:/!{/MAE       /!d}' res ; done
 # 1 = Data input type is in eval_driver.m format, merged to contain all 55 benchmarks.
 # 2 = Data input type is scraped data, alternating rows between `## data dir: <subset>` and `MAD <value>`
dataInput_Type=2

## FLAGS for deltaEBarMean control. Suggested = 1
 # For Groups "basic+ssmall, iso.+large, etc..." select which DeltaEBar_Mean to use:
 # 1 = Use the same as the full GMTKN55 (how Grimme presented his stats in the original work)
 # 2 = Recalculate DeltaEBar_Mean for each subset
deltaEBarMean_Type=1

## FLAGS for deltaEBarMeanFixed control. Suggested = 1
 # 1 = Let it autocalculate based on the GMTKN55_info table
 # 2 = Override it to a specific value, given by deltEBs_fixed
deltaEBarMeanFixed_Type=2
deltEBs_fixed=56.84

## FLAGS TO CONTROL OUTPUT
 # Note the report prints wtmadN only if ((print_wtmadN == 1 || print_wtmadN_summary == 1))
 # 0 = false
 # 1 = true
print_mad=1
print_wtmad1=1
print_wtmad2=1
print_wtmad3=1
print_wtmad15=0
print_wtmad4=1
print_wtmad4p=0
print_wtmad1_summary=1
print_wtmad2_summary=1
print_wtmad3_summary=1
print_wtmad15_summary=0
print_wtmad4_summary=1
print_wtmad4p_summary=0
print_report=1

## REFERENCE DATA TABLE
 # Rearrange rows to change the subset ordering in the output.
 # Comment out a row to exclude that subset from the output.
 # All errors will adjust accordingly, automatically.
 #     Column 1: Subset Name
 #     Column 2: Number of systems in the subset
 #     Column 3: Average relative absolute energy \bar{|\Delta E|} in kcal/mol        [Used for WTMAD-2]
 #     Column 4: Weight (=10.0 if deltaE < 7.5, =0.1 if deltaE > 75, = 1.0 otherwise) [Used for WTMAD-1]
 #     Column 5: Indexing (0 = basicsmall, 1 = isolarge, 2 = barriers, 3 = intermolNCI, 4 = intramolNCI)
 #     Column 6: Weights such that each "typical" functional+DC gives equal weights for each benchmark. [Used for WTMAD-4]
 # To obtain ref energies from your .din, use the following one-liner:
 #     cat *.din | awk '/^0$/ { getline; print }' | awk '{sum+=sqrt($1*$1); n++} END {if(n>0) printf "%.2f\n", sum/n}'     
weight_Type=1 #1 = D3-10, 2 = ALL-115
if ((weight_Type == 1)) ; then
    ### WTMAD-4 Weights determined using D3-10 Dataset
    GMTKN55_info=(
      "AL2X6        6     35.88     1.0    0    3.27 "
      "ALK8         8     62.60     1.0    0    1.30 "
      "ALKBDE10    10    100.69     0.1    0    1.06 "
      "BH76RC      30     21.39     1.0    0    2.55 "
      "DC13        13     54.98     1.0    0    0.78 "
      "DIPCS10     10    654.26     0.1    0    1.65 "
      "FH51        51     31.01     1.0    0    2.39 "
      "G21EA       25     33.62     1.0    0    2.15 "
      "G21IP       36    257.61     0.1    0    1.63 "
      "G2RC        25     51.26     1.0    0    1.12 "
      "HEAVYSB11   11     58.02     1.0    0    2.73 "
      "NBPRC       12     27.71     1.0    0    2.32 "
      "PA26        26    189.05     0.1    0    1.98 "
      "RC21        21     35.70     1.0    0    1.45 "
      "SIE4x4      16     33.72     1.0    0    0.469"
      "TAUT15      15      3.05    10.0    0    5.80 "
      "W4-11      140    306.91     0.1    0    1.07 "
      "YBDE18      18     49.28     1.0    0    2.55 "
      "BSR36       36     16.20     1.0    1    2.03 "
      "C60ISO       9     98.25     0.1    1    1.19 "
      "CDIE20      20      4.06    10.0    1    5.75 "
      "DARC        14     32.47     1.0    1    1.44 "
      "ISO34       34     14.57     1.0    1    4.49 "
      "ISOL24      24     21.92     1.0    1    1.99 "
      "MB16-43     43    468.39     0.1    1    0.329"
      "PArel       20      4.63    10.0    1    5.51 "
      "RSE43       43      7.60     1.0    1    5.27 "
      "BH76        76     18.61     1.0    2    1.53 "
      "BHDIV10     10     45.33     1.0    2    1.66 "
      "BHPERI      26     20.87     1.0    2    2.29 "
      "BHROT27     27      6.27    10.0    2   11.0  "
      "INV24       24     31.85     1.0    2    4.41 "
      "PX13        13     33.36     1.0    2    1.18 "
      "WCPT18      18     34.99     1.0    2    1.77 "
      "ADIM6        6      3.36    10.0    3   36.8  "
      "AHB21       21     22.49     1.0    3    6.24 "
      "CARBHB12    12      6.04    10.0    3    5.50 "
      "CHB6         6     26.79     1.0    3    4.14 "
      "HAL59       59      4.59    10.0    3    9.63 "
      "HEAVY28     28      1.24    10.0    3   14.0  "
      "IL16        16    109.04     0.1    3   11.5  "
      "PNICO23     23      4.27    10.0    3    7.86 "
      "RG18        18      0.58    10.0    3   29.9  "
      "S22         22      7.30    10.0    3   13.5  "
      "S66         66      5.47    10.0    3   18.4  "
      "WATER27     27     81.14     0.1    3    1.43 "
      "ACONF       15      1.83    10.0    4   61.2  "
      "Amino20x4   80      2.44    10.0    4   22.6  "
      "BUT14DIOL   64      2.80    10.0    4   30.0  "
      "ICONF       17      3.27    10.0    4   20.0  "
      "IDISP        6     14.22     1.0    4    2.50 "
      "MCONF       51      4.97    10.0    4   21.2  "
      "PCONF21     18      1.62    10.0    4    8.66 "
      "SCONF       17      4.60    10.0    4   19.1  "
      "UPU23       23      5.72    10.0    4   10.1  "
    )
elif ((weight_Type == 2)) ; then
    ### WTMAD-4 Weights determined using ALL-115 Dataset
    GMTKN55_info=(
      "AL2X6        6     35.88     1.0    0    2.67 "
      "ALK8         8     62.60     1.0    0    1.30 "
      "ALKBDE10    10    100.69     0.1    0    1.25 "
      "BH76RC      30     21.39     1.0    0    2.85 "
      "DC13        13     54.98     1.0    0    0.881"
      "DIPCS10     10    654.26     0.1    0    1.37 "
      "FH51        51     31.01     1.0    0    2.82 "
      "G21EA       25     33.62     1.0    0    2.37 "
      "G21IP       36    257.61     0.1    0    1.93 "
      "G2RC        25     51.26     1.0    0    1.42 "
      "HEAVYSB11   11     58.02     1.0    0    1.97 "
      "NBPRC       12     27.71     1.0    0    3.09 "
      "PA26        26    189.05     0.1    0    2.32 "
      "RC21        21     35.70     1.0    0    1.82 "
      "SIE4x4      16     33.72     1.0    0    0.486"
      "TAUT15      15      3.05    10.0    0    6.01 "
      "W4-11      140    306.91     0.1    0    1.12 "
      "YBDE18      18     49.28     1.0    0    2.26 "
      "BSR36       36     16.20     1.0    1    2.87 "
      "C60ISO       9     98.25     0.1    1    1.08 "
      "CDIE20      20      4.06    10.0    1    6.60 "
      "DARC        14     32.47     1.0    1    1.77 "
      "ISO34       34     14.57     1.0    1    5.04 "
      "ISOL24      24     21.92     1.0    1    2.02 "
      "MB16-43     43    468.39     0.1    1    0.299"
      "PArel       20      4.63    10.0    1    5.90 "
      "RSE43       43      7.60     1.0    1    4.45 "
      "BH76        76     18.61     1.0    2    1.56 "
      "BHDIV10     10     45.33     1.0    2    1.80 "
      "BHPERI      26     20.87     1.0    2    2.35 "
      "BHROT27     27      6.27    10.0    2   14.3  "
      "INV24       24     31.85     1.0    2    4.47 "
      "PX13        13     33.36     1.0    2    1.38 "
      "WCPT18      18     34.99     1.0    2    1.93 "
      "ADIM6        6      3.36    10.0    3   17.4  "
      "AHB21       21     22.49     1.0    3    8.15 "
      "CARBHB12    12      6.04    10.0    3    7.28 "
      "CHB6         6     26.79     1.0    3    4.18 "
      "HAL59       59      4.59    10.0    3    9.09 "
      "HEAVY28     28      1.24    10.0    3   14.6  "
      "IL16        16    109.04     0.1    3    9.95 "
      "PNICO23     23      4.27    10.0    3    9.22 "
      "RG18        18      0.58    10.0    3   26.0  "
      "S22         22      7.30    10.0    3   16.4  "
      "S66         66      5.47    10.0    3   19.8  "
      "WATER27     27     81.14     0.1    3    1.68 "
      "ACONF       15      1.83    10.0    4   44.0  "
      "Amino20x4   80      2.44    10.0    4   23.2  "
      "BUT14DIOL   64      2.80    10.0    4   25.8  "
      "ICONF       17      3.27    10.0    4   22.2  "
      "IDISP        6     14.22     1.0    4    2.55 "
      "MCONF       51      4.97    10.0    4   15.8  "
      "PCONF21     18      1.62    10.0    4    8.98 "
      "SCONF       17      4.60    10.0    4   15.8  "
      "UPU23       23      5.72    10.0    4   11.6  "
    )
else
    echo "ERROR: weight_Type Not Supported. Exiting..." >&2
    exit 1
fi

# Group names to display in partial benchmark statistics for the groups in col5 above
# The last one should be the full GMTKN55 set with all inputs.
group_names=( "basicsmall" "isolarge" "barriers" "intermolNCI" "intramolNCI" "allNCI" "GMTKN55" )

### END USER SETTABLE AREA ###



# Import Data

# Get index of full GMTKN55 group, used for ni_max and DeltaEBar_Mean definitions, and some print statements
index_GMTKN55=$(( ${#group_names[@]} - 1 ))

# Declare associative arrays
declare -A subsets
declare -A systems
declare -A deltEBs
declare -A weights
declare -A weights2

# Declare arrays for holding totals
declare -a subsets_total
declare -a systems_total
declare -a deltEBs_total
declare -a weights_total
declare -a weights2_total
declare -a deltEBs_mean

# Initialize arrays
declare -a index
for (( g=0 ; g<=index_GMTKN55 ; g++ )) ; do
    index[$g]=0
    subsets_total[$g]=0
    systems_total[$g]=0
    deltEBs_total[$g]=0.0
    weights_total[$g]=0.0
    weights2_total[$g]=0.0
    deltEBs_mean[$g]=0.0
done

# Loop through the top-level info array
for info in "${GMTKN55_info[@]}"; do
  # Read input line
  read subset system deltEB weight subcat weight2 <<< "$info"
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
    weights2["$g,${index[$g]}"]=$weight2
    # Update totals
    (( subsets_total[$g]++ ))
    (( systems_total[$g]+=system ))
    # Use bc for floating point sums
    deltEBs_total[$g]=$(echo "${deltEBs_total[$g]} + $deltEB" | bc -l)
    weights_total[$g]=$(echo "${weights_total[$g]} + $weight" | bc -l)
    weights2_total[$g]=$(echo "${weights2_total[$g]} + $weight2" | bc -l)
    # Increment the index for this group
    ((index[$g]++))
  done
done

# Calculate deltaEBar_mean for each group
for (( g=0 ; g<=index_GMTKN55 ; g++ )) ; do
    if ((deltaEBarMean_Type == 1)) ; then
        deltEBs_mean[$g]=$(echo "${deltEBs_total[$index_GMTKN55]} / ${subsets_total[$index_GMTKN55]}" | bc -l)
    elif ((deltaEBarMean_Type == 2)) ; then
        deltEBs_mean[$g]=$(echo "${deltEBs_total[$g]} / ${subsets_total[$g]}" | bc -l)
    else
        echo "ERROR: deltaEBarMean_Type Not Supported. Exiting..." >&2
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
printf "Directory: %s\n" "$(pwd)"
printf "Date:      %s\n" "$(date)"
printf "\n"
printf "%s statistics:\n" "${group_names[$index_GMTKN55]}"
printf "  Number of Subsets:  %d\n" "${subsets_total[$index_GMTKN55]}"
printf "  Number of Systems:  %d\n" "${systems_total[$index_GMTKN55]}"
printf "  DeltaEBar_Total:    %.2f\n" "${deltEBs_total[$index_GMTKN55]}"
printf "  DeltaEBar_Mean:     %.2f\n" "${deltEBs_mean[$index_GMTKN55]}" 

# If DeltaEBar_Mean is being overridden, recalculate it and print it to the user
if ((deltaEBarMeanFixed_Type == 1)) ; then
printf "  DeltaEBar_Mean is NOT OVERRIDDEN. Using the calculated value: %.2f\n" "${deltEBs_mean[$index_GMTKN55]}"
elif ((deltaEBarMeanFixed_Type == 2)) ; then
    # Recalculate deltaEBar_mean for each group
    for (( g=0 ; g<=index_GMTKN55 ; g++ )) ; do
        if ((deltaEBarMean_Type == 1)) ; then
            deltEBs_mean[$g]=$deltEBs_fixed
        elif ((deltaEBarMean_Type == 2)) ; then
            echo "ERROR: deltaEBarMean_Type==2 not supported with deltaEBarMeanFixed_Type==2. Exiting..." >&2
            exit 1
        else
            echo "ERROR: deltaEBarMean_Type Not Supported. Exiting..." >&2
            exit 1
        fi
    done
    printf "  DeltaEBar_Mean is OVERRIDDEN. Using the fixed value: %.2f\n" "${deltEBs_mean[$index_GMTKN55]}"
else
    echo "ERROR: deltaEBarMeanFixed_Type Not Supported. Exiting..." >&2
    exit 1
fi
printf "\n"

# Set the column width to max(12, longest input file name)
cw=12
for inFile in "$@" ; do
    lenFilename=$(expr length "${inFile%.*}")
    if [ $((lenFilename + 1)) -gt $cw ] ; then
        cw=$((lenFilename + 1))
    fi
done

# Fetch the Mean Absolute Errors (MAE or MAD) for each input
if ((print_progress == 1)) ; then echo "Calculating:"  ; fi
if ((print_progress == 1)) ; then echo "... MAD Array" ; fi
declare -A mad_array
for g_i in "${!subsets[@]}"; do  # key is "g_i"
    IFS=',' read -r g i <<< "$g_i"
    subset="${subsets["$g,$i"]}"
    n_syst="${systems["$g,$i"]}"
    if ((dataInput_Type == 1)) ; then   # eval_driver.m prints 9 extra rows / subset; - 1 for din. Thus = n_syst + 8
        n_line=$(( n_syst + 8 ))
    elif ((dataInput_Type == 2)) ; then # Used for scraped data, only need 1 row after subset detection.
        n_line=1
    else
        echo "ERROR: dataInput_Type Type Not Supported. Exiting..." >&2
        exit 1
    fi
    for j in "${!args[@]}"; do
        inFile="${args[$j]}"
        mad_value=$(grep -i -A "$n_line" "^## data dir:.*${subset}[[:space:]]*$" "$inFile" | tail -n +2 | grep "MAE\|MAD" | awk '{print $NF}')
        if [[ $(wc -l <<< "$mad_value") -ne 1 ]] ; then
            echo "ERROR: Expected exactly 1 MAD value, got $(wc -l <<< "$mad_value")" >&2
            echo "   File: $inFile | Subset: $subset"                                 >&2
            echo "   Ensure your input data is free of errors."                       >&2
            echo "   Check your 'dataInput_Type' settable variable."                  >&2
            echo "Raw values found:"                                                  >&2
            echo "$mad_value"                                                         >&2
            exit 1
        fi
        if ! [[ "$mad_value" =~ ^-?([0-9]+(\.[0-9]*)?|\.[0-9]+)$ ]] ; then
            echo "ERROR: MAD value is non-numerical"                                  >&2
            echo "   File: $inFile | Subset: $subset"                                 >&2
            echo "   Ensure your input data is free of errors."                       >&2
            echo "   Check your 'dataInput_Type' settable variable."                  >&2
            echo "Raw values found:"                                                  >&2
            echo "$mad_value"                                                         >&2
            exit 1
        fi
        if awk '{exit ($1 <= 0 ? 0 : 1)}' <<< "$mad_value" ; then
            echo "ERROR: MAD value is equal to or less than zero"                     >&2
            echo "   File: $inFile | Subset: $subset"                                 >&2
            echo "   Ensure your input data is free of errors."                       >&2
            echo "   Check your 'dataInput_Type' settable variable."                  >&2
            echo "Raw values found:"                                                  >&2
            echo "$mad_value"                                                         >&2
            exit 1
        fi
        mad_array["$g,$i,$j"]="$mad_value"
    done
done



## USEFUL FOR DEBUGGING
#echo
#printf "%-${cw}s %-${cw}s %-${cw}s | " "Subset" "N.Systems" "DeltaEBar"
#for inFile in "$@" ; do
#    printf "%-${cw}s " "${inFile%.*}"
#done
#printf "\n"
#if ((print_mad == 1)) ; then
#    for (( i=0 ; i<subsets_total[$index_GMTKN55] ; i++ )) ; do
#        printf "%-${cw}s %-${cw}s %-${cw}s | " "${subsets["$index_GMTKN55,$i"]}" "${systems["$index_GMTKN55,$i"]}" "${deltEBs["$index_GMTKN55,$i"]}"
#        for j in "${!args[@]}" ; do
#            printf "%-${cw}.2f " "${mad_array["$index_GMTKN55,$i,$j"]}"
#        done
#        printf "\n"
#    done
#fi
#exit 1

# Calculate Errors

# Initialize wtmad arrays for each group and functional
declare -A wtmad1 wtmad2 wtmad3 wtmad15 wtmad4 wtmad4p
for j in "${!args[@]}"; do
    for (( g=0 ; g<=index_GMTKN55 ; g++ )) ; do
        wtmad1["$g,$j"]=0.0
        wtmad2["$g,$j"]=0.0
        wtmad3["$g,$j"]=0.0
        wtmad15["$g,$j"]=0.0
        wtmad4["$g,$j"]=0.0
        wtmad4p["$g,$j"]=0.0
    done
done

# Calculate WTMAD-1
# \text{WTMAD-1} = \frac{1}{N_{\text{Bench}}} \sum_{i=1}^{N_{\text{Bench}}} w_{i} \cdot \text{MAD}_{i}
if ((print_wtmad1 == 1 || print_wtmad1_summary == 1)) ; then
    if ((print_progress == 1)) ; then echo "... WTMAD-1" ; fi
    for j in "${!args[@]}" ; do
        for g_i in "${!subsets[@]}" ; do
            IFS=',' read -r g i <<< "$g_i"
            wtmad1_elem=$(echo "${weights["$g,$i"]} * ${mad_array["$g,$i,$j"]} / ${subsets_total[$g]}" | bc -l)
            wtmad1["$g,$j"]=$(echo "${wtmad1["$g,$j"]} + $wtmad1_elem" | bc -l)
        done
    done
fi

# Calculate WTMAD-2
#\text{WTMAD-2} = \sum_{i=1}^{N_{\text{Bench}}} \frac{N_{i}}{N_{\text{total}}} \cdot \frac{ {\overline{|\Delta E|}_{\text{total}}}  }{\overline{|\Delta E|}_{i}} \cdot \text{MAD}_{i}
if ((print_wtmad2 == 1 || print_wtmad2_summary == 1)) ; then
    if ((print_progress == 1)) ; then echo "... WTMAD-2" ; fi
    for j in "${!args[@]}" ; do
        for g_i in "${!subsets[@]}" ; do
            IFS=',' read -r g i <<< "$g_i"
            wtmad2_elem=$(echo "${systems["$g,$i"]} * ${deltEBs_mean[$g]} * ${mad_array["$g,$i,$j"]} / (${deltEBs["$g,$i"]} * ${systems_total[$g]})" | bc -l)
            wtmad2["$g,$j"]=$(echo "${wtmad2["$g,$j"]} + $wtmad2_elem" | bc -l)
        done
    done
fi

# Calculate WTMAD-3
# \text{WTMAD-3} = \sum_{i=1}^{N_{\text{Bench}}} \frac{N_{i}^{\text{damp}}}{N_{\text{total}}} \cdot \frac{ {\overline{|\Delta E|}_{\text{total}}}  }{\overline{|\Delta E|}_{i}} \cdot \text{MAD}_{i}
# N_i^{\text{damp}} = \min(0.01 \, N_{\text{total}} \, , \, N_i)
if ((print_wtmad3 == 1 || print_wtmad3_summary == 1)) ; then
    if ((print_progress == 1)) ; then echo "... WTMAD-3" ; fi
    ni_max=$(echo "0.01 * ${systems_total[$index_GMTKN55]}" | bc -l)
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
fi

# Calculate WTMAD-1.5
# Proposed by K R Bryenton and E R Johnson to remove the N_i term entirely so each benchmark is weighted the same.
#\text{WTMAD-1.5} =  \frac{1}{N_{\text{Bench}}} \sum_{i=1}^{N_{\text{Bench}}} \frac{ {\overline{|\Delta E|}_{\text{total}}}  }{\overline{|\Delta E|}_{i}} \cdot \text{MAD}_{i}
if ((print_wtmad15 == 1 || print_wtmad15_summary == 1)) ; then
    if ((print_progress == 1)) ; then echo "... WTMAD-1.5" ; fi
    for j in "${!args[@]}" ; do
        for g_i in "${!subsets[@]}" ; do
            IFS=',' read -r g i <<< "$g_i"
            wtmad15_elem=$(echo "${deltEBs_mean[$g]} * ${mad_array["$g,$i,$j"]} / (${deltEBs["$g,$i"]} * ${subsets_total[$g]})" | bc -l)
            wtmad15["$g,$j"]=$(echo "${wtmad15["$g,$j"]} + $wtmad15_elem" | bc -l)
        done
    done
fi

# Calculate WTMAD-4
# Proposed by K R Bryenton and E R Johnson to weigh each benchmark equivalently while taking into account their typical MAD values per benchmark on well-behaved functionals.
# \text{WTMAD-4} = \frac{1}{N_{\text{Bench}}} \sum_{i=1}^{N_{\text{Bench}}} w_{i} \cdot \text{MAD}_{i}
if ((print_wtmad4 == 1 || print_wtmad4_summary == 1)) ; then
    if ((print_progress == 1)) ; then echo "... WTMAD-4" ; fi
    for j in "${!args[@]}" ; do
        for g_i in "${!subsets[@]}" ; do
            IFS=',' read -r g i <<< "$g_i"
            wtmad4_elem=$(echo "${weights2["$g,$i"]} * ${mad_array["$g,$i,$j"]} / ${subsets_total[$g]}" | bc -l)
            wtmad4["$g,$j"]=$(echo "${wtmad4["$g,$j"]} + $wtmad4_elem" | bc -l)
        done
    done
fi

# Calculate WTMAD-4'
# Proposed by K R Bryenton and E R Johnson to rescale WTMAD-4 so each of the five main categories has equal weight
# \text{WTMAD-4g} =  \frac{1}{N_{\text{Cat.}}} \sum_{i=1}^{N_{\text{Cat.}}} \frac{1}{N_{\text{Bench,Cat.}}} \sum_{i=1}^{N_{\text{Bench,Cat.}}} w_{i,\text{Cat.}} \cdot \text{MAD}_{i,\text{Cat.}}
# Alternatively, you calculate the WTMAD-4 for each each category (basic+small, iso+large, barriers, intermolNCI, intramolNCI) then take their mean.
if ((print_wtmad4p == 1 || print_wtmad4p_summary == 1)) ; then
    if ((print_progress == 1)) ; then echo "... WTMAD-4'" ; fi
    for j in "${!args[@]}" ; do
        for g_i in "${!subsets[@]}" ; do
            IFS=',' read -r g i <<< "$g_i"
            wtmad4p_elem=$(echo "${weights2["$g,$i"]} * ${mad_array["$g,$i,$j"]} / ${subsets_total[$g]}" | bc -l)
            wtmad4p["$g,$j"]=$(echo "${wtmad4p["$g,$j"]} + $wtmad4p_elem" | bc -l)
        done
        wtmad4p["$index_GMTKN55,$j"]=$(echo "0.2*(${wtmad4p["1,$j"]} + ${wtmad4p["2,$j"]} + ${wtmad4p["3,$j"]} + ${wtmad4p["4,$j"]} + ${wtmad4p["5,$j"]})" | bc -l)
    done
fi







# Print Output:

# Print Header
echo
printf "%-${cw}s %-${cw}s %-${cw}s | " "Subset" "N.Systems" "DeltaEBar"
for inFile in "$@" ; do
    printf "%-${cw}s " "${inFile%.*}"
done
printf "\n"

# Print MAD rows for full GMTKN55
if ((print_mad == 1)) ; then
    for (( i=0 ; i<subsets_total[$index_GMTKN55] ; i++ )) ; do
        printf "%-${cw}s %-${cw}s %-${cw}s | " "${subsets["$index_GMTKN55,$i"]}" "${systems["$index_GMTKN55,$i"]}" "${deltEBs["$index_GMTKN55,$i"]}"
        for j in "${!args[@]}" ; do
            printf "%-${cw}.2f " "${mad_array["$index_GMTKN55,$i,$j"]}"
        done
        printf "\n"
    done
fi

# Print WTMAD-1
if ((print_wtmad1 == 1)) ; then
    printf "%-${cw}s %-${cw}s %-${cw}s | " "  WTMAD-1" "-" "-"
    for j in "${!args[@]}" ; do
        printf "%-${cw}.2f " "${wtmad1["$index_GMTKN55,$j"]}"
    done
    printf "\n"
fi

# Print WTMAD-2
if ((print_wtmad2 == 1)) ; then
    printf "%-${cw}s %-${cw}s %-${cw}s | " "  WTMAD-2" "-" "-"
    for j in "${!args[@]}" ; do
        printf "%-${cw}.2f " "${wtmad2["$index_GMTKN55,$j"]}"
    done
    printf "\n"
fi

# Print WTMAD-3
if ((print_wtmad3 == 1)) ; then
    printf "%-${cw}s %-${cw}s %-${cw}s | " "  WTMAD-3" "-" "-"
    for j in "${!args[@]}" ; do
        printf "%-${cw}.2f " "${wtmad3["$index_GMTKN55,$j"]}"
    done
    printf "\n"
fi

# Print WTMAD-1.5
if ((print_wtmad15 == 1)) ; then
    printf "%-${cw}s %-${cw}s %-${cw}s | " "  WTMAD-1.5" "-" "-"
    for j in "${!args[@]}" ; do
        printf "%-${cw}.2f " "${wtmad15["$index_GMTKN55,$j"]}"
    done
    printf "\n"
fi

#Print WTMAD-4
if ((print_wtmad4 == 1)) ; then
    printf "%-${cw}s %-${cw}s %-${cw}s | " "  WTMAD-4" "-" "-"
    for j in "${!args[@]}" ; do
        printf "%-${cw}.2f " "${wtmad4["$index_GMTKN55,$j"]}"
    done
    printf "\n"
fi

# Print WTMAD-4p
if ((print_wtmad4p == 1)) ; then
    printf "%-${cw}s %-${cw}s %-${cw}s | " "  WTMAD-4'" "-" "-"
    for j in "${!args[@]}" ; do
        printf "%-${cw}.2f " "${wtmad4p["$index_GMTKN55,$j"]}"
    done
    printf "\n"
fi








# Print Summary Tables
printf "\n"
printf "%s\n" "--------------------"
printf "%s\n" "   SUMMARY TABLES   "
printf "%s\n" "--------------------"


if ((print_wtmad1_summary == 1)) ; then
    printf "%-${cw}s " "WTMAD-1"
    for (( g=0 ; g<=index_GMTKN55 ; g++ )) ; do
        printf "%-${cw}s " "${group_names[$g]}"
    done
    printf "\n"
    for j in "${!args[@]}" ; do
        inFile="${args[$j]}"
        printf "%-${cw}s " "${inFile%.*}"
        for (( g=0 ; g<=index_GMTKN55 ; g++ )) ; do
            printf "%-${cw}.2f " "${wtmad1["$g,$j"]}"
        done
        printf "\n"
    done
    printf "\n"
fi

if ((print_wtmad2_summary == 1)) ; then
    printf "%-${cw}s " "WTMAD-2"
    for (( g=0 ; g<=index_GMTKN55 ; g++ )) ; do
        printf "%-${cw}s " "${group_names[$g]}"
    done
    printf "\n"
    for j in "${!args[@]}" ; do
        inFile="${args[$j]}"
        printf "%-${cw}s " "${inFile%.*}"
        for (( g=0 ; g<=index_GMTKN55 ; g++ )) ; do
            printf "%-${cw}.2f " "${wtmad2["$g,$j"]}"
        done
        printf "\n"
    done
    printf "\n"
fi

if ((print_wtmad3_summary == 1)) ; then
    printf "%-${cw}s " "WTMAD-3"
    for (( g=0 ; g<=index_GMTKN55 ; g++ )) ; do
        printf "%-${cw}s " "${group_names[$g]}"
    done
    printf "\n"
    for j in "${!args[@]}" ; do
        inFile="${args[$j]}"
        printf "%-${cw}s " "${inFile%.*}"
        for (( g=0 ; g<=index_GMTKN55 ; g++ )) ; do
            printf "%-${cw}.2f " "${wtmad3["$g,$j"]}"
        done
        printf "\n"
    done
    printf "\n"
fi

if ((print_wtmad15_summary == 1)) ; then
    printf "%-${cw}s " "WTMAD-1.5"
    for (( g=0 ; g<=index_GMTKN55 ; g++ )) ; do
        printf "%-${cw}s " "${group_names[$g]}"
    done
    printf "\n"
    for j in "${!args[@]}" ; do
        inFile="${args[$j]}"
        printf "%-${cw}s " "${inFile%.*}"
        for (( g=0 ; g<=index_GMTKN55 ; g++ )) ; do
            printf "%-${cw}.2f " "${wtmad15["$g,$j"]}"
        done
        printf "\n"
    done
    printf "\n"
fi

if ((print_wtmad4_summary == 1)) ; then
    printf "%-${cw}s " "WTMAD-4"
    for (( g=0 ; g<=index_GMTKN55 ; g++ )) ; do
        printf "%-${cw}s " "${group_names[$g]}"
    done
    printf "\n"
    for j in "${!args[@]}" ; do
        inFile="${args[$j]}"
        printf "%-${cw}s " "${inFile%.*}"
        for (( g=0 ; g<=index_GMTKN55 ; g++ )) ; do
            printf "%-${cw}.2f " "${wtmad4["$g,$j"]}"
        done
        printf "\n"
    done
    printf "\n"
fi

if ((print_wtmad4p_summary == 1)) ; then
    printf "%-${cw}s " "WTMAD-4'"
    for (( g=0 ; g<=index_GMTKN55 ; g++ )) ; do
        printf "%-${cw}s " "${group_names[$g]}"
    done
    printf "\n"
    for j in "${!args[@]}" ; do
        inFile="${args[$j]}"
        printf "%-${cw}s " "${inFile%.*}"
        for (( g=0 ; g<=index_GMTKN55 ; g++ )) ; do
            printf "%-${cw}.2f " "${wtmad4p["$g,$j"]}"
        done
        printf "\n"
    done
    printf "\n"
fi








# Print the Partial Stats Full Report
if (( print_report == 1 )) ; then
    printf "\n"
    printf "%s\n" "-------------------"
    printf "%s\n" "   PARTIAL STATS   "
    printf "%s\n" "-------------------"
    if (( deltaEBarMean_Type == 1 )) ; then
        printf "%s\n" "Note: DeltaEBar_Mean fixed to use the 'full subset' value."
    elif (( deltaEBarMean_Type == 2 )) ; then
        printf "%s\n" "Note: DeltaEBar_Mean recalculated for each group."
    else
        echo "ERROR: DeltaEBar_Mean Type Not Supported. Exiting..." >&2
        exit 1
    fi
    printf "\n"
    
    # Print Full GMTKN55 Statistics
    for (( g=0 ; g<=index_GMTKN55 ; g++ )) ; do
        # Group and Metrics
        printf "%s statistics:\n" "${group_names[$g]}"
        printf "  Number of Subsets:  %d\n" "${subsets_total[$g]}"
        printf "  Number of Systems:  %d\n" "${systems_total[$g]}"
        printf "  DeltaEBar_Total:    %.2f\n" "${deltEBs_total[$g]}"
        printf "  DeltaEBar_Mean:     %.2f\n" "${deltEBs_mean[$g]}"
    
        # Functional List
        printf "%-${cw}s %-${cw}s %-${cw}s | " "-" "-" "-"
        for inFile in "$@"; do
            printf "%-${cw}s " "${inFile%.*}"
        done
        printf "\n"
    
        # WTMAD-1
        if ((print_wtmad1 == 1 || print_wtmad1_summary == 1)) ; then
            printf "%-${cw}s %-${cw}s %-${cw}s | " "  WTMAD-1" "-" "-"
            for j in "${!args[@]}" ; do
                printf "%-${cw}.2f " "${wtmad1["$g,$j"]}"
            done
            printf "\n"
        fi
            
        # WTMAD-2
        if ((print_wtmad2 == 1 || print_wtmad2_summary == 1)) ; then
            printf "%-${cw}s %-${cw}s %-${cw}s | " "  WTMAD-2" "-" "-"
            for j in "${!args[@]}" ; do
                printf "%-${cw}.2f " "${wtmad2["$g,$j"]}"
            done
            printf "\n"
        fi
            
        # WTMAD-3
        if ((print_wtmad3 == 1 || print_wtmad3_summary == 1)) ; then
            printf "%-${cw}s %-${cw}s %-${cw}s | " "  WTMAD-3" "-" "-"
            for j in "${!args[@]}" ; do
                printf "%-${cw}.2f " "${wtmad3["$g,$j"]}"
            done
            printf "\n"
        fi
            
        # WTMAD-1.5
        if ((print_wtmad15 == 1 || print_wtmad15_summary == 1)) ; then
            printf "%-${cw}s %-${cw}s %-${cw}s | " "  WTMAD-1.5" "-" "-"
            for j in "${!args[@]}" ; do
                printf "%-${cw}.2f " "${wtmad15["$g,$j"]}"
            done
            printf "\n"
        fi
        
        # WTMAD-4
        if ((print_wtmad4 == 1 || print_wtmad4_summary == 1)) ; then
            printf "%-${cw}s %-${cw}s %-${cw}s | " "  WTMAD-4" "-" "-"
            for j in "${!args[@]}" ; do
                printf "%-${cw}.2f " "${wtmad4["$g,$j"]}"
            done
            printf "\n"
        fi
        
        # WTMAD-4'
        if ((print_wtmad4p == 1 || print_wtmad4p_summary == 1)) ; then
            printf "%-${cw}s %-${cw}s %-${cw}s | " "  WTMAD-4'" "-" "-"
            for j in "${!args[@]}" ; do
                printf "%-${cw}.2f " "${wtmad4p["$g,$j"]}"
            done
            printf "\n"
        fi

    
        printf "\n"
    done
fi
