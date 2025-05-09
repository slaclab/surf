# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib surf -dir "$::DIR_PATH/core"  -fileType "VHDL 2008"
loadSource -lib surf -dir "$::DIR_PATH/fixed" -fileType "VHDL 2008"

# Load Simulation
loadSource -lib surf -sim_only -dir "$::DIR_PATH/tb" -fileType "VHDL 2008"
