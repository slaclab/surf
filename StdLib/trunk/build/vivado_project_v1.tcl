
# Get Environment Variables
set XDC_FILES        $::env(XDC_FILES)
set RTL_FILES        $::env(RTL_FILES)
set CORE_FILES       $::env(CORE_FILES)
set PRJ_PART         $::env(PRJ_PART)
set PROJECT          $::env(PROJECT)
set OUT_DIR          $::env(OUT_DIR)
set VIVADO_DIR       $::env(VIVADO_DIR)
set VIVADO_PROJECT   $::env(VIVADO_PROJECT)
set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)

# Create a project
create_project -quiet ${VIVADO_PROJECT} -force ${OUT_DIR} -part ${PRJ_PART}

# Add source Files
add_files -quiet -fileset sources_1 ${RTL_FILES}

# Add core Files
if { ${CORE_FILES} != " " } {
   add_files -quiet -fileset sources_1 ${CORE_FILES}
}

# Add XDC FILES
add_files -quiet -fileset constrs_1 ${XDC_FILES}

# Set the top level
set_property top ${PROJECT} [current_fileset]

# Message Filtering Script
source ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl

# Enable implementation steps by default
set_property STEPS.POWER_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.POST_PLACE_POWER_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1] 

# Setup pre and post scripts for synthesis
set_property STEPS.SYNTH_DESIGN.TCL.PRE  ${VIVADO_BUILD_DIR}/vivado_timestamp_v1.tcl [get_runs synth_1]

# Setup pre and post scripts for implementation
set_property STEPS.OPT_DESIGN.TCL.PRE                  ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl [get_runs impl_1]
set_property STEPS.POWER_OPT_DESIGN.TCL.PRE            ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl [get_runs impl_1]
set_property STEPS.PLACE_DESIGN.TCL.PRE                ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl [get_runs impl_1]
set_property STEPS.POST_PLACE_POWER_OPT_DESIGN.TCL.PRE ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.TCL.PRE             ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl [get_runs impl_1]
set_property STEPS.ROUTE_DESIGN.TCL.PRE                ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl [get_runs impl_1]
set_property STEPS.WRITE_BITSTREAM.TCL.PRE             ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl [get_runs impl_1]

# Target specific project setup script
source ${VIVADO_DIR}/project_setup.tcl

# Close the project
close_project
