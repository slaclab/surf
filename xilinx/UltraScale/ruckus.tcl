# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load the Core
loadRuckusTcl "$::DIR_PATH/general"
loadRuckusTcl "$::DIR_PATH/gthUs"
loadSource -lib surf -dir "$::DIR_PATH/pkg"
