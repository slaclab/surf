
# Project Batch-Mode Run Script (Partial Reconfiguration: Dynamic)

# Get variables
set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl

# Load Custom Procedures
source -quiet ${VIVADO_BUILD_DIR}/vivado_proc_v1.tcl

# Check for a blank RECONFIG_NAME variable
if { [CheckForReconfigCheckPoint] != true } {
   exit -1
}

# Open the project
open_project -quiet ${VIVADO_PROJECT}

# Clean up runs
reset_run synth_1
reset_run impl_1

# Prevents I/O insertion for synthesis and downstream tools
# Note:  To synthesis in GUI (debuggin only, this property 
#        should also be set in the project's vivado/project_setup.tcl file
set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects [get_runs synth_1]

# Synthesize
launch_run  synth_1
wait_on_run synth_1

# Target post synthesis script
source ${VIVADO_BUILD_DIR}/vivado_post_synthesis_v1.tcl

# Check that the Synthesize is completed
if { [get_property PROGRESS [get_runs synth_1]]!="100\%" || \
     [get_property STATUS [get_runs synth_1]]!="synth_design Complete!" } {
   close_project
   exit -1
}

# Import static checkpoint
ImportStaticReconfigDcp

# Implement
launch_run -to_step write_bitstream impl_1
wait_on_run impl_1

# Target post route script
source ${VIVADO_BUILD_DIR}/vivado_post_route_v1.tcl

# Check that the Implement is completed
if { [get_property PROGRESS [get_runs impl_1]]!="100\%" || \
     [get_property STATUS [get_runs impl_1]]!="write_bitstream Complete!" } {
   close_project
   exit -1
}

# Check if there were timing or routing errors during implement
if { [CheckTiming] != true } {
   close_project
   exit -1
}

# Export partial configuration bit file
ExportPartialReconfigBit

# Close the project
close_project
exit 0
