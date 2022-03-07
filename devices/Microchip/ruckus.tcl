# Load RUCKUS environment and library
source $::env(RUCKUS_QUIET_FLAG) $::env(RUCKUS_PROC_TCL)

# Load ruckus files
loadRuckusTcl "$::DIR_PATH/sy56040"
