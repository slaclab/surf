# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load ruckus files
loadRuckusTcl "$::DIR_PATH/cxp"
loadRuckusTcl "$::DIR_PATH/qsfp"
loadRuckusTcl "$::DIR_PATH/sfp"
