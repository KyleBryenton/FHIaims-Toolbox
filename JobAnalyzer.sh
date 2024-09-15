#!/bin/bash

# JobAnalyzer.sh
# Kyle Bryenton - 2024-09-15
#
#     This script will check your jobs to tell you if they crashed or not
#     It sorts them into total jobs, unsubmitted, in queue, completed, and crashed
#     Crashed jobs are displayed explicitly so you can quickly pushd or cd to them
#     
#     This simple script will check all subfolders in the pwd.
#     To run it over multiple folders, you'd execute something like:
#
#     for dir in */ ; do cd $dir ; JobAnalyzer.sh ; cd .. ; done > JobAnalyzer.dat 

# Instantiation
Total=0
Unsubmit=0
Queued=0
Completed=0
Crashed=0
WD=$(pwd)

# Do work
# - For each directory that exists, total++
# - then inside it, if neither a .slm nor .out exist, unsubmit++
# - else one of them exists, if the out doesn't exist, queued++
# - else the .out must exist, if it doesn't have "nice day", crashed++
# - else the out exists and says "nice day", so complete++
for dir in */ ; do
    cd "$dir"
    ((Total++))
    if [[ -z $(ls -f | grep .slm) ]] && [[ -z $(ls -f | grep .out) ]] ; then 
    ((Unsubmit++))
    elif [[ -z $(ls -f | grep .out) ]] ; then
    	((Queued++))
    elif [[ -z $(grep "Have a nice day." *.out) ]] ; then
    	((Crashed++))
	echo "${WD}/${dir}" >> $WD/JobAnalyzer_CrashedJobs.temp
    else 
    	((Completed++))
    fi
    cd ..
done

# Write Output
echo                                      "JOB DIRECTORY: " $PWD
echo                                      "     Total Jobs: " $Total
if [[ $Completed != 0 ]]      ; then echo "      Completed: " $Completed ; fi
if [[ $Completed != $Total ]] ; then echo " ~~~ WARNING: $(($Total - $Completed)) not completed ~~~ " ; fi
if [[ $Unsubmit != 0 ]]       ; then echo "    Unsubmitted: " $Unsubmit ; fi
if [[ $Queued != 0 ]]         ; then echo "       In Queue: " $Queued ; fi
if [[ $Crashed != 0 ]]        ; then echo "        Crashed: " $Crashed ; 
                                     echo -e " CRASHED JOBS: " ;
                                     cat JobAnalyzer_CrashedJobs.temp ;
                                     rm JobAnalyzer_CrashedJobs.temp ;
fi
echo -e "\n"

# Cleanup
unset Total Unsubmit Queued Completed Crashed dir WD
