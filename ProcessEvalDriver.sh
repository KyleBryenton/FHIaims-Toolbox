#!/bin/bash

# ProcessEvalDriver.sh
# Kyle Bryenton - 2025-07-20

if [ $# == 0 ]; then
    echo "ERROR: No result files selected. Exiting.     " >&2
    echo "USAGE: 1) $0 benchmark1.results benchmark2.results ..." >&2
    echo "       2) $0 *.results                        " >&2
    exit 1
fi

# First we want to create something that's easy to copy and paste into latex. The lines after 'cat' will:
# - Only keep lines containing "## data dir:", "MAE", or "ME"
# - Remove the "## data dir:"
# - Remove the " MAE        ---" and " ME        ---"
# - Will print the "## data dir" line final `n` subdirectory names for processing. These are likely basis / functional / etc
# - Remove all the newlines
# - Add a newline back in before each basis, so now we have one row per system
# - Format columns to get pre-defined spacing, aligning them

#Note, if n gets large the programs gets kind of screwy. Keep it smaller than your home directory.
n=3 # Keep `n` last subdirectory names from "## data dir:" line
for res in "$@" ; do
    grep -E '(## data dir:|MAE|ME)' "$res" \
        | sed "s/## data dir://" \
        | sed -E "s/( MAE        ---| ME        ---)/ /g" \
        | awk -F '/' -v n="$n" '
            {
                if (NF > 1) {
                    printf "#" ;
                    for (i=NF-n+1 ; i<=NF ; i++) {
                        printf "%s ", (i>0 ? $(i):"N/A") ;
                    }
                    printf "\n" ;
                } else {
                    print $0 ; 
                }
            }' \
        | tr -d "\n" \
        | sed -e "s/#/\n/g" \
        | awk -v n="$((n+2))" '{
              for (i=1 ; i<=n ; i++) {
                  printf "%-28s  ", $i;
              }
              printf "\n" ;
          }' \
        > "${res%.*}.ped_temp"
done

# Now combine files, generate a header
header=$(awk -v n="$((n+2))" 'BEGIN {
    if (n > 4) {
        for (i=1 ; i<=n-4 ; i++) {
            printf "%-28s  ", "..." ;
        }
    }
    printf "%-28s  %-28s  %-28s  %-28s", "Basis", "Functional", "MAE", "ME" ;
}')
{
    echo "$header"
    cat *.ped_temp | sed '/^[[:space:]]*$/d' | sort -k1,1 -k2,2V -k3,3V #Note, this may have to change depending on how many lines are kept
} > "${res%.*}.dat"
rm *.ped_temp

