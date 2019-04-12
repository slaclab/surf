# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Check for submodule tagging
if { [info exists ::env(OVERRIDE_SUBMODULE_LOCKS)] != 1 || $::env(OVERRIDE_SUBMODULE_LOCKS) == 0 } {
   if { [SubmoduleCheck {ruckus} {1.7.6} ] < 0 } {exit -1}
} else {
   puts "\n\n*********************************************************"
   puts "OVERRIDE_SUBMODULE_LOCKS != 0"
   puts "Ignoring the submodule locks in surf/ruckus.tcl"
   puts "*********************************************************\n\n"
}

# Load ruckus files
loadRuckusTcl "$::DIR_PATH/axi"
loadRuckusTcl "$::DIR_PATH/base"
loadRuckusTcl "$::DIR_PATH/dsp"
loadRuckusTcl "$::DIR_PATH/devices"
loadRuckusTcl "$::DIR_PATH/ethernet"
loadRuckusTcl "$::DIR_PATH/protocols"
loadRuckusTcl "$::DIR_PATH/xilinx"
