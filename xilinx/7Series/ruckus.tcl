# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load the Core
loadRuckusTcl "$::DIR_PATH/general"
loadRuckusTcl "$::DIR_PATH/xadc"
loadRuckusTcl "$::DIR_PATH/sem"

# Get the family type
set family [getFpgaFamily]

if { ${family} == "artix7" } {
   loadRuckusTcl "$::DIR_PATH/gtp7"
}

if { ${family} == "kintex7" } {
   loadRuckusTcl "$::DIR_PATH/gtx7"
}

if { ${family} == "virtex7" } {
   loadRuckusTcl "$::DIR_PATH/gth7"
}

if { ${family} == "zynq" } {
   loadRuckusTcl "$::DIR_PATH/gtx7"
}

