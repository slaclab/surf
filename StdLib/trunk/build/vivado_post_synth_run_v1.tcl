
# Post-Synthesis Run Script

########################################################
## Get variables and Custom Procedures
########################################################
set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl
source -quiet ${VIVADO_BUILD_DIR}/vivado_proc_v1.tcl

# GUI Related:
# Disable a refresh due to the changes 
# in the Version.vhd file during synthesis 
set_property NEEDS_REFRESH false [current_run]

# Target specific post_synthesis script
SourceTclFile ${VIVADO_DIR}/post_synth_run.tcl