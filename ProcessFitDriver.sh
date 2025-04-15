#!/bin/bash

# ProcessFitDriver.sh
# Kyle Bryenton - 2025-04-15


# Set these flags as desired.
print_param=true
print_fhiaims=true
print_tex=true
print_xdmsetter=false

if [ $# == 0 ]; then
    echo "ERROR: No result files selected. Exiting.     " >&2
    echo "USAGE: 1) $0 kb49.results kb49_BJ0.results ..." >&2
    echo "       2) $0 *.results                        " >&2
    exit 1
fi

# First we want to create something that's easy to copy and paste into latex. The lines after 'cat' will:
# - Only keep lines containing "## FIT for:", "a1 =", "Dataset", "MAD", or "MAPD"
# - For the path line from "FIT for", only keep last two subdirectories (hopefully basis and functional)
# - Remove all the newlines
# - Add a newline back in before each basis, so now we have one row per system
# - Remove all other unnecessary info that was grepped, replacing with spaces
# - Add a header to the table
# - Format columns to get pre-defined spacing, aligning them
for res in "$@" ; do
    cat $res \
        | grep -E '(## FIT for:|a1 =|Dataset|MAD|MAPD)' \
        | awk -F'/' '{if (NF > 1) print "# "$(NF-1)" "$NF; else print}' \
        | tr -d "\n" \
        | sed "s/\# /\n/g" \
        | sed -E "s/(a1 =|\|\| a2\(ang\) =|Dataset size =|MAD    =|MAPD   =)/ /g" \
        | awk '{printf "%-32s %-14s %-12s %-12s %-7s %-7s %-5s\n", $1, $2, $3, $4, $6, $7, $5}' \
        > ${res%.*}.pfd_temp # Process Fit Driver Temp
done
# If multiple result files were provided, combine, and remove any that have negative values for a1
# This will effectively merge datasets between BJ damping, and BJ0 damping. 
cat *.pfd_temp \
    | sort --version-sort \
    | awk '($3 >= 0 && $4 >= 0)' \
    | sed '1i\Basis                            Functional     a1           a2(ang)      MAD     MAPD    nset' \
    | sed '/^[[:space:]]*$/d' \
    > ${res%.*}.dat 
    # This .dat will contain all data needed for other "print_format" flags specified in the header. 
rm *.pfd_temp


# The .param format. 
# Format type: Markup 
# So it can be pasted into Erin/Alberto's websites
if [ $print_param == true ] ; then
    cat ${res%.*}.dat \
        | awk '{printf "%-32s %-14s %-12s %-12s %-7s %-5s\n", $1, $2, $3, $4, $6, $7}' \
        | sed '1d' \
        | awk 'BEGIN {basis = ""} {
            if ($1 != basis) { 
                if (basis != "") print "" ;
                basis = $1 ;
                print "# " basis ;
                print "Functional     a1           a2(ang)      MAPD    nset" ;
            }
            print substr($0, index($0, $2)) 
        }' \
        > ${res%.*}.param
fi

# The .fhiaims format. 
# Format type: Fortran
# So it can be pasted into FHIaims's xdm.f90 xdm_set_damping_coeffs() subroutine for XDMrv4
if [ $print_fhiaims == true ] ; then
    cat ${res%.*}.dat \
        | awk '{printf "\"%s\" \"%s\" %sd0 %sd0 \n", $1, $2, $3, $4}' \
        | awk '{printf "bj_entry(%-32s, %-16s, %-14s, %-14s), &\n", $1, $2, $3, $4}' \
        | sed '1d' \
        > ${res%.*}.fhiaims
fi

# The .tex format.
# Format type: TeX
# So it can be pasted into Overleaf to save XDM damping coefficients
if [ $print_tex == true ] ; then
    cat << EOF > ${res%.*}.tex
\\begin{table}[h!]
{\\footnotesize
\\centering
\\caption{Optimal XDM parameters (\$a_1\$ and \$a_2\$) for selected functionals, with exact-exchange mixing 
    fractions (\$a_\\text{X}\$) indicated. The mean absolute errors (MAE, in kcal/mol) and mean absolute 
    percent errors (MAPE) for the KB49 fit set are also shown. All numbers are for new parameters. \\\\}
\\begin{tabular}{lccrr}
\\hline
Functional     & a1           & a2(ang)      & MAD     & MAPD \\\\
EOF
    cat ${res%.*}.dat \
        | awk -F ' ' '{printf "%s & %-14s & %-12s & %-12s & %-7s & %-7s \\\\ \n", $1, $2, $3, $4, $5, $6}' \
        | sed '1d' \
        | awk -F ' & ' 'BEGIN {basis = ""} {
            if ($1 != basis) {
                basis = $1 ;
                print "\\hline \\multicolumn{5}{c}{"basis" basis set} \\\\ \\hline";
            }
            print substr($0, index($0, $2))
        }' \
        >> ${res%.*}.tex
    cat << EOF >> ${res%.*}.tex
\\hline
\\end{tabular}\\\\
\${}^a\$The \$a_X\$ value is the range-separation parameter (\$\\omega\$) instead of the exact-exchange fraction.\\\\
\${}^b\$The optimal \$a_1\$ value was negative, so it was set to zero during the parametrization.\\\\
}
\\end{table}
EOF
fi

# The .xdmsetter format
# Format type: Bash
# So it can be used in conjunction with the XDM_a1a2_Setter.sh script
if [ $print_xdmsetter == true ] ; then 
    cat ${res%.*}.dat \
        | awk '{printf "%s %s %s %s %s \n", "XDM_a1a2_Setter.sh", $1, $2, $3, $4}' \
        | sed '1d' \
        > ${res%.*}.xdmsetter
fi
