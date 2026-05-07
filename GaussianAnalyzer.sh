#!/bin/bash

# GaussianAnalyzer.sh
# Kyle Bryenton - 2026-05-06
#
#     This script will check your jobs to tell you if they crashed or not
#     It sorts them into total jobs, unsubmitted, in queue, completed, and crashed
#     Crashed jobs are displayed explicitly so you can quickly pushd or cd to them
#     
#     This simple script will check all subfolders in the pwd.
#     To run it over multiple folders, you'd execute something like:
#
#     for dir in */ ; do cd $dir ; GaussianAnalyzer.sh ; cd .. ; done > GaussianAnalyzer.dat 

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
# - else the out exists and says "Optimization completed", so complete++

extra_checks=1
debug=1
for dir in */ ; do
    out_str=""
    cd "$dir"
    ((Total++))
    if [[ -z $(ls -f | grep .slm) ]] && [[ -z $(ls -f | grep .out) ]] ; then 
    ((Unsubmit++))
    elif [[ -z $(ls -f | grep .out) ]] ; then
    	((Queued++))
    elif [[ -z $(tail -5 control.out | grep "Normal termination") ]] ; then
    	((Crashed++))
	out_str+=" | Didn't terminate normally"
	if (( debug == 0 )) ; then
	    echo "${WD}/${dir}" >> $WD/GaussianAnalyzer_CrashedJobs.temp
	else
            echo -e "${WD}/${dir}\t\t${out_str}" >> $WD/GaussianAnalyzer_CrashedJobs.temp
	fi
    else 
        if (( extra_checks == 1 )) ; then
	    inp=(*.in)
	    inp=${inp[0]}
	    out=${inp%.in}.out #Assumes the .out is the same basename as the .in
	    # Backup in case it isn't, try your best, don't get a slurm file.
	    if [[ ! -f "$out" ]] ; then
                out=$(find . -maxdepth 1 -name "*.out" ! -name "slurm*" | head -n 1)
            fi
	    ok=1
            # Check if opt was called
	    if grep -iqE " opt" "$inp" ; then
                if ! grep -q  "Optimization completed" "$out" ; then
		    out_str+=" | Geometry not converged"
		    ok=0
		fi
	    fi
	    # Check if freq was called
	    is_there_atom_2=$(grep -A6 "Standard orientation:" control.out | head -n 7 | tail -n 1 | awk '{print $1}')
	    if grep -iqE " freq" "$inp" && [[ "$is_there_atom_2" == "2" ]] ; then
	        freq=$(grep "Frequencies --" control.out | head -1 | awk '{print $(NF-2)}')
                if [[ -z "$freq" ]] ; then
                    out_str+=" | No freqs detected"
		    ok=0
                fi
                if (( $(echo "$freq < 0" | bc -l) )) ; then
                    out_str+=" | Negative freqs detected"
                    ok=0
                fi
	    fi
	    # If either is not ok, crashed++, else, completed++
	    if (( ok == 1 )) ; then
	        ((Completed++))
	    else
	        ((Crashed++))
	        if (( debug == 0 )) ; then
                    echo "${WD}/${dir}" >> $WD/GaussianAnalyzer_CrashedJobs.temp
                else
                    echo -e "${WD}/${dir}\t\t${out_str}" >> $WD/GaussianAnalyzer_CrashedJobs.temp
                fi
	    fi
	else
    	    ((Completed++))
	fi
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
                                     cat GaussianAnalyzer_CrashedJobs.temp ;
                                     rm GaussianAnalyzer_CrashedJobs.temp ;
fi
echo -e "\n"

# Cleanup
unset Total Unsubmit Queued Completed Crashed dir WD
