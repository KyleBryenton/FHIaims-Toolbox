#!/bin/bash

# OptSteps.sh
# Kyle Bryenton - 2024-09-15
#
#     This script will check your jobs to tell you how many opt steps were performed
#     This is useful when running XDM. You should keep resubmitting until each job performs
#     0 opt steps. This is to offset the choice in XDM to not recalculate C6 coefficients at
#     each step, but rather, only at the start and end.
#
#     This script will check all subfolders in the pwd, and scan for *.out files
#     So to run it over multiple folders, you'd execute something like:
#
#     for dir in */ ; do cd $dir ; OptSteps.sh >> ../OptSteps.dat ; cd .. ; done

WD=$(pwd)
rm OptSteps.temp 2> /dev/null

for i in */ ; do 
    cd $i
    nStep=$(grep "| Number of relaxation steps " *.out | awk '{print $NF}')
    nStep=${nStep:-"N/A"} # Single point jobs show as "N/A"
    echo -e "$nStep\t$(pwd)" >> $WD/OptSteps.temp
    cd .. 
done
echo "$(sort -r OptSteps.temp)" 
rm OptSteps.temp
