#!/bin/bash

# FHIaims_260501_SUB.sh
# Kyle Bryenton - 2026-05-01

# FHIaims version 260501 is the public release of XDM(Z) 

# Choose if you want it to read the input, or use the defaults below
#read -p "Specify number of nodes [1-5]" -a node
#read -p "Specify walltime: [hh:mm:ss]" -a wall
#read -p "Specify number of processors per node: [n]" -a nprocs
#read -p "Specify amount of total memory: [nM]" -a pmem

# Comment out if you want to read from the user above.
node="1"        # Generally keep as low as possible. Ideally 1
wall="3:00:00"  # Generally always use 3:00:00 or 24:00:00 if you can.
nprocs="4"      # Use fractions of 40 per node on Siku, or 64 per node on Argo
pmem="3900M"    # Limits of approximately 4600M/cpu on Siku, or 3900M/cpu on Argo



# ~~~~~~~~~~~~~~~~~~~~~~~~~~ #

# Get current directory and store it.
WD=$(pwd)
myDIR=$WD

# Choose if you want to loop it yourself, or if you want it to loop for you
# dir=$WD
read -p "Specify directories (wildcards supported -- e.g. */PBE0/*/*): [dir*]/" -a dir

# Expand and loop through directories, submiting each one.
for ii in $dir/; do
    cd $ii/
    name=$(echo $ii | sed 's/.$//' | sed 's/.*\///') #Uses only the deepest directory's name
    cat > ${name%_}.slm <<EOF
#!/bin/bash
#SBATCH --nodes=$node
#SBATCH --ntasks-per-node=$nprocs
#SBATCH --mem-per-cpu=$pmem
#SBATCH --time=$wall
#SBATCH --job-name=${name%_}
#SBATCH --account=def-ejohnson

module purge
module load StdEnv/2023
module load intel/2023.2.1 intelmpi/2021.9.0 imkl/2023.2.0 libxc/6.2.2

# These environment variables set per FHIaims manual p.20
export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
export MKL_DYNAMIC=FALSE
ulimit -s unlimited

mpirun ~/projects/def-ejohnson/FHIaims/FHIaims_260501/build/aims.260501.scalapack.mpi.x </dev/null > ${name%/}.out
EOF
    sbatch ${name%/}.slm
    cd $myDIR #Navigates back to directory the script was started from
done
