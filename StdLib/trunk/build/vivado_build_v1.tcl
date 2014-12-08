
## Project Batch-Mode Run Script

########################################################
## Get variables and Custom Procedures
########################################################
set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl
source -quiet ${VIVADO_BUILD_DIR}/vivado_proc_v1.tcl

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
   ## Check for DCP only synthesis run
   if { [info exists ::env(SYNTH_DCP)] } {
      set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects [get_runs synth_1]
   }
   ## Launch the run
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
## Check if only doing Synthesize
########################################################
if { [info exists ::env(SYNTH_ONLY)] } {
   close_project
   exit 0
}

########################################################
## Check if Synthesizen DCP Output
########################################################
if { [info exists ::env(SYNTH_DCP)] } {
   source ${VIVADO_BUILD_DIR}/vivado_dcp_v1.tcl
   close_project
   exit 0
}

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
## Close the project and return sucessful flag
########################################################

close_project
exit 0
