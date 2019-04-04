# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
loadSource -dir "$::DIR_PATH/rtl"
loadSource -dir "$::DIR_PATH/rtl/inferred"
loadSource -dir "$::DIR_PATH/rtl/xilinx"

# Bug Fix: https://www.xilinx.com/support/answers/67815.html
set_property XPM_LIBRARIES XPM_MEMORY [current_project]
