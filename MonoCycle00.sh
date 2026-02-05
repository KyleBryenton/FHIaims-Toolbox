#!/bin/bash

# Kyle R Bryenton 2026-02-05
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
    echo "------------------------------" >&2
    echo "ERROR: Input Checks Failed"     >&2
    echo "USAGE: $0 <dir>"                >&2
    echo "    <dir>"                      >&2
    echo "    ├── control.inp"            >&2
    echo "    ├── complex.xyz"            >&2
    echo "    ├── ligand.xyz"             >&2
    echo "    └── metal.xyz"              >&2
    echo "    └── control.slm (optional)" >&2
    echo "EXITING"                        >&2
    exit 1
}

# Store ptable array, used for counting electrons for multiplicity checks
ptable=(
    Emptium 
    H  He 
    Li Be B  C  N  O  F  Ne 
    Na Mg Al Si P  S  Cl Ar 
    K  Ca Sc Ti V  Cr Mn Fe Co Ni Cu Zn Ga Ge As Se Br Kr 
    Rb Sr Y  Zr Nb Mo Tc Ru Rh Pd Ag Cd In Sn Sb Te I  Xe 
    Cs Ba La Ce Pr Nd Pm Sm Eu Gd Tb Dy Ho Er Tm Yb Lu Hf Ta W  Re Os Ir Pt Au Hg Tl Pb Bi Po At Rn 
    Fr Ra Ac Th Pa U  Np Pu Am Cm Bk Cf Es Fm Md No Lr Rf Db Sg Bh Hs Mt Ds Rg Cn Nh Fl Mc Lv Ts Og
)

