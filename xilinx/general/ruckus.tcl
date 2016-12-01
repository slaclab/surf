# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load the Core
loadRuckusTcl "$::DIR_PATH/microblaze"

# Load Source Code
loadSource -dir "$::DIR_PATH/rtl/"
