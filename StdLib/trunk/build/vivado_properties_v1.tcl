
# Project Properties Script

# Set VHDL as preferred language
set_property target_language VHDL [current_project]

# Disable Xilinx's WebTalk
config_webtalk -user off

# Enable implementation steps by default
set_property STEPS.POWER_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.POST_PLACE_POWER_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]

# Close and reopen project to force the physical path of ${VIVADO_BUILD_DIR} (bug in Vivado 2014.1)
close_project
open_project -quiet ${VIVADO_PROJECT} 

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

# Set the messaging limit
set_param messaging.defaultLimit 10000

# Vivado simulation properties
set_property runtime {} [get_filesets sim_1]
set_property nl.process_corner slow [get_filesets sim_1]
set_property nl.sdf_anno true [get_filesets sim_1]
set_property SOURCE_SET sources_1 [get_filesets sim_1]
set_property xelab.debug_level typical [get_filesets sim_1]
set_property xelab.mt_level auto [get_filesets sim_1]
set_property xelab.sdf_delay sdfmin [get_filesets sim_1]
set_property xelab.rangecheck false [get_filesets sim_1]
set_property xelab.unifast false [get_filesets sim_1]
set_property simulator_language Mixed [current_project]