# Check for input file structure
echo "Checking inputs exist..."
if [ $# -ne 1 ] ; then
    InputExit "    Failed: One input directory must be specified as an input argument."
fi
dir=$1
if [ ! -d "$dir" ] ; then
    InputExit "    Failed: Input directory '$@' not detected."
fi
if [ ! -f "$dir"/control.inp ] ; then
    InputExit "    Failed: ORCA control file '$dir/control.inp' not detected."
fi
for species in complex metal ligand ; do
    if [ ! -f "$dir/$species.xyz" ] ; then
        InputExit "    Failed: XYZ geometry file '$dir/$species.xyz' not detected."
    fi
done
echo "    Success: Inputs detected."

# Check the control.inp file
echo "Checking control.inp..."
if ! grep -iq "^!" $dir/control.inp ; then
    InputExit "    Failed: No functional detected '$dir/control.inp'"
fi
# All of these blocks are required for the control.inp
for block in %basis %method %geom %freq %scf %cpcm %pal ; do
    if ! grep -iq "^$block" $dir/control.inp ; then
        InputExit "     Failed: No '%$block' block detected in '$dir/control.inp'"
    fi
done
# Inputs must be entered via .xyz files
if ! grep -iq "^\*xyzfile" "$dir/control.inp" ; then
    InputExit "    Failed: No '*xyzfile' line found in '$dir/control.inp'"
fi
# We require this exactly to comment Opts on and off.
if ! grep -iq "^%method RunTyp Opt end" "$dir/control.inp" ; then
    InputExit "    Failed: Missing required line: '%method RunTyp Opt end'"
fi
# We require the frequency line to begin with AnFreq True.
if ! grep -iq "^%freq AnFreq True" "$dir/control.inp" ; then
    InputExit "    Failed: The '%freq' line must start with '%freq AnFreq True'"
fi
echo "    Success: All required input blocks detected"

# Check the XYZ files for multiplicity, charge, and balanced elements
echo "Checking .xyz files for charges and multiplicities..."
read chg_c mul_c <<< "$(sed -n '2p' $dir/complex.xyz)"
read chg_m mul_m <<< "$(sed -n '2p' $dir/metal.xyz)"
read chg_l mul_l <<< "$(sed -n '2p' $dir/ligand.xyz)"
if ! [[ "$chg_c" =~ ^-?[0-9]+$ ]] || ! [[ "$mul_c" =~ ^-?[0-9]+$ ]] ; then
    InputExit "    Failed: Non-integer charge ($charge) or multiplicity ($multiplicity) found on line 2 of complex.xyz"
fi
if ! [[ "$chg_m" =~ ^-?[0-9]+$ ]] || ! [[ "$mul_m" =~ ^-?[0-9]+$ ]] ; then
    InputExit "    Failed: Non-integer charge ($charge) or multiplicity ($multiplicity) found on line 2 of metal.xyz"
fi
if ! [[ "$chg_l" =~ ^-?[0-9]+$ ]] || ! [[ "$mul_l" =~ ^-?[0-9]+$ ]] ; then
    InputExit "    Failed: Non-integer charge ($charge) or multiplicity ($multiplicity) found on line 2 of ligand.xyz"
fi
printf "%s%3d%s%3d\n" "    - Complex :  chg =" $chg_c " , mul =" $mul_c
printf "%s%3d%s%3d\n" "    -   Metal :  chg =" $chg_m " , mul =" $mul_m
printf "%s%3d%s%3d\n" "    -  Ligand :  chg =" $chg_l " , mul =" $mul_l
echo "    Success: Charge and multiplicity detected"








# We now want to check that the complex can be built from the ligand and the metal
echo "Checking atom list..."



# Step 1: Count atoms in each input .xyz vile
atCount_c="$(tail -n +3 "$dir/complex.xyz" | awk '{print $1}' | sort | uniq -c)"
atCount_l="$(tail -n +3 "$dir/ligand.xyz" | awk '{print $1}' | sort | uniq -c)"
atCount_m="$(tail -n +3 "$dir/metal.xyz" | awk '{print $1}' | sort | uniq -c)"
echo "    - Complex :  " $atCount_c
echo "    -   Metal :  " $atCount_m
echo "    -  Ligand :  " $atCount_l
echo "    Success: Atom lists populated"


# Step 2: Store arrays of how many of each element exists, taking them from the complex
echo "Checking the complex can be formed by the metal and ligand..."

elems=()
num_cs=()
num_ls=()
num_ms=()

# Get atom counts per complex, metal, ligand, in order they appear in the complex
lines=$(echo "$atCount_c" | wc -l)
for ((index=0 ; index<lines ; index++)) ; do
    # Read the element
    line=$((index+1))
    elem=$(echo "$atCount_c" | sed -n "${line}p" | awk '{print $2}')
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

# Ensure metal and ligand don't contain any extra elements
lines=$(echo "$atCount_m" | wc -l)
for ((index=0 ; index<lines ; index++)) ; do
    line=$((index+1))
    elem=$(echo "$atCount_m" | sed -n "${line}p" | awk '{printf $2}')
    if ! echo "${elems[@]}" | grep -qwi "$elem" ; then
        InputExit "    Failed: Found element '$elem' in metal but not in complex: ${elems[@]}"
    fi
done
lines=$(echo "$atCount_l" | wc -l)
for ((index=0 ; index<lines ; index++)) ; do
    line=$((index+1))
    elem=$(echo "$atCount_l" | sed -n "${line}p" | awk '{printf $2}')
    if ! echo "${elems[@]}" | grep -qwi "$elem" ; then
        InputExit "    Failed: Found element '$elem' in ligand but not in complex: ${elems[@]}"
    fi
done



# Step 3: We now want to solve num_cs[i] = n * num_ms[i] + m * num_ls[i] for n and m
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
    if (( ! found )) ; then
        InputExit "    Failed: The complex != n*metal + m*ligand for n,m<=10. Suspected imbalanced equation."
    fi
done
echo "    Success: The complex is formed with n=$n_metal * metal + m=$m_ligand * ligand"



# Step 5: Ensure charge follows the n/m rules
echo "Checking charge balancing..."

lhs=chg_c
rhs=$(( n_metal * chg_m + m_ligand * chg_l))
if (( lhs == rhs )) ; then
    echo "    Success: complex charge ($chg_c) == n ($n_metal) * metal charge ($chg_m) + m ($m_ligand) * ligand charge ($chg_l)"
else
    InputExit "    Failed: complex charge ($chg_c) != n ($n_metal) * metal charge ($chg_m) + m ($m_ligand) * ligand charge ($chg_l)"
fi





# Step 6: Count electrons. Make sure multiplicty follows (2S+1) even/odd rules
echo "Checking multiplicities via 2S+1 rule...."

for syst in Complex Metal Ligand ; do
    if [[ $syst == "Complex" ]] ; then
        atCount=$atCount_c
	chg=$chg_c
    elif [[ $syst == "Metal" ]] ; then
        atCount=$atCount_m
        chg=$chg_m
    elif [[ $syst == "Ligand" ]] ; then
        atCount=$atCount_l
        chg=$chg_l
    else
       InputExit "    Failed: Issue with multiplicty checking loop."
    fi
    lines=$(echo "$atCount" | wc -l)
    n_elec=0
    for ((index=0 ; index<lines ; index++)) ; do
        Z=-1 #Reset Z, atomic number of each element
        line=$((index+1))
        n_elem=$(echo "$atCount" | sed -n "${line}p" | awk '{print $1}')
        elem=$(echo "$atCount" | sed -n "${line}p" | awk '{print $2}')
        # Look up index of matching element, that is the number of electrons
        for i in "${!ptable[@]}" ; do
            if [[ "${ptable[i],,}" == "${elem,,}" ]] ; then
                Z=i
                break
            fi
        done
        if (( $Z<0 )) ; then
            InputExit "    Failed: Could not find matching element '$elem' from $syst's '$atCount_c' in 'ptable' array"
        fi
        (( n_elec += $n_elem*$Z ))
    done
    (( n_elec += $chg_c ))
    if (( mul_c%2 == (n_elec+1)%2 )) ; then
        printf "%s%7s%s%3d%s%3d\n" "    - " $syst " :  valid with n_elec =" $n_elec " , multiplicity =" $mul_c
    else
        InputExit "    Failed: $syst multiplicity invalid with n_elec=$n_elec, multiplicity='$mul_c'"
    fi
done
echo "    Success: Multiplicies follow the even/odd rules. Please verify, this only goes so far."




# Create a .slm or partially validate a provided one which it will use instead.
echo "Checking .slm file (if it exists)..."
def_nod="1"
def_pro="8"
def_mem="3900M" # MAX: 3906.25M/core for Argo, ~4650M/core for Siku. Use 3900/4600
def_tim="24:00:00"
def_nam="MonoCycle00"
def_acc="def-ejohnson"
def_inp='control'
def_out="control"
n_slm=$(ls -1 $dir/*.slm 2>/dev/null | wc -l)
if (( n_slm>1 )) ; then
    InputExit "    Failed: Multiple .slm files detected. Reduce to 1 (to overwrite defaults) or 0 (to use defaults)"
fi
if (( n_slm==0 )) ; then
    cat > "$dir/$def_inp.slm" << EOF
#!/bin/bash
#SBATCH --nodes=$def_nod
#SBATCH --ntasks-per-node=$def_pro
#SBATCH --mem-per-cpu=$def_mem
#SBATCH --time=$def_tim
#SBATCH --job-name=$def_nam
#SBATCH --account=$def_acc

module purge
module load StdEnv/2023 gcc/12.3 openmpi/4.1.5
module load orca/6.1.1

\$EBROOTORCA/orca $def_inp.inp > $def_out.out

if tail -2 "${def_inp}.out" | head -1 | grep -q "ORCA TERMINATED NORMALLY" ; then
  rm -f ${def_inp}.bibtex       ${def_inp}.densities       ${def_inp}.densitiesinfo       ${def_inp}.opt \
        ${def_inp}.engrad       ${def_inp}.gbw             ${def_inp}.hess                ${def_inp}.property.txt \
        ${def_inp}_atom*.bibtex ${def_inp}_atom*.densities ${def_inp}_atom*.densitiesinfo ${def_inp}_atom*.opt \
        ${def_inp}_atom*.engrad ${def_inp}_atom*.gbw       ${def_inp}_atom*.hess          ${def_inp}_atom*.property.txt \
        ${def_inp}_atom*.out    slurm*.out
fi

EOF
echo "    Success: Existing .slm not detected, created $dir/$def_inp.slm using defaults"
else
    echo "    WARNING: A *.slm file already exists. This will be used in place of the defaults."
    echo "           | The user will be responsible to ensure compatibility. If this was a mistake,"
    echo "           | delete the '01_MonoCycle' directory and the .slm file, and rerun. Otherwise, "
    echo "           | this program will try to interpret variables from the existing .slm"
    echo "           | Recomendation: Instead of using an external script, change the defaults."
    def_inp=("$dir"/*.slm)
    def_inp=${def_inp[0]##*/}
    def_inp=${def_inp%.slm}
    def_out=$(grep "EBROOTORCA/orca" $dir/*.slm | awk '{print $NF}')
    def_out=${def_out%.out}
    def_pro=$(grep "#SBATCH --ntasks" $dir/*.slm | awk -F"[ =]" '{print $3}')
    def_nam=$(grep "#SBATCH --job-name=" $dir/*.slm | awk -F"[ =]" '{print $3}')
    orca_ver=$(grep "module load orca/" $dir/*.slm | awk -F"[ /]" '{print $4}')
    if [[ -z "$def_inp" ]] || [[ "$def_inp" =~ [[:space:]] ]] ; then
        InputExit "    Failed: Could not read provided .slm. The .slm file must not have spaces in the name, detected '$def_inp'"
    fi
    if [[ -z "$def_out" ]] || [[ "$def_out" =~ [[:space:]] ]] ; then
        InputExit "    Failed: Could not read provided .slm. The output must be a single word followed by .out, detected '$def_out'"
    fi
    if [[ -z "$def_nam" ]] || [[ "$def_nam" =~ [[:space:]] ]] ; then
        InputExit "    Failed: Could not read provided .slm. The job-name must be a single word, detected '$def_nam'"
    fi
    if [[ -z "$def_pro" ]] || ! [[ "$def_pro" =~ ^[0-9]+$ ]] || (( def_pro == 0 )) ; then
        InputExit "    Failed: Could not read provided .slm. ntasks must be a positive integer, detected '$def_pro'"
    fi
    if [[ "$orca_ver" != "6.1.1" ]] ; then
        InputExit "    Failed: Supplied ORCA version was not 6.1.1, detected '$orca_ver'"
    fi
    echo "    - Input name:  $def_inp"
    echo "    - Output name: $def_out"
    echo "    - Job name:    $def_nam"
    echo "    - ntasks:      $def_pro"
    echo "    - ORCA vers:   $orca_ver"
    echo "    - Assuming:    all other inputs are as intended."
    echo "    Success: Provided .slm file was parsed successfully."
fi



echo " ---- Checks Completed | Assembling Inputs ---- "



#echo " Your basis is:"
#basis=$(awk '/^%basis/ {flag=1} flag {print} /^end$/ && flag {exit}' $dir/control.inp)
#echo "$basis"


# ALL CHECKS COMPLETED
# BEGIN ASSEMBLING INPUTS


# Aborts if 01_MonoCycle already exists.
top_dir_name="01_MonoCycle"
if [ -d "$top_dir_name" ]; then
    echo "ERROR: A '01_MonoCycle/' directory already exists. "
    echo "     | Please delete/rename this directory, then re-run."
    echo "     | Exiting."
    exit 1
fi

for phase in Aq Gas ; do
    for syst in complex metal ligand ; do
        
	dir2="$top_dir_name/$phase/$syst"
	mkdir -p $dir2
        
        cp "$dir/control.inp" "$dir2/$def_inp.inp"
        cp "$dir/$syst.xyz"   "$dir2/geometry.initial"
        cp "$dir/$syst.xyz"   "$dir2/$def_inp.xyz"
        cp "$dir/control.slm" "$dir2/$def_inp.slm"
        
        case "$syst" in
            complex) chg=$chg_c ; mul=$mul_c ;;
            metal)   chg=$chg_m ; mul=$mul_m ;;
            ligand)  chg=$chg_l ; mul=$mul_l ;;
        esac
        
	# Set the charge, multiplicity, and point to correct .xyz file
        sed -i "s/^\*xyzfile.*/\*xyzfile $chg $mul $def_inp.xyz/" $dir2/$def_inp.inp

	# Set nprocs equal to what is set in the .slm file
        sed -i "s/^%pal.*/%pal nprocs=$def_pro end/" $dir2/$def_inp.inp
        
	# Ensure opt is off for calcs with 1 element, and on otherwise
	# .xyz files have the first atom on line 3.
	if (( $(wc -l < $dir2/$def_inp.xyz) < 4 )) ; then
            sed -i "s/^%method/#%method/" $dir2/$def_inp.inp
	    sed -i "s/^%geom/#%geom/"     $dir2/$def_inp.inp
	else
	    sed -i "s/^#%method/%method/" $dir2/$def_inp.inp
	    sed -i "s/^#%geom/%geom/"     $dir2/$def_inp.inp
	fi

	# Ensure solvant is on/off for Aq/Gas phase calcs
	# Aq should be redundant since we checked at top of script, but just in case.
	if [[ "$phase" == "Aq" ]] ; then
            sed -i "s/^#%cpcm/%cpcm/" $dir2/$def_inp.inp
        fi
        if [[ "$phase" == "Gas" ]] ; then
            sed -i "s/^%cpcm/#%cpcm/" $dir2/$def_inp.inp
	fi
        
        # If you want descriptive job names, uncomment this:
        sed -i "s/#SBATCH --job-name=$def_nam/#SBATCH --job-name=${phase}_${syst}/" $dir2/$def_inp.slm

    done
done

echo "    Success: Inputs assembled."
echo "    You may now run these jobes using:"
echo 'for i in $(find '"$top_dir_name"' -name '"$def_inp.slm"'); do pushd "$(dirname "$i")" > /dev/null ; sbatch "$(basename "$i")" ; popd > /dev/null ; done'













