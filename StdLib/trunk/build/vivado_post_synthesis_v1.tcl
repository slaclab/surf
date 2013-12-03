
# Post-Synthesis Build Script

# Get Environment Variables
set VIVADO_DIR     $::env(VIVADO_DIR)

# GUI Related:
# Disable a refresh due to the changes 
# in the Version.vhd file during synthesis 
set_property needs_refresh false [get_runs synth_1]

# Target post synthesis script
source ${VIVADO_DIR}/post_synthesis.tcl
