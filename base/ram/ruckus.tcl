# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
loadSource -lib surf -dir "$::DIR_PATH/inferred"
loadSource -lib surf -dir "$::DIR_PATH/xilinx"
