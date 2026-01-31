#!/bin/bash

# Kyle R Bryenton 2026-01-30
# MonoCycle01.sh

# Purpose: 
# To generate the ORCA input structure for phase 1 of the monomer cycle.


# KNOWN ISSUES:
#   The current implementation only assumes one ligand
#   This will be an issue when we consider co-lixivants
#   like a CN / Glycinate combination.


set -e  # Exit immediately if a command exits with a non-zero status

InputExit() {
    echo "$1"
    echo "Input directory structure invalid. Exiting." >&2
    echo "USAGE: $0 <dir>"      >&2
    echo "    <dir>"            >&2
    echo "    ├── control.inp"  >&2
    echo "    ├── complex.xyz"  >&2
    echo "    ├── ligand.xyz"   >&2
    echo "    └── metal.xyz"    >&2
    exit 1
}


# Check for input file structure
echo "Checking inputs exist..."
if [ $# -ne 1 ] ; then
    InputExit "ERROR: One input directory must be specified as an input argument."
fi
dir=$1
if [ ! -d "$dir" ] ; then
    InputExit "ERROR: Input directory '$@' not detected."
fi
if [ ! -f "$dir"/control.inp ] ; then
    InputExit "ERROR: ORCA control file '$dir/control.inp' not detected."
fi
for species in complex metal ligand ; do
    if [ ! -f "$dir/$species.xyz" ] ; then
        InputExit "ERROR: XYZ geometry file '$dir/$species.xyz' not detected."
    fi
done

# Check the control.inp file
echo "Validating control.inp..."
if ! grep -iq "^!" $dir/control.inp ; then
    InputExit "ERROR: No functional detected '$dir/control.inp'"
fi
for block in %basis %method %freq %scf %geom %pal ; do
    if ! grep -iq "^$block" $dir/control.inp ; then
        InputExit "ERROR: No '%$block' block detected in '$dir/control.inp'"
    fi
done
if ! grep -iq '^\*xyzfile' "$dir/control.inp"; then
    InputExit "ERROR: No '*xyzfile' line found in '$dir/control.inp'"
fi

# Check the XYZ files for multiplicity, charge, and balanced elements
echo "Reading Geometries..."
read chg_c mul_c <<< "$(sed -n '2p' $dir/complex.xyz)"
read chg_m mul_m <<< "$(sed -n '2p' $dir/metal.xyz)"
read chg_l mul_l <<< "$(sed -n '2p' $dir/ligand.xyz)"
for i in chg_c chg_m chg_l mul_c mul_m mul_l ; do
    if ! [[ "$charge" =~ ^-?[0-9]+$ ]] || ! [[ "$mult" =~ ^-?[0-9]+$ ]]; then
        InputExit "ERROR: Non-integer charge ($charge) or multiplicity ($multiplicity) found in line 2 of one of the input .xyz files."
    fi
done


# We now want to check that the complex can be built from the ligand and the metal
echo "Validating Geometries..."

# Step 1: Count atoms in each input .xyz vile
atCount_c="$(tail -n +3 "$dir/complex.xyz" | awk '{print $1}' | sort | uniq -c)"
atCount_l="$(tail -n +3 "$dir/ligand.xyz" | awk '{print $1}' | sort | uniq -c)"
atCount_m="$(tail -n +3 "$dir/metal.xyz" | awk '{print $1}' | sort | uniq -c)"

# Step 2: Store arrays of how many of each element exists, taking them from the complex
elems=()
num_cs=()
num_ls=()
num_ms=()
lines=$(echo "$atCount_c" | wc -l)
for ((index=0 ; index<lines ; index++)) ; do
    # Read the element
    line=$((index+1))
    elem=$(echo "$atCount_c" | sed -n "${line}p" | awk '{printf $2}')
    # Get the number of times that element appears in each count
    num_c=$(echo "$atCount_c" | awk -v e="$elem" '$2 == e {print $1}')
    num_l=$(echo "$atCount_l" | awk -v e="$elem" '$2 == e {print $1}')
    num_m=$(echo "$atCount_m" | awk -v e="$elem" '$2 == e {print $1}')
    # If it doesn't appear, set it to 0
    if [ -z "$num_c" ] ; then num_c=0 ; fi
    if [ -z "$num_l" ] ; then num_l=0 ; fi
    if [ -z "$num_m" ] ; then num_m=0 ; fi
    # Store as array
    elems[index]="$elem"
    num_cs[index]="$num_c"
    num_ls[index]="$num_l"
    num_ms[index]="$num_m"
done

# Step 3: Ensure metal and ligand don't contain any extra elements
lines=$(echo "$atCount_m" | wc -l)
for ((index=0 ; index<lines ; index++)) ; do
    line=$((index+1))
    elem=$(echo "$atCount_m" | sed -n "${line}p" | awk '{printf $2}')
    if ! echo "${elems[@]}" | grep -qwi "$elem" ; then
        InputExit "ERROR: Found element '$elem' in metal but not in complex: ${elems[@]}"
    fi
done
lines=$(echo "$atCount_l" | wc -l)
for ((index=0 ; index<lines ; index++)) ; do
    line=$((index+1))
    elem=$(echo "$atCount_l" | sed -n "${line}p" | awk '{printf $2}')
    if ! echo "${elems[@]}" | grep -qwi "$elem" ; then
        InputExit "ERROR: Found element '$elem' in ligand but not in complex: ${elems[@]}"
    fi
done

# Step 4: We now want to solve num_cs[i] = n * num_ms[i] + m * num_ls[i] for n and m
# These complexes should generally have n=1 and m<=6, so lets search over n,m={1..10}
# Searching rather than calculating is preferable in bash.

n_metal=0
m_ligand=0
found=0
lines=$(echo "$atCount_c" | wc -l)
for n in {1..10} ; do
    for m in {1..10} ; do
        # Assume n,m work. Change if they don't.
	ok=1
	# Loop through each element, see if current n,m satisfy all
        for ((index=0 ; index<lines ; index++)) ; do
            lhs=${num_cs[index]}
            rhs=$(( n * num_ms[index] + m * num_ls[index] ))
            # If any don't work, abandon 
	    if ((lhs != rhs)) ; then
                ok=0
		break
	    fi
	done
	# If all worked, match is found.
	if (( ok )) ; then
            found=1
	    n_metal=$n
	    m_ligand=$m
	    break
	fi
    done
done
echo "Reading Geometries:"
echo "- Complex is $atCount_c"
echo "-   Metal is $atCount_m"
echo "-  Ligand is $atCount_l"
echo "Thus the Complex is formed with n=$n_metal Metal and m=$m_ligand Ligand"

# Next step is to ensure charge and multiplicity follow the n/m rules

awk '/^%basis/ {f=1} flag {print} /^[[:space:]]*end[[:space:]]*$/ && flag {exit}
' file.inp





# ALL CHECKS COMPLETED
# BEGIN ASSEMBLING INPUTS

echo "___Executing MonoCycle01.sh___"

# Aborts if 01_MonoCycle already exists. 
if [ ! -d "01_MonoCycle" ]; then
    mkdir "01_MonoCycle"
    mkdir 01_MonoCycle/Aq_Phase
    mkdir 01_MonoCycle/Aq_Phase/Complex
    mkdir 01_MonoCycle/Aq_Phase/Ligand
    mkdir 01_MonoCycle/Aq_Phase/Metal
    mkdir 01_MonoCycle/Gas_Phase
    mkdir 01_MonoCycle/Gas_Phase/Complex
    mkdir 01_MonoCycle/Gas_Phase/Ligand
    mkdir 01_MonoCycle/Gas_Phase/Metal
else
    echo "ABORTING: '01_MonoCycle' directory already exists. "
    echo "Please delete or rename this directory, then re-run."
    exit 1  
fi

