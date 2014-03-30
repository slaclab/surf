
## Project Batch-Mode Run Script (Partial Reconfiguration: Dynamic)

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
## Check for a blank RECONFIG_NAME variable
########################################################
if { [CheckForReconfigCheckPoint] != true } {
   exit -1
}

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
## Prevents I/O insertion for synthesis and downstream tools
## Note:  To synthesis in GUI (debuggin only, this property 
##        should also be set in the project's vivado/project_setup.tcl file
########################################################
set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects [get_runs synth_1]

########################################################
## Check if we re-synthesis any of the IP cores
########################################################
if { [get_ips] != "" } {
   foreach corePntr [get_ips] {
      set ipSynthRun ${corePntr}_synth_1
      if { [CheckIpSynth ${ipSynthRun}] != true } {      
         # Build the IP Core
         reset_run         ${ipSynthRun}
         launch_run -quiet ${ipSynthRun}
         wait_on_run       ${ipSynthRun}
         
         # Disable the IP Core's XDC (so it doesn't get implemented at the project level)
         set xdcPntr [get_files -of_objects [get_files ${corePntr}.xci] -filter {FILE_TYPE == XDC}]
         set_property is_enabled false [get_files ${xdcPntr}]   
      }      
   }
}

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
close_project
open_project -quiet ${VIVADO_PROJECT}

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
## Import static checkpoint
########################################################
ImportStaticReconfigDcp

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
## Export partial configuration bit file
########################################################
ExportPartialReconfigBit

########################################################
## Close the project and return sucessful flag
########################################################
close_project
exit 0
