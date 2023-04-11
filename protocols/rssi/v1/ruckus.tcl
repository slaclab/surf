# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL_COMBO)

# Load Source Code
loadSource -lib surf -dir "$::DIR_PATH/rtl"

# Load Simulation
loadSource -lib surf -sim_only -dir "$::DIR_PATH/tb"
