# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
loadSource -dir  "$::DIR_PATH/rtl"
# loadIpCore -path "$::DIR_PATH/coregen/Salt7SeriesCore.xci"
loadSource -path "$::DIR_PATH/coregen/Salt7SeriesCore.dcp"

# Load Simulation
loadSource -sim_only -dir "$::DIR_PATH/tb/"