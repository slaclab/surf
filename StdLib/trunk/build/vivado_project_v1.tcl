
# Project Batch-Mode Build Script

# Get variables
set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl

# Load Custom Procedures
source -quiet ${VIVADO_BUILD_DIR}/vivado_proc_v1.tcl

# Create a Project
create_project ${VIVADO_PROJECT} -force ${OUT_DIR} -part ${PRJ_PART}

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

# Target specific project setup script
source ${VIVADO_DIR}/project_setup.tcl

# Close the project
close_project
