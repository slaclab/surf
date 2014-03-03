
# Sources Batch-Mode Build Script

# Get variables
set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl

# Load Custom Procedures
source -quiet ${VIVADO_BUILD_DIR}/vivado_proc_v1.tcl

# Open the project
open_project -quiet ${VIVADO_PROJECT}

# Add RTL Source Files
foreach rtlPntr ${RTL_FILES} {
   # Add the RTL Files
   add_files -quiet -fileset sources_1 ${rtlPntr}
   # Force Absolute Path (not relative to project)
   set_property PATH_MODE AbsoluteFirst [get_files ${rtlPntr}]
}

# Add Simulation Source Files
if { ${SIM_FILES} != "" } {
   foreach simPntr ${SIM_FILES} {
      # Add the Simulation Files
      add_files -quiet -fileset sim_1 ${simPntr} 
      # Force Absolute Path (not relative to project)
      set_property PATH_MODE AbsoluteFirst [get_files ${simPntr}]
   }
}

# Add Core Files
if { ${CORE_FILES} != "" } {
   foreach corePntr ${CORE_FILES} {
      import_ip -quiet -srcset sources_1 ${corePntr}
   }
}

# Add XDC FILES
if { ${XDC_FILES} != "" } {
   foreach xdcPntr ${XDC_FILES} {
      # Add the Constraint Files
      add_files -quiet -fileset constrs_1 ${xdcPntr}
      # Force Absolute Path (not relative to project)
      set_property PATH_MODE AbsoluteFirst [get_files ${xdcPntr}]
   }   
}   

# Set the Top Level 
set_property top ${PROJECT} [current_fileset]

close_project
open_project -quiet ${VIVADO_PROJECT}

# Generate all IP cores' output files
generate_target all [get_ips]
if { [get_ips] != "" } {
   foreach corePntr [get_ips] {

      # Build the IP Core
      puts "\nUpgrading ${corePntr}.xci IP Core ..."
      upgrade_ip [get_ips ${corePntr}]
      puts "... Upgrade Complete!\n"

      # Build the IP Core
      puts "\nBuilding ${corePntr}.xci IP Core ..."
      synth_ip [get_ips ${corePntr}]
      puts "... Build Complete!\n"
      
      # Disable the IP Core's XDC (so it doesn't get implemented at the project level)
      set xdcPntr [get_files -of_objects [get_files ${corePntr}.xci] -filter {FILE_TYPE == XDC}]
      set_property is_enabled false [get_files ${xdcPntr}]
      
   }
}

# Touch dependency file
exec touch ${PROJECT}_sources.txt

# Close the project
close_project
