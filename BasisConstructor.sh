#!/bin/bash

# BasisConstructor.sh
# Kyle Bryenton - 2024-09-15
# 
#       Setup: Set the "basis_dir" in the header.
# Description: This script finds FHI-aims geometry.in files and sets the basis in their corresponding control.in files based on the input arguments

# This script has two modes:
#
#    Default: Find all geometry.in in subdirectories that contain a basis matching the input arguments, detect which basis to use based on their filepath, then set their basis accordingly
#      Usage: $ BasisConstructor.sh <basis> <basis> <basis>...
#        E.g: If your input arguments are "li tight", it 
#             - Searches for "light/" and "tight/" directories
#             - Finds all geometry.in inside them
#             - Sets their basis to "light" and "tight" defaults, respectively
#        
#  "-setall": Find all geometry.in in subdirectories, and set all their basis to the one specified in the input argument
#      Usage: $ BasisConstructor.sh -setall <basis>
#        E.g: If your input arguments are "-setall ld", it
#             - Finds all geometry.in in all subdirectories starting from the pwd
#             - Sets their basis to "lightdense" defaults
# 
# Supported Basis Sets:   Basis          Alias
#                       - light          li
#                       - intermediate   in
#                       - tight          ti
#                       - really_tight   re
#                       - lightdense     ld
#                       - lightdenser    ldr
#                       - intdense       id  # Not yet in FHI-aims
#                       - tightdense     td  # Not yet in FHI-aims
#                       - Tier2_aug2     aug2
#
# Notes: - Using <basis> = "all" will attempt to set all of the above
#        - '*_then_lightdense', '*_then_tight', etc... will be included if 'lightdense', 'tight', etc.. are selected.
#        - The script ensures the request basis directories exist before continuing
#  	 - The script will display all directories it will touch, and requies the user to confirm [y,n] before proceeding
#  	 - The old control.in files are preserved as control.old


# TO DO
# - Make it default to using Tight if an element isn't found
# - Display warnings AFTER it finishes working through a directory and printing "DONE". At the moment it ouputs like this: 
#      Processing: /home/bryenton/scratch/592-residual-memory-in-xdm_2024-09-08/temp/Tier2_aug2 ...WARNING: Expected exactly one matching basis file for element 'Au' in directory '/home/bryenton/projects/def-ejohnson/bryenton/FHIaims/FHIaims_240507_Stable_DEV/species_defaults/non-standard/Tier2_aug2'. --- Skipping...
#      DONE

# ~~~~~~~~~~ HEADER and INPUT ~~~~~~~~~~~

# Set the Delete_old_control_flag. If false, preserves the old control.in as control.old
Delete_old_control_flag=false

# Set Basis Directory Locations
basis_dir="${HOME}/projects/def-ejohnson/FHIaims/FHIaims_240507_Stable/species_defaults/"

# Current locations:
Li_dir="${basis_dir}defaults_2020/light"
In_dir="${basis_dir}defaults_2020/intermediate"
Ti_dir="${basis_dir}defaults_2020/tight"
Re_dir="${basis_dir}defaults_2020/really_tight"
LD_dir="${basis_dir}defaults_2020/lightdense"
LDr_dir="${basis_dir}defaults_next/dense/lightdenser"
Aug2_dir="${basis_dir}non-standard/Tier2_aug2"

# Future Locations:
#Li_dir="${basis_dir}defaults_next/standard/light"
#In_dir="${basis_dir}defaults_next/standard/intermediate"
#Ti_dir="${basis_dir}defaults_next/standard/tight"
#Re_dir="${basis_dir}defaults_next/standard/really_tight"
#LD_dir="${basis_dir}defaults_next/dense/lightdense"
#ID_dir="${basis_dir}defaults_next/dense/intdense"
#TD_dir="${basis_dir}defaults_next/dense/tightdense"


# _____Unless you're adding support for a new basis, nothing needs to be modified below this line______








# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# ~~~~~~~~~~ START OF FUNCTION SECTION ~~~~~~~~~~
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#  Input: 
#    - A space-delimited list of elements with appropriate capitalization, in any order
# Ouptut:
#    - The same list of elements, but sorted in periodic-table order
PT_sort() {
    local unique_atom_list=("$@") # Input: A unique list of atoms
    local order=(
        "H"  "He" 
        "Li" "Be" "B"  "C"  "N"  "O"  "F"  "Ne"
        "Na" "Mg" "Al" "Si" "P"  "S"  "Cl" "Ar"
        "K"  "Ca" "Sc" "Ti" "V"  "Cr" "Mn" "Fe" "Co" "Ni" "Cu" "Zn" "Ga" "Ge" "As" "Se" "Br" "Kr"
        "Rb" "Sr" "Y"  "Zr" "Nb" "Mo" "Tc" "Ru" "Rh" "Pd" "Ag" "Cd" "In" "Sn" "Sb" "Te" "I"  "Xe"
        "Cs" "Ba" "La" "Ce" "Pr" "Nd" "Pm" "Sm" "Eu" "Gd" "Tb" "Dy" "Ho" "Er" "Tm" "Yb" "Lu" 
                       "Hf" "Ta" "W"  "Re" "Os" "Ir" "Pt" "Au" "Hg" "Tl" "Pb" "Bi" "Po" "At" "Rn"
        "Fr" "Ra" "Ac" "Th" "Pa" "U"  "Np" "Pu" "Am" "Cm" "Bk" "Cf" "Es" "Fm" "Md" "No" "Lr" 
                       "Rf" "Db" "Sg" "Bh" "Hs" "Mt" "Ds" "Rg" "Cn" "Nh" "Fl" "Mc" "Lv" "Ts" "Og"
    )
    local keyed_atom_list=()
    for element in "${unique_atom_list[@]}"; do
        # - Turns order[@] into a newline-separated list via printf
	    # - Greps the current element, via `-n` it includes the line number followed by ":"
	    # - Prints the first column (the line number)  via cut.
        # This gets the index of the element.
	    local index=$(printf "%s\n" "${order[@]}" | grep -n "^$element$" | cut -d: -f1)
        keyed_atom_list+=("$index $element")
    done
    # - Turns keyed_atom_list[@] into a newline-separated list via printf
    # - Sorts based on the element's index that was inserted into the first column
    # - Prints out the second column via cut.
    local sorted_atom_list=($(printf "%s\n" "${keyed_atom_list[@]}" | sort -n | cut -d" " -f2-))
    echo "${sorted_atom_list[@]}"
}

#  Input:
#    - The path to the basis directory it will use to generate the new basis
#    - A list of directories to scan through, find geometry.in files, and generate a basis for
# Ouptut:
#    - A new control.in file, with the previous basis removed, and a new basis appended to the bottom
Construct_basis() {
    local basis_dir="$1"                                 
    shift ; local basis_list=("$@")                              
    local basis_list_elem output_dir PT_element filename_pattern          
    local -a atom_list unique_atom_list sorted_atom_list matched_files
    local temp_file                                        
    local control_old_flag control_temp_flag basis_temp_flag 
    for basis_list_elem in "${basis_list[@]}" ; do
	control_old_flag=false
	control_temp_flag=false
        basis_temp_flag=false
        echo -n "    Processing: $basis_list_elem ..."
        for output_dir in $(find "$basis_list_elem" -type f -name "geometry.in" | sed "s/\/geometry.in//") ; do
            # Ensure control.old, control.temp, and basis.temp are not already present.
            if [ -e "$output_dir/control.old" ]; then
                temp_file=$(mktemp "$output_dir/control.old.XXXXXX")
                cp "$output_dir/control.old" "$temp_file"
                control_old_flag=true
            fi
            if [ -e "$output_dir/control.temp" ]; then
                temp_file=$(mktemp "$output_dir/control.temp.XXXXXX")
                cp "$output_dir/control.temp" "$temp_file"
                control_temp_flag=true
	    fi
            if [ -e "$output_dir/basis.temp" ]; then
                temp_file=$(mktemp "$output_dir/basis.temp.XXXXXX")
                cp "$output_dir/basis.temp" "$temp_file"
                basis_temp_flag=true
	    fi
            # Get the atoms from the output_dir's geometry.in
            atom_list=($(grep "^atom" "$output_dir/geometry.in" | awk '{print $5}'))
            if [ ${#atom_list[@]} -eq 0 ]; then
                echo "WARNING: \"$output_dir/geometry.in\" exists but contains no atoms. Skipping..." >&2
                continue
            fi
            unique_atom_list=($(printf "%s\n" "${atom_list[@]}" | sort -u))
            sorted_atom_list=($(PT_sort "${unique_atom_list[@]}"))
            # Create a basis for those atoms
            for PT_element in "${sorted_atom_list[@]}" ; do
                filename_pattern=$(eval echo "$basis_dir/*_${PT_element}_*")
                matched_files=($(ls -f $filename_pattern 2>/dev/null))
                if [ ${#matched_files[@]} -ne 1 ]; then
                    echo "WARNING: Expected exactly one matching basis file for element '${PT_element}' in directory '${basis_dir}'. --- Skipping..." >&2
                else
                    cat "${matched_files[0]}" >> "$output_dir/basis.temp"
                fi
            done
            # Remove any current basis in the control.in
            if [ -e "$output_dir/control.in" ]; then
                cp "$output_dir/control.in" "$output_dir/control.old"
                sed '/^#####################/,$d' "$output_dir/control.old" > "$output_dir/control.temp"
            else
                echo "WARNING: \"$output_dir/control.in\" did not exist. The generated control.in will only contain a basis." >&2
                echo "# EMPTY CONTROL.IN CREATED BY BasisConstructor.sh" > "$output_dir/control.temp"
            fi
            # Assemble the new control.in 
            cat "$output_dir/control.temp" "$output_dir/basis.temp" > "$output_dir/control.in"
            # Cleanup Temp Files
            rm "$output_dir/control.temp" "$output_dir/basis.temp"
            if [[ $Delete_old_control_flag == true ]] ; then
                rm "$output_dir/control.old"
            fi
	    # echo -n "."    #Uncomment this line if you want a poor-man's progress bar.
        done
	echo " DONE"
	if [[ $control_old_flag == true ]] ;  then echo "WARNING: Existing \"control.old\" detected. Moved to a temp file. Locate using: find \"$basis_list_elem\" -name \"control.old.*\"" >&2 ; fi
	if [[ $control_temp_flag == true ]] ; then echo "WARNING: Existing \"control.temp\" detected. Moved to a temp file. Locate using: find \"$basis_list_elem\" -name \"control.temp.*\"" >&2 ; fi
	if [[ $basis_temp_flag == true ]] ;   then echo "WARNING: Existing \"basis.temp\" detected. Moved to a temp file. Locate using: find \"$basis_list_elem\" -name \"basis.temp.*\"" >&2 ; fi
    done
}

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# ~~~~~~~~~~ END OF FUNCTION SECTION ~~~~~~~~~~
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~







# Set flags from input arguments. Turn on if both are true
#    1) User has specified the basis in the input arguments
#    2) The basis directory can be detected
Li_flag=false   #Flag to scan for "light/"        directories
In_flag=false   #Flag to scan for "intermediate/" directories
Ti_flag=false   #Flag to scan for "tight/"        directories
Re_flag=false   #Flag to scan for "really_tight/" directories
LD_flag=false   #Flag to scan for "lightdense/"   directories
LDr_flag=false  #Flag to scan for "lightdenser/"  directories
ID_flag=false   #Flag to scan for "intdense/"     directories
RD_flag=false   #Flag to scan for "tightdense/"   directories
Aug2_flag=false #Flag to scan for "Tier2_aug2/"   directories
if [ $# == 0 ]; then
    echo "EXITING... NO BASIS SELECTED." >&2
    echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >&2
    echo "WARNING: Use with care. See code header for instructions           " >&2
    echo "                                                                   " >&2
    echo "  USAGE: 1) $0 <basis> <basis> <basis> ...                         " >&2
    echo "         2) $0 -setall <basis>                                     " >&2
    echo "                                                                   " >&2
    echo " Supported Basis Sets:   Basis          Alias                      " >&2
    echo "                       - light          li                         " >&2
    echo "                       - intermediate   in                         " >&2
    echo "                       - tight          ti                         " >&2
    echo "                       - really_tight   re                         " >&2
    echo "                       - lightdense     ld                         " >&2
    echo "                       - lightdenser    ldr                        " >&2
    echo "                       - intdense       id  # Not yet in FHI-aims  " >&2
    echo "                       - tightdense     td  # Not yet in FHI-aims  " >&2
    echo "                       - Tier2_aug2     aug2                       " >&2
    echo "                                                                   " >&2
    echo " Note: Using <basis> = \"all\" will attempt to set all of the above" >&2
    echo " ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" >&2
    exit 1
else
    # Check for '-setall' flag, and ensure only one basis follows it.
    if [[ "${1,,}" == "-setall" ]] ; then
	Setall_flag=true
	echo "Detected Flag: -setall"
	echo "    This will scan for all geometry.in files and set the basis in their" 
	echo "    respective control.in files to the basis given in the input args.  "
	shift
	if [ $# -ne 1 ] && [ "$1" != "all" ] ; then 
	    echo "ERROR: '-setall' must be followed by exactly one basis type." >&2
            exit 1
	fi
    fi
    # Loop through all basis types
    for basis in "$@" ; do
        basis=$(echo "$basis" | tr '[:upper:]' '[:lower:]')
        case "$basis" in
            "li"|"light")
                if [[ -d "$Li_dir" && "$Li_dir" != "$basis_dir" ]] ; then 
                    Li_flag=true
                    echo "Detected Basis: light"
                else 
                    echo "WARNING: 'light/' basis directory not detected --- Skipping..."  
                fi
                ;;
            "in"|"intermediate")
                if [[ -d "$In_dir" && "$In_dir" != "$basis_dir" ]] ; then 
                    In_flag=true 
                    echo "Detected Basis: intermediate" 
                else 
                    echo "WARNING: 'intermediate/' basis directory not detected --- Skipping..." 
                fi
                ;;
            "ti"|"tight")
                if [[ -d "$Ti_dir" && "$Ti_dir" != "$basis_dir" ]] ; then 
                    Ti_flag=true 
                    echo "Detected Basis: tight" 
                else 
                    echo "WARNING: 'tight/' basis directory not detected --- Skipping..." 
                fi
                ;;
            "re"|"really_tight")
                if [[ -d "$Re_dir" && "$Re_dir" != "$basis_dir" ]] ; then 
		    Re_flag=true 
                    echo "Detected Basis: really_tight" 
                else 
                    echo "WARNING: 'really_tight/' basis directory not detected --- Skipping..." 
                fi
                ;;
            "ld"|"lightdense")
                if [[ -d "$LD_dir" && "$LD_dir" != "$basis_dir" ]] ; 
                    then LD_flag=true 
                    echo "Detected Basis: lightdense" 
                else
                    echo "WARNING: 'lightdense/' basis directory not detected --- Skipping..." 
                fi
                ;;
            "ldr"|"lightdenser")
                if [[ -d "$LDr_dir" && "$LDr_dir" != "$basis_dir" ]] ;
                    then LDr_flag=true
                    echo "Detected Basis: lightdenser"
                else
                    echo "WARNING: 'lightdenser/' basis directory not detected --- Skipping..."
                fi
                ;;
            "id"|"intdense")
                if [[ -d "$ID_dir" && "$ID_dir" != "$basis_dir" ]] ; then 
                    ID_flag=true 
                    echo "Detected Basis: intdense"
                else 
                    echo "WARNING: 'intdense/' basis directory not detected --- Skipping..." 
                fi
                ;;
            "rd"|"tightdense")
                if [[ -d "$TD_dir" && "$TD_dir" != "$basis_dir" ]] ; 
                    then TD_flag=true 
                    echo "Detected Basis: tightdense"
                else 
                    echo "ERROR: 'tightdense/' basis directory not detected --- Skipping..." 
                fi
                ;;
            "aug2"|"tier2_aug2")
                if [[ -d "$Aug2_dir" && "$Aug2_dir" != "$basis_dir" ]] ;
                    then Aug2_flag=true
                    echo "Detected Basis: Tier2_aug2"
                else
                    echo "ERROR: 'Tier2_aug2/' basis directory not detected --- Skipping..."
                fi
                ;;
	    "all")
		if [[ -d "$Li_dir" && "$Li_dir" != "$basis_dir" ]] ; then
                    Li_flag=true
                    echo "Detected Basis: light"
                else
                    echo "WARNING: 'light/' basis directory not detected --- Skipping..."
                fi
		if [[ -d "$In_dir" && "$In_dir" != "$basis_dir" ]] ; then
                    In_flag=true
                    echo "Detected Basis: intermediate"
                else
                    echo "WARNING: 'intermediate/' basis directory not detected --- Skipping..."
                fi
		if [[ -d "$Ti_dir" && "$Ti_dir" != "$basis_dir" ]] ; then
                    Ti_flag=true
                    echo "Detected Basis: tight"
                else
                    echo "WARNING: 'tight/' basis directory not detected --- Skipping..."
                fi
		if [[ -d "$Re_dir" && "$Re_dir" != "$basis_dir" ]] ; then 
		    Re_flag=true
                    echo "Detected Basis: really_tight"
                else
                    echo "WARNING: 'really_tight/' basis directory not detected --- Skipping..."
                fi
		if [[ -d "$LD_dir" && "$LD_dir" != "$basis_dir" ]] ;
                    then LD_flag=true
                    echo "Detected Basis: lightdense"
                else
                    echo "WARNING: 'lightdense/' basis directory not detected --- Skipping..."
                fi
                if [[ -d "$LDr_dir" && "$LDr_dir" != "$basis_dir" ]] ;
                    then LDr_flag=true
                    echo "Detected Basis: lightdenser"
                else
                    echo "WARNING: 'lightdenser/' basis directory not detected --- Skipping..."
                fi
		if [[ -d "$ID_dir" && "$ID_dir" != "$basis_dir" ]] ; then
                    ID_flag=true
                    echo "Detected Basis: intdense"
                else
                    echo "WARNING: 'intdense/' basis directory not detected --- Skipping..."
                fi
		if [[ -d "$TD_dir" && "$TD_dir" != "$basis_dir" ]] ;
                    then TD_flag=true
                    echo "Detected Basis: tightdense"
                else
                    echo "WARNING: 'tightdense/' basis directory not detected --- Skipping..."
                fi
		if [[ -d "$Aug2_dir" && "$Aug2_dir" != "$basis_dir" ]] ;
                    then Aug2_flag=true
                    echo "Detected Basis: Tier2_aug2"
                else
                    echo "WARNING: 'Tier2_aug2/' basis directory not detected --- Skipping..."
                fi
		;;
            *)
                echo "ERROR: $basis is not a supported basis --- Exiting..."
                exit 1
                ;;
        esac
    done
fi

# Scan for Directories, and print them so the user can verify
echo "... Scanning for Directories ..."
echo "------------------------------------------------------"
if [[ ${Setall_flag} == true ]] ; then
    if   [[ ${Li_flag} == true ]] ; then Li_list=($(pwd | tee /dev/tty)) 
    elif [[ ${In_flag} == true ]] ; then In_list=($(pwd | tee /dev/tty))
    elif [[ ${Ti_flag} == true ]] ; then Ti_list=($(pwd | tee /dev/tty))
    elif [[ ${Re_flag} == true ]] ; then Re_list=($(pwd | tee /dev/tty))
    elif [[ ${LD_flag} == true ]] ; then LD_list=($(pwd | tee /dev/tty))
    elif [[ ${LDr_flag} == true ]] ; then LDr_list=($(pwd | tee /dev/tty))
    elif [[ ${ID_flag} == true ]] ; then ID_list=($(pwd | tee /dev/tty))
    elif [[ ${TD_flag} == true ]] ; then TD_list=($(pwd | tee /dev/tty))
    elif [[ ${Aug2_flag} == true ]] ; then Aug2_list=($(pwd | tee /dev/tty))
    fi
else
    if [[ ${Li_flag} == true ]] ; then
        echo "    Light:"
        Li_list=($(find $(pwd) -type d -iname 'li' -o -iname 'light' -o -iname '*_then_light' -o -iname 'defaults_2020_light' 2>/dev/null | tee /dev/tty)) 
    fi
    if [[ ${In_flag} == true ]] ; then
        echo "    Intermediate:"
        In_list=($(find $(pwd) -type d -iname 'in' -o -iname 'intermediate' -o -iname '*_then_intermediate' -o -iname 'defaults_2020_intermediate' 2>/dev/null | tee /dev/tty)) 
    fi
    if [[ ${Ti_flag} == true ]] ; then
        echo "    Tight:"
        Ti_list=($(find $(pwd) -type d -iname 'ti' -o -iname 'tight' -o -iname '*_then_tight' -o -iname 'defaults_2020_tight' 2>/dev/null | tee /dev/tty)) 
    fi
    if [[ ${Re_flag} == true ]] ; then
        echo "    Really_Tight:"
        Re_list=($(find $(pwd) -type d -iname 're' -o -iname 'really_tight' -o -iname '*_then_really_tight' -o -iname 'defaults_2020_really_tight' 2>/dev/null | tee /dev/tty)) 
    fi
    if [[ ${LD_flag} == true ]] ; then
        echo "    LightDense:"
        LD_list=($(find $(pwd) -type d -iname 'ld' -o -iname 'lightdense' -o -iname '*_then_lightdense' -o -iname 'defaults_2020_lightdense' 2>/dev/null | tee /dev/tty)) 
    fi
    if [[ ${LDr_flag} == true ]] ; then
        echo "    LightDenser:"
        LDr_list=($(find $(pwd) -type d -iname 'ldr' -o -iname 'lightdenser' -o -iname '*_then_lightdenser' -o -iname 'defaults_next_lightdenser' 2>/dev/null | tee /dev/tty))
    fi
    if [[ ${ID_flag} == true ]] ; then
        echo "    IntDense:"
        ID_list=($(find $(pwd) -type d -iname 'id' -o -iname 'intdense' -o -iname '*_then_intdense' 2>/dev/null | tee /dev/tty))
    fi
    if [[ ${TD_flag} == true ]] ; then
        echo "    TightDense:"
        TD_list=($(find $(pwd) -type d -iname 'td' -o -iname 'tightdense' -o -iname '*_then_tightdense' 2>/dev/null | tee /dev/tty))  
    fi
    if [[ ${Aug2_flag} == true ]] ; then
        echo "    Tier2_aug2:"
        Aug2_list=($(find $(pwd) -type d -iname 'aug2' -o -iname 'tier2_aug2' -o -iname '*_then_tier2_aug2' -o -iname 'non-standard_tier2_aug2' 2>/dev/null | tee /dev/tty))
    fi
