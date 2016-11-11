# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
loadSource -dir  "$::DIR_PATH/rtl"
# loadIpCore -path "$::DIR_PATH/coregen/SaltUltraScaleCore.xci"
loadSource -path "$::DIR_PATH/coregen/SaltUltraScaleCore.dcp"
loadSource -path "$::DIR_PATH/coregen/SaltUltraScaleRxOnly.dcp"

# Load Simulation
loadSource -sim_only -dir "$::DIR_PATH/tb/"