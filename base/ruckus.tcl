# Load RUCKUS environment and library
source $::env(RUCKUS_PROC_TCL)

# Load ruckus files
loadRuckusTcl "$::DIR_PATH/delay"
loadRuckusTcl "$::DIR_PATH/crc"
loadRuckusTcl "$::DIR_PATH/fifo"
loadRuckusTcl "$::DIR_PATH/general"
loadRuckusTcl "$::DIR_PATH/ram"
loadRuckusTcl "$::DIR_PATH/sync"
