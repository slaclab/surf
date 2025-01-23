# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib surf -dir "$::DIR_PATH/rtl"

# Load Simulation
loadSource -lib surf -sim_only -dir "$::DIR_PATH/tb"
