# CHANGELOG.md
# Kyle Bryenton - 2024-09-15

This version of the FHI-aims code is based on 240507_1, commit 19beda04

Additional manual installations:
- XDMrv3 with updated damping parametrs
- B86bPBE0 functional
- B86bPBE0 damping parameters for XDM
- PBE0 damping parameters for XDM
- Issue 592: Residual Memory in XDM Bugfit
- Issue 599: Inconsistent Ordering of Atoms
- Issue 584: Plan for updated species default organization
- XDMrv4 with basis detection support


This will be the stable version of the FHIaims code for the Johnson Group as of 2024-08-14.
As new features for XDM become available, this version of the code will update as an in-suite experimental
version of these new features before they become available on the developmental branch of FHIaims.

The hope is this will keep all FHIaims data consistent between projects and members in the group, and also
give us access to new features without having to wait for an official stable version of FHIaims.

## Changelog:

- 2024-08-13: Initial Commit
-             Implemented B86bPBE0
-             Added XDM damping functions for B86bPBE0-%
- 2024-08-14: Updated lightdense basis
-             Commented out write(*,*) line in evaluate_density_direct_from_densmat.f90
-             Added XDM damping functions for PBE0-%
- 2024-08-19: Added a warning in XDM if using <5% increments in hybrid_xc_coeff
-             Added files to 00_USEFUL_FILES, including BasisConstructor.sh
- 2024-08-22: Updated 00_USEFUL_FILES/XDM_Fitting_Results_2024-08-22.txt 
-             Added   00_USEFUL_FILES/XDM_Fitting_Results_2024-08-22.pdf
- 2024-09-01: Added more scripts to 00_USEFUL_FILES
-             Added lightdense_{4,8}_{e,v,r} variants to defaults_2020/l_hartree_testing
-             Added libpaths to initial_cache.cmake in 00_USEFUL_FILES
- 2024-09-02: Made xdm_set_damping_coeffs subroutine
-             Added basis handling to xdm damping via lookup tables
-             Added basis keyword support to read_control.f90
- 2024-09-03: Prototype of XDMrv4 completed
-             Damping coefficients added
- 2024-09-05: Support for Lightdenser basis added
-             Updates to BasisConstructor to support Lightdenser
-             XDMrv4 in experimental phase
- 2024-09-06: Fixed bug with cubic fits for B86bPBE0 and PBE0
-             Included fix for "Inconsistent ordering of atoms"
-             Added warning if using the variable_c6 keyword
- 2024-09-07: Edited XDM warnings and cleaned up write statements
-             Attempted fix of XDM residual memory issue, as mentioned in #592
- 2024-09-08: Added Aug2 to BasisConstructor.sh & $HOME fix.
-             Manually merged Issue 592, Residual Memory in XDM
- 2024-09-09: Added XDM citation
- 2024-09-11: Added Aug2 support
-             Implemented the interpolation_a1_a2 function
- 2024-09-14: Formatting changes, preparing for push
-             Bugfix regarding print statements. a1 and a2 are re-fetched on recalc_c6
- 2024-09-15: Bugfix for build.gnu pipeline
-             Removed 00_USEFUL_FILES, moved to FHIaims-Toolbox public repo
-             Deployed to group

