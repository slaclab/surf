# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load ruckus files
loadRuckusTcl "$::DIR_PATH/ddr3"
loadRuckusTcl "$::DIR_PATH/ddr4"
loadRuckusTcl "$::DIR_PATH/mt28ew"
loadRuckusTcl "$::DIR_PATH/n25q"
loadRuckusTcl "$::DIR_PATH/p30"
