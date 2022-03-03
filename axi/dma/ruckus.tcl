# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado/proc.tcl

# Load Source Code
loadSource -lib surf -dir "$::DIR_PATH/rtl"
loadSource -lib surf -dir "$::DIR_PATH/rtl/v1"
loadSource -lib surf -dir "$::DIR_PATH/rtl/v2"

# Load Simulation
loadSource -lib surf -sim_only -dir "$::DIR_PATH/tb"
