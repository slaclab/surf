# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL_QUIET)

# Load Source Code
loadSource -lib surf -dir "$::DIR_PATH/rtl"
loadSource -lib surf -dir "$::DIR_PATH/rtl/7Series"
loadSource -lib surf -dir "$::DIR_PATH/rtl/UltraScale"

# Load Simulation
loadSource -lib surf -sim_only -dir "$::DIR_PATH/tb"
