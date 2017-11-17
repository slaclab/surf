# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Check for submodule tagging
if { [SubmoduleCheck {ruckus} {1.5.0} ] < 0 } {exit -1}

# Load ruckus files
loadRuckusTcl "$::DIR_PATH/axi"        "quiet"
loadRuckusTcl "$::DIR_PATH/base"       "quiet"
loadRuckusTcl "$::DIR_PATH/dsp"        "quiet"
loadRuckusTcl "$::DIR_PATH/devices"    "quiet"
loadRuckusTcl "$::DIR_PATH/ethernet"   "quiet"
loadRuckusTcl "$::DIR_PATH/protocols"  "quiet"
loadRuckusTcl "$::DIR_PATH/xilinx"     "quiet"
