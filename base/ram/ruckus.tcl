# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL_QUIET)

# Load Source Code
loadSource -lib surf -dir "$::DIR_PATH/inferred"
loadSource -lib surf -dir "$::DIR_PATH/xilinx"

# https://support.xilinx.com/s/article/67815?language=en_US
if { $::env(VIVADO_VERSION) >= 2021.2 } {
   set_property XPM_LIBRARIES XPM_MEMORY [current_project]
}
