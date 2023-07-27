# Load RUCKUS environment and library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib surf -dir "$::DIR_PATH/rtl"
