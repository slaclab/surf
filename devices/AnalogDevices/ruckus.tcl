# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load ruckus files
loadRuckusTcl "$::DIR_PATH/ad5780"
loadRuckusTcl "$::DIR_PATH/ad9249"
loadRuckusTcl "$::DIR_PATH/ad9467"
loadRuckusTcl "$::DIR_PATH/general"