fi
echo "------------------------------------------------------"
echo "Do you want to set the basis for all control.in files"
echo "in the above directories? This cannot be undone."
read -rp "Confirm [y/n]: " Continue_flag # Comment this and set Continue_flag="yes" to be able to (dangerously) run in the background.
if [[ ! "${Continue_flag,,}" =~ ^(y|yes)$ ]] ; then
    echo "Exiting per user request..."
    exit 1
fi

# Loop through the above directories, 
# find subdirectories that contain geometry.in files, 
# then construct a basis for each one.
if [[ ${Li_flag} == true ]] ; then Construct_basis "$Li_dir" "${Li_list[@]}" ; fi
if [[ ${In_flag} == true ]] ; then Construct_basis "$In_dir" "${In_list[@]}" ; fi
if [[ ${Ti_flag} == true ]] ; then Construct_basis "$Ti_dir" "${Ti_list[@]}" ; fi
if [[ ${Re_flag} == true ]] ; then Construct_basis "$Re_dir" "${Re_list[@]}" ; fi
if [[ ${LD_flag} == true ]] ; then Construct_basis "$LD_dir" "${LD_list[@]}" ; fi
if [[ ${LDr_flag} == true ]] ; then Construct_basis "$LDr_dir" "${LDr_list[@]}" ; fi
if [[ ${ID_flag} == true ]] ; then Construct_basis "$ID_dir" "${ID_list[@]}" ; fi
if [[ ${TD_flag} == true ]] ; then Construct_basis "$TD_dir" "${TD_list[@]}" ; fi
if [[ ${Aug2_flag} == true ]] ; then Construct_basis "$Aug2_dir" "${Aug2_list[@]}" ; fi



