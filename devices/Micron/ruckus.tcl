# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load ruckus files
loadRuckusTcl "$::DIR_PATH/n25q"
loadRuckusTcl "$::DIR_PATH/p30"
loadRuckusTcl "$::DIR_PATH/ddr3"
