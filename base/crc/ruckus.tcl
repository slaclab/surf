# Load RUCKUS library
source $::env(RUCKUS_QUIET_FLAG) $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib surf -dir "$::DIR_PATH/rtl"
