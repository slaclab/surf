# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadRuckusTcl "$::DIR_PATH/generic"

# Check for non-zero Vivado version (in-case non-Vivado project)
if {  $::env(VIVADO_VERSION) > 2023.1} {
   loadRuckusTcl "$::DIR_PATH/xilinx"
}
