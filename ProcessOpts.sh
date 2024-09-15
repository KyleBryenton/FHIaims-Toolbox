#!/bin/bash

# ProcessOpts.sh
# Kyle Bryenton - 2024-09-15
#
#    This script is run by supplying a list of paths to *.out files to process
#    Each one processed will be one row in a table of data
#    The table includes the following:
#        System Functional Basis l_hart 50div SCF_1 Opt_1 Opt_2 N_SCF N_Opt Time\/CPU NiceDay?
#    - SCF_1, Opt_1, Opt_2, Time/CPU are all in units of sections per cpu core
#    - N_SCF and N_Opt are the number of scf steps and opt steps respectively
#     



# Set these flags as desired.
save_raw_data=false
save_pruned_data=false
filename="ProcessOpts"

if [ $# == 0 ]; then
    echo "ERROR: No *.out files detected. Exiting."                    >&2
    echo "USAGE: $0 \$(find . -name "*.out" | sort --version-sort)"    >&2
    echo "    This appends results to the same file as a single line." >&2
    echo "    You may also list paths manually to *.out files."        >&2
    exit 1
fi

# Collect raw data from *.out files. In order specified in the header.
if [[ $save_raw_data == true ]] ; then
    rm "$filename.raw" 2> /dev/null
    for inFile in "$@" ; do
        echo "!! $inFile"
        grep "^  xc  " "$inFile" ;
        grep "#  Suggested \"" "$inFile" | head -1 ; 
        grep "l_hartree" "$inFile" | head -1 ;
        grep "division" "$inFile" | head -1 ;
        grep -1 "SCF    2 :" "$inFile" | head -1 ;
        grep "| Time for this force" "$inFile" | head -2  ;
        grep "Number of self-" "$inFile" ;
        grep "Number of relaxation" "$inFile" ;
        grep " | Total time  " "$inFile" ;
        grep "nice day" "$inFile" ;
    done >> "$filename.raw"
fi

# Partially processes/prunes raw data, again in same order you see in the header.
rm "$filename.po_temp" 2> /dev/null
for inFile in "$@" ; do 
    echo "!! $(echo ${inFile%.out} | awk -F "/" '{print $NF}')"
    grep "^  xc  " "$inFile" | awk '{print $2}' ; 
    grep "#  Suggested \"" "$inFile" | head -1 | awk -F "\"" '{print $2}' ;
    grep "l_hartree" "$inFile" | head -1 | awk '{print $2}' ; 
    if [[ "$(grep "division" "$inFile" | head -1 | sed 's/^[[:space:]]*//')" =~ ^#.*50$ ]] ; then echo "Y" ; else echo "N" ; fi ; 
    grep -1 "SCF    2 :" "$inFile" | head -1 | awk '{print $(NF-4)}' ; 
    grep "| Time for this force" "$inFile" | head -2 | awk '{print $(NF-3)}' ; 
    grep "Number of self-" "$inFile" | awk '{print $NF}' ; 
    grep "Number of relaxation" "$inFile" | awk '{print $NF}' ; 
    grep " | Total time  " "$inFile" | awk '{print $(NF-3)}' ; 
    if [[ ! -z $(grep "nice day" "$inFile") ]] ; then echo "Y" ; else echo "N" ; fi  ;
done >> "$filename.po_temp"
if [[ $save_raw_data == true ]] ; then cp "$filename.po_temp" "$filename.pruned" ; fi

# Collapeses each system into a single row of the table, and adds a header
cat "$filename.po_temp" \
    | tr "\n" " " \
    | sed "s/!! /\n/g" \
    | sed '1s/.*/\System Functional Basis l_hart 50div SCF_1 Opt_1 Opt_2 N_SCF N_Opt Time\/CPU NiceDay?/' \
    | sed '$a\' \
    | awk '{printf "%-26s %-12s %-12s %-8s %-8s %-8s %-8s %-8s %-8s %-8s %-10s %-8s\n", $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12}' \
    > "$filename.dat"
rm "$filename.po_temp"

