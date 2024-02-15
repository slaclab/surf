# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado/proc.tcl

# Load Source Code
loadSource -lib surf -dir  "$::DIR_PATH/rtl"
