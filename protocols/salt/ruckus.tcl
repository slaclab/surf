# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load the Core
loadRuckusTcl "$::DIR_PATH/core"

# Get the family type
set family [getFpgaFamily]

if { ${family} == "artix7" } {
   loadRuckusTcl "$::DIR_PATH/xilinx7"
}

if { ${family} == "kintex7" } {
   loadRuckusTcl "$::DIR_PATH/xilinx7"
}

if { ${family} == "virtex7" } {
   loadRuckusTcl "$::DIR_PATH/xilinx7"
}

if { ${family} == "zynq" } {
   loadRuckusTcl "$::DIR_PATH/xilinx7"
}

if { ${family} == "kintexu" } {
   loadRuckusTcl "$::DIR_PATH/xilinxUltraScale"
}
