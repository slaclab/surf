##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

# Project Properties Script

########################################################
## Get variables and Custom Procedures
########################################################
set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl
source -quiet ${VIVADO_BUILD_DIR}/vivado_proc_v1.tcl

# Set VHDL as preferred language
set_property target_language VHDL [current_project]

# Disable Xilinx's WebTalk
config_webtalk -user off

# Default to no flattening of the hierarchy
set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY none [get_runs synth_1]

# Close and reopen project to force the physical path of ${VIVADO_BUILD_DIR} (bug in Vivado 2014.1)
VivadoRefresh ${VIVADO_PROJECT}

# Setup pre and post scripts for synthesis
set_property STEPS.SYNTH_DESIGN.TCL.PRE  ${VIVADO_BUILD_DIR}/vivado_pre_synth_run_v1.tcl [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.TCL.POST ${VIVADO_BUILD_DIR}/vivado_post_synth_run_v1.tcl [get_runs synth_1]

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
set_property simulator_language Mixed [current_project]
set_property nl.process_corner slow   [get_filesets sim_1]
set_property nl.sdf_anno true         [get_filesets sim_1]
set_property SOURCE_SET sources_1     [get_filesets sim_1]

if { ${VIVADO_VERSION} <= 2014.2 } {
   set_property runtime {}             [get_filesets sim_1]
   set_property xelab.debug_level all  [get_filesets sim_1]
   set_property xelab.mt_level auto    [get_filesets sim_1]
   set_property xelab.sdf_delay sdfmin [get_filesets sim_1]
   set_property xelab.rangecheck false [get_filesets sim_1]
   set_property xelab.unifast false    [get_filesets sim_1]
} else {
   set_property xsim.simulate.runtime {}  [get_filesets sim_1]
   set_property xsim.debug_level all      [get_filesets sim_1]
   set_property xsim.mt_level auto        [get_filesets sim_1]
   set_property xsim.sdf_delay sdfmin     [get_filesets sim_1]
   set_property xsim.rangecheck false     [get_filesets sim_1]
   set_property xsim.unifast false        [get_filesets sim_1]
}   

# Refer to http://www.xilinx.com/support/answers/65415.html
if { ${VIVADO_VERSION} >=  2016.1 } {
   set_property STEPS.SYNTH_DESIGN.ARGS.ASSERT true [get_runs synth_1]
}
   
# Prevent Vivado from doing power optimization (which can optimize out register chains)
set_property STEPS.POWER_OPT_DESIGN.IS_ENABLED false [get_runs impl_1]
set_property STEPS.POST_PLACE_POWER_OPT_DESIGN.IS_ENABLED false [get_runs impl_1]
set_property STEPS.OPT_DESIGN.ARGS.DIRECTIVE NoBramPowerOpt [get_runs impl_1]

# Enable physical optimization for register replication
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]

# Target specific properties script
SourceTclFile ${VIVADO_DIR}/properties.tcl
