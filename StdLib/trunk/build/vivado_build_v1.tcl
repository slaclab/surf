
## Project Batch-Mode Run Script

########################################################
## Get variables
########################################################
set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl

########################################################
## Open the project
########################################################
open_project -quiet ${VIVADO_PROJECT}

# Setup project properties
source ${VIVADO_BUILD_DIR}/vivado_properties_v1.tcl

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
   launch_run  synth_1
   wait_on_run synth_1
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
## Implement
########################################################
if { [CheckImpl] != true } {
   launch_run -to_step write_bitstream impl_1
   wait_on_run impl_1
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
## Close the project and return sucessful flag
########################################################

close_project
exit 0
