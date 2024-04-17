# Load RUCKUS environment and library
source $::env(RUCKUS_PROC_TCL)

# Check for non-zero Vivado version (in-case non-Vivado project)
if {  $::env(VIVADO_VERSION) > 0.0} {
   # Load ruckus files
   loadRuckusTcl "$::DIR_PATH/ddr3"
   loadRuckusTcl "$::DIR_PATH/ddr4"
   loadRuckusTcl "$::DIR_PATH/mt28ew"
   loadRuckusTcl "$::DIR_PATH/n25q"
   loadRuckusTcl "$::DIR_PATH/p30"
}
