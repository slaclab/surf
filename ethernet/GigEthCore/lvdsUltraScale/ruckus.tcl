# Load RUCKUS environment and library
source $::env(RUCKUS_QUIET_FLAG) $::env(RUCKUS_PROC_TCL)

loadSource -lib surf -dir "$::DIR_PATH/rtl"
