
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
compile_simlib -simulator vcs_mx -library unisim -library simprim -library axi_bfm -directory ${OUT_DIR}/vcs_library

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
########################################################

# Save the current top level simulation testbed value
set orginalTop [get_property top [get_filesets sim_1]]

# Create a VCS script with each testbed
foreach SimTbPntr [get_files *Tb.vhd] {
   set simTbFileName [string trimright [file tail ${SimTbPntr}] {.vhd}]
   set_property top ${simTbFileName} [get_filesets sim_1]
   set_property top_lib xil_defaultlib [get_filesets sim_1]
   update_compile_order -fileset sim_1   
   if { [export_simulation -force -simulator vcs_mx -lib_map_path ${OUT_DIR}/vcs_library/ -directory ${OUT_DIR}/vcs_scripts/${simTbFileName}/] != 0 } {
      puts "export_simulation ERROR: ${newTop}"
      exit -1
   }   
}

# Reset the top level simulation testbed for GUI
set_property top {${orginalTop}} [get_filesets sim_1]

########################################################
## Close the project
########################################################
close_project
exit 0