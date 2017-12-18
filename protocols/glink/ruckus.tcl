# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load the Core
loadRuckusTcl "$::DIR_PATH/core"

# Get the family type
set family [getFpgaFamily]

#############################################################################
# Note: Our G-Link implementation only supported by the Xilinx 7-Series FPGAs
#############################################################################

if { ${family} == "artix7" } {
   loadRuckusTcl "$::DIR_PATH/gtp7"
}

if { ${family} == "kintex7" } {
   loadRuckusTcl "$::DIR_PATH/gtx7"
}

if { ${family} == "zynq" } {
   loadRuckusTcl "$::DIR_PATH/gtx7"
}
