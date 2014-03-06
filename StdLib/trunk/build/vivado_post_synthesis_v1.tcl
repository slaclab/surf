
# Post-Synthesis Build Script

# Get variables
set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl

# GUI Related:
# Disable a refresh due to the changes 
# in the Version.vhd file during synthesis 
set_property NEEDS_REFRESH false [get_runs synth_1]

# Target post synthesis script
source ${VIVADO_DIR}/post_synthesis.tcl
