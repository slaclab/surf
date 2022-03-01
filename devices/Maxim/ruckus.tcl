# Load RUCKUS environment and library
source $::env(RUCKUS_PROC_TCL_QUIET)

# Load the source code
loadSource -lib surf -dir "$::DIR_PATH/rtl"
