#!/bin/bash

# ORCAAnalyzer.sh
# Kyle Bryenton - 2026-02-17
#
#     This script will check your jobs to tell you if they crashed or not
#     It sorts them into total jobs, unsubmitted, in queue, completed, and crashed
#     Crashed jobs are displayed explicitly so you can quickly pushd or cd to them
#     
#     This simple script will check all subfolders in the pwd.
#     To run it over multiple folders, you'd execute something like:
#
#     for dir in */ ; do cd $dir ; ORCAAnalyzer.sh ; cd .. ; done > JobAnalyzer.dat 

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
# - else the out exists and says "ORCA TERMINATED NORMALLY", so complete++

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
    elif [[ -z $(tail -5 control.out | grep "ORCA TERMINATED NORMALLY") ]] ; then
    	((Crashed++))
	out_str+=" | Didn't terminate normally"
	if (( debug == 0 )) ; then
	    echo "${WD}/${dir}" >> $WD/ORCAAnalyzer_CrashedJobs.temp
	else
            echo -e "${WD}/${dir}\t\t${out_str}" >> $WD/ORCAAnalyzer_CrashedJobs.temp
	fi
    else 
        if (( extra_checks == 1 )) ; then
	    inp=(*.inp)
	    out=${inp%.inp}.out #Assumes the .out is the same basename as the .inp
	    ok=1
            # Check if opt was called
	    if grep -iqE "^!.*opt|^%method.*runtyp opt" "$inp" ; then
                if ! grep -q  "THE OPTIMIZATION HAS CONVERGED" "$out" ; then
		    out_str+=" | Geometry not converged"
		    ok=0
		fi
	    fi
	    # Check if freq was called
	    if grep -iqE "^!.*freq|^%freq" "$inp" ; then
                freqs=$(grep -A11 "VIBRATIONAL FREQUENCIES" "$out" | tail -n +6 |  sed '/^   /!d' | awk '{print $2}')
                if [[ -z "$freqs" ]] ; then
                    out_str+=" | No freqs detected"
		    ok=0
                fi
                for freq in $freqs ; do
                    if (( $(echo "$freq < 0" | bc -l) )) ; then
                        out_str+=" | Negative freqs detected"
			ok=0
                    fi
                done
	    fi
	    # If either is not ok, crashed++, else, completed++
	    if (( ok == 1 )) ; then
	        ((Completed++))
	    else
	        ((Crashed++))
	        if (( debug == 0 )) ; then
                    echo "${WD}/${dir}" >> $WD/ORCAAnalyzer_CrashedJobs.temp
                else
                    echo -e "${WD}/${dir}\t\t${out_str}" >> $WD/ORCAAnalyzer_CrashedJobs.temp
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
                                     cat ORCAAnalyzer_CrashedJobs.temp ;
                                     rm ORCAAnalyzer_CrashedJobs.temp ;
fi
echo -e "\n"

# Cleanup
unset Total Unsubmit Queued Completed Crashed dir WD
