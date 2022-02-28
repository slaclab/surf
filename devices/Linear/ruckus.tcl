# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado/proc.tcl

# Load ruckus files
loadRuckusTcl "$::DIR_PATH/lct2270"
