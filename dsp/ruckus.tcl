# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
loadSource -dir "$::DIR_PATH/core"  -fileType "VHDL 2008"
loadSource -dir "$::DIR_PATH/float" -fileType "VHDL 2008"
loadSource -dir "$::DIR_PATH/fixed"

# Load Simulation
loadSource -sim_only -dir "$::DIR_PATH/tb/"
