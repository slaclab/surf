##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

## Project Batch-Mode Run Script (Partial Reconfiguration: Static)

########################################################
## Get variables and Custom Procedures
########################################################
set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl
source -quiet ${VIVADO_BUILD_DIR}/vivado_proc_v1.tcl

########################################################
## Check for a blank RECONFIG_NAME variable
########################################################
if { [CheckForReconfigName] != true } {
   exit -1
}

########################################################
## Open the project
########################################################
open_project -quiet ${VIVADO_PROJECT}

# Setup project properties
source -quiet ${VIVADO_BUILD_DIR}/vivado_properties_v1.tcl

# Setup project messaging
source -quiet ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl

########################################################
## Update the complie order
########################################################
update_compile_order -quiet -fileset sources_1
update_compile_order -quiet -fileset sim_1

########################################################
## Check if we need to clean up or stop the implement
########################################################
if { [CheckImpl] != true } {
   reset_run impl_1
}

########################################################
## Check if we need to clean up or stop the synthesis
########################################################
if { [CheckSynth] != true } {
   reset_run synth_1
}

########################################################
## Disable all the Partial Reconfiguration RTL Block(s) and 
## their XDC files before launching the top level synthesis run
########################################################
set RECONFIG_NAME $::env(RECONFIG_NAME)
foreach rtlPntr ${RECONFIG_NAME} {
   set_property is_enabled false [get_files ${rtlPntr}.vhd]
   set_property is_enabled false [get_files ${rtlPntr}.xdc]
}

########################################################
## Check if we re-synthesis any of the IP cores
########################################################
BuildIpCores

########################################################
## Target Pre synthesis script
########################################################
source ${VIVADO_BUILD_DIR}/vivado_pre_synthesis_v1.tcl

########################################################
## Synthesize
########################################################
if { [CheckSynth] != true } {
   launch_runs synth_1
   set src_rc [catch { 
      wait_on_run synth_1 
   } _RESULT]  
}

########################################################
## Force a refresh of project by close then open project
########################################################
VivadoRefresh ${VIVADO_PROJECT}

########################################################
## Target post synthesis script
########################################################
source ${VIVADO_BUILD_DIR}/vivado_post_synthesis_v1.tcl

########################################################
## Check that the Synthesize is completed
########################################################
if { [CheckSynth] != true } {
   close_project
   exit -1
}

########################################################
## Insert the Partial Reconfiguration RTL Block(s) 
## into top level checkpoint checkpoint
########################################################
InsertStaticReconfigDcp

########################################################
## Implement
########################################################
if { [CheckImpl] != true } {
   launch_runs -to_step write_bitstream impl_1
   set src_rc [catch { 
      wait_on_run impl_1 
   } _RESULT]     
}

########################################################
## Target post route script
########################################################
source ${VIVADO_BUILD_DIR}/vivado_post_route_v1.tcl

########################################################
## Check that the Implement is completed
########################################################
if { [CheckImpl] != true } {
   close_project
   exit -1
}

########################################################
## Check if there were timing 
## or routing errors during implement
########################################################
if { [CheckTiming] != true } {
   close_project
   exit -1
}

########################################################
## Export static checkpoint
########################################################
ExportStaticReconfigDcp

########################################################
## Close the project and return sucessful flag
########################################################
close_project
exit 0
