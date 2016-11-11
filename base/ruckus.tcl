# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load ruckus files
loadRuckusTcl "$::DIR_PATH/fifo"
loadRuckusTcl "$::DIR_PATH/general"
loadRuckusTcl "$::DIR_PATH/ram"
loadRuckusTcl "$::DIR_PATH/sync"
