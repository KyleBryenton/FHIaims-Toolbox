#!/bin/bash

# FHIaims_240507_Stable_SUB.sh
# Kyle Bryenton - 2024-09-15
#
# A slurm submission script with wildcard support for FHIaims_240507_Stable


# Choose if you want it to read the input, or just use some standard
#read -p "Specify number of nodes [1-5]" -a node
#read -p "Specify walltime: [hh:mm:ss]" -a wall
#read -p "Specify number of processors per node: [n]" -a nprocs
#read -p "Specify amount of total memory: [nM]" -a pmem
node="1"
wall="3:00:00"
nprocs="1"
pmem="4000M"

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

mpirun ~/projects/def-ejohnson/FHIaims/FHIaims_240507_Stable/build/aims.240507.scalapack.mpi.x </dev/null > ${name%/}.out
EOF
    sbatch ${name%/}.slm
    cd $myDIR #Navigates back to directory the script was started from
done
