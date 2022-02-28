# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado/proc.tcl

# Load the Core
loadRuckusTcl "$::DIR_PATH/microblaze"

# Load Source Code
loadSource -lib surf -dir "$::DIR_PATH/rtl"

# Load Simulation
loadSource -lib surf -sim_only -dir "$::DIR_PATH/tb"
