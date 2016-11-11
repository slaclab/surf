# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load ruckus files
loadRuckusTcl "$::DIR_PATH/axi"
loadRuckusTcl "$::DIR_PATH/base"
loadRuckusTcl "$::DIR_PATH/devices"
loadRuckusTcl "$::DIR_PATH/ethernet"
loadRuckusTcl "$::DIR_PATH/protocols"
loadRuckusTcl "$::DIR_PATH/xilinx"