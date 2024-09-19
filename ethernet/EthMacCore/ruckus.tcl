# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib surf -dir "$::DIR_PATH/rtl"
loadRuckusTcl "$::DIR_PATH/RoCEv2"

# Load Simulation
loadSource -lib surf -sim_only -dir "$::DIR_PATH/tb"
