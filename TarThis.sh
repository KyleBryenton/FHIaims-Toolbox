#!/bin/bash

# TarThis.sh
# Kyle Bryenton - 2024-09-15
#
# This will tar the file given as an input argument.


if [ "$#" -ne 1 ]; then
    echo "  USAGE: $0 <directory to tar>"
    exit 1
fi

dir="$1"

if [ ! -e "$dir" ]; then
    echo "Error: File or directory '$dir' does not exist."
    exit 1
fi


cat > ${dir%/}.slm <<EOF
#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --mem=16000M
#SBATCH --time=24:00:00
#SBATCH --job-name=${dir%/}
#SBATCH --account=def-ejohnson

echo "*** Start:     $(date)"
mpirun tar -czvf ${dir%/}.tar.gz $dir
echo "*** End:     $(date)"
EOF

sbatch ${dir%/}.slm

