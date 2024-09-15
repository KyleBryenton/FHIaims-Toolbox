#!/bin/bash

# BuildThis.sh
# Kyle Bryenton - 2024-09-15
#
#    This script can be used to build FHI-aims code via a submission script.
#    - Put BuildThis.sh in your scripts directory (add to .bashrc path)
#    - Navigate to your FHI-aims directory
#    - mkdir build/
#    - Move your initial_cache.cmake into build/
#    - cd build/
#    - Run Build_This.sh
#    - It will autodectect if cmake -C initial_cache.cmake .. needs to be run or not
#    - It will output everything into a slurm.out file
# ... 
# Because this is based on my submission script, this could support 
# building multiple installations via wildcards. But this is untested.

# Specify resources to request 
node="1"
wall="24:00:00"
nprocs="16"
pmem="4000M"

# Gets current directory and stores it.
WD=$(pwd)
myDIR=$WD

dir=$WD          # MOVED DIR NAME TO HERE FOR THE FHIAIMS_XDMR_HERE SCRIPT ONLY

for ii in $dir/; do

        cd $ii/
        i=$dir | sed 's/\///g' #Causes an error if a directory isn't chosen.

	# Choose one of the two naming conventions.
        # name=$(echo $ii | sed 's/\//_/g')                #Appends all parent directory names.
        name=$(echo $ii | sed 's/.$//' | sed 's/.*\///') #Uses only the deepest directory's name

        cat > ${name%_}.slm <<EOF
#!/bin/bash
#SBATCH --nodes=$node
#SBATCH --ntasks-per-node=$nprocs
#SBATCH --mem-per-cpu=$pmem
#SBATCH --time=$wall
#SBATCH --job-name=${name%_}
#SBATCH --account=def-ejohnson

echo -n "*** Start: " ; date
echo "*** Loading Modules ..."
echo -e "\n\n\n"

module purge
module load StdEnv/2023
module load intel/2023.2.1 intelmpi/2021.9.0 imkl/2023.2.0 libxc/6.2.2

echo -e "\n\n\n"
echo -n "*** Modules Loaded: " ; module list 
echo -e "\n\n\n"

if [ ! -f "Makefile" ] ; then
  echo "---- Makefile does not exist. Running cmake... ----"
  cmake -C initial_cache.cmake ..
fi

make -j $nprocs

echo -e "\n\n\n"
echo -n "*** End: " ; date
EOF

        sbatch ${name%_}.slm

        cd $myDIR #Navigates back to directory the script was started from

done

