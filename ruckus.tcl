# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Check for submodule tagging
if { [SubmoduleCheck {ruckus} {1.5.0} ] < 0 } {exit -1}

# Load ruckus files
loadRuckusTcl "$::DIR_PATH/axi"
loadRuckusTcl "$::DIR_PATH/base"
loadRuckusTcl "$::DIR_PATH/dsp"
loadRuckusTcl "$::DIR_PATH/devices"
loadRuckusTcl "$::DIR_PATH/ethernet"
loadRuckusTcl "$::DIR_PATH/protocols"
loadRuckusTcl "$::DIR_PATH/xilinx"
