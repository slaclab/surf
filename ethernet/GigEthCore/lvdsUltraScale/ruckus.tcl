# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

loadSource -dir "$::DIR_PATH/rtl"
