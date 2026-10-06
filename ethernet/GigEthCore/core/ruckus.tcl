# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load common Ethernet management and configuration types.
loadSource -lib surf -dir  "$::DIR_PATH/rtl"
