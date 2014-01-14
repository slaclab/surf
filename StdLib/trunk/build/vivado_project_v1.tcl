
# Project Batch-Mode Build Script

# Get variables
source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl

# Load Custom Procedures
source -quiet ${VIVADO_BUILD_DIR}/vivado_proc_v1.tcl

# Create a Project
create_project ${VIVADO_PROJECT} -force ${OUT_DIR} -part ${PRJ_PART}

# Add RTL Source Files
add_files -fileset sources_1 ${RTL_FILES}

# Add Simulation Source Files
if { ${SIM_FILES} != "" } {

   # add the simulation files
   add_files -fileset sim_1 ${SIM_FILES}
   
}

# Add Core Files
if { ${CORE_FILES} != "" } {

   # add the IP Cores
   add_files -fileset sources_1 ${CORE_FILES}

   # Force Absolute Path (not relative to project)
   set_property PATH_MODE AbsoluteFirst [get_files ${CORE_FILES}]
   
}

# Add XDC FILES
if { ${XDC_FILES} != "" } {
   
   set index 1
   foreach xdcPntr ${XDC_FILES} {
      add_files -fileset constrs_${index} ${xdcPntr}
      
      # Set the out_of_context .XDC files
      # NOTE: I need to write this "if statement" to check for project .xdc file instead of the index pointer (LLR - 14JAN2014)
      if { ${index} != 1 } {
         set_property USED_IN {synthesis implementation out_of_context} [get_files ${xdcPntr}]
      }
      
      set_property PATH_MODE AbsoluteFirst [get_files ${xdcPntr}]
      incr index
      create_fileset -constrset constrs_${index}
   }
   delete_fileset constrs_${index}
   
}   

# Set the Top Level 
set_property top ${PROJECT} [current_fileset]

# Set VHDL as preferred language
set_property target_language VHDL [current_project]

# Disable Xilinx's WebTalk
config_webtalk -user off

# Message Filtering Script
source -quiet ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl

# Enable implementation steps by default
set_property STEPS.POWER_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.POST_PLACE_POWER_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1] 

# Setup pre and post scripts for synthesis
set_property STEPS.SYNTH_DESIGN.TCL.PRE  ${VIVADO_BUILD_DIR}/vivado_pre_synthesis_v1.tcl [get_runs synth_1]

# Setup pre and post scripts for implementation
set_property STEPS.OPT_DESIGN.TCL.PRE                  ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl [get_runs impl_1]
set_property STEPS.POWER_OPT_DESIGN.TCL.PRE            ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl [get_runs impl_1]
set_property STEPS.PLACE_DESIGN.TCL.PRE                ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl [get_runs impl_1]
set_property STEPS.POST_PLACE_POWER_OPT_DESIGN.TCL.PRE ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.TCL.PRE             ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl [get_runs impl_1]
set_property STEPS.ROUTE_DESIGN.TCL.PRE                ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl [get_runs impl_1]
set_property STEPS.WRITE_BITSTREAM.TCL.PRE             ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl [get_runs impl_1]

# Generate all IP cores' output files
generate_target all [get_ips]
if { [get_ips] != "" } {
   foreach corePntr [get_ips] {
   
      # Build the IP Core
      puts "\nBuilding ${corePntr}.xci IP Core ..."
      synth_ip -quiet [get_ips ${corePntr}]
      puts "... Build Complete!\n"
      
      # Disable the IP Core's XDC (so it doesn't get implemented at the project level)
      set xdcPntr [get_files -of_objects [get_files ${corePntr}.xci] -filter {FILE_TYPE == XDC}]
      set_property is_enabled false [get_files ${xdcPntr}]
      
   }
}

# Target specific project setup script
source ${VIVADO_DIR}/project_setup.tcl

# Close the project
close_project
