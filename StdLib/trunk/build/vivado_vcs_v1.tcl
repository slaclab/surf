
# Vivado VCS Build Script

## Note: 
##    VCS must be version H-2013.06-3 (or newer)
##    based on 2013.3 release notes

########################################################
## Get variables
########################################################
set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl

########################################################
## Load Custom Procedures
########################################################
source -quiet ${VIVADO_BUILD_DIR}/vivado_proc_v1.tcl

########################################################
## Open the project
########################################################
open_project -quiet ${VIVADO_PROJECT}

########################################################
## Check if we re-synthesis any of the IP cores
########################################################
BuildIpCores

########################################################
## Compile the libraries for VCS
########################################################
set simLibOutDir ${OUT_DIR}/vcs_library
compile_simlib -simulator vcs_mx -library unisim -library simprim -library axi_bfm -directory ${simLibOutDir}

########################################################
## Enable the LIBRARY_SCAN parameter 
## in the synopsys_sim.setup file
########################################################

set LIBRARY_SCAN_OLD "LIBRARY_SCAN                    = FALSE"
set LIBRARY_SCAN_NEW "LIBRARY_SCAN                    = TRUE"

# open the files
set in  [open ${OUT_DIR}/vcs_library/synopsys_sim.setup r]
set out [open ${OUT_DIR}/vcs_library/synopsys_sim.temp  w]

# Find and replace the LIBRARY_SCAN parameter
while { [eof ${in}] != 1 } {
   gets ${in} line
   if { ${line} == ${LIBRARY_SCAN_OLD} } {
      puts ${out} ${LIBRARY_SCAN_NEW}
   } else { 
      puts ${out} ${line} 
   }
}

# Close the files
close ${in}
close ${out}

# over-write the existing file
file rename -force ${OUT_DIR}/vcs_library/synopsys_sim.temp ${OUT_DIR}/vcs_library/synopsys_sim.setup

########################################################
## Generate the VCS simulation scripts for each testbed
## Note:
##    This script will automatically build the top level
##    simulation script.  Make sure to set your desired
##    testbed as top level either in GUI interface or 
##    the target's project_setup.tcl script
##
## Example:: project_setup.tcl script:
##    set_property top {HeartbeatTb} [get_filesets sim_1]
########################################################

# Save the current top level simulation testbed value
set simTbFileName [get_property top [get_filesets sim_1]]
set simTbOutDir ${OUT_DIR}/vcs_scripts/${simTbFileName}

if { [export_simulation -force -simulator vcs_mx -lib_map_path ${simLibOutDir} -directory ${simTbOutDir}/] != 0 } {
   puts "export_simulation ERROR: ${newTop}"
   exit -1
} 

########################################################
## Check for a simlink directory 
########################################################
set simTbDirName [file dirname [get_files ${simTbFileName}.vhd]]
set simLinkDir   ${simTbDirName}/../simlink/
if { [file isdirectory ${simLinkDir}] == 1 } {

   # Create the setup environment script
   set envScript [open ${simTbOutDir}/setup_env.csh  w]
   puts  ${envScript} "limit stacksize 60000"
   set LD_LIBRARY_PATH "setenv LD_LIBRARY_PATH ${simTbOutDir}:$::env(LD_LIBRARY_PATH)"
   puts  ${envScript} ${LD_LIBRARY_PATH} 
   close ${envScript}
   
   # Compile the C code
   #
   # Note: DSHM_ID and DSHM_NAME are defined in the .h header, not the makefile
   #
   set objectList ""
   foreach simLinkSrcPntr [glob -directory ${simLinkDir} *.c] {
      set simLinkSrcName  [string trimright [string trimright [file tail ${simLinkSrcPntr}] "c"] "."]
      exec gcc -Wall -c -fPIC -o ${simTbOutDir}/${simLinkSrcName}.o -I$::env(VCS_HOME)/include/ ${simLinkDir}/${simLinkSrcName}.c
      append objectList ${simTbOutDir}/${simLinkSrcName}.o " "
   }
   exec gcc -Wall -shared -o ${simTbOutDir}/libSimSw_lib.so ${objectList}   
}

########################################################
## Close the project
########################################################
close_project

exit 0