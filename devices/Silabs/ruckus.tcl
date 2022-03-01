# Load RUCKUS environment and library
source $::env(RUCKUS_PROC_TCL_QUIET)

# Load ruckus files
loadRuckusTcl "$::DIR_PATH/si5324"
loadRuckusTcl "$::DIR_PATH/si5345"
