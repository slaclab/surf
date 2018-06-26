# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load the Core
loadRuckusTcl "$::DIR_PATH/core"

# Get the family type
set family [getFpgaFamily]

if { ${family} eq {kintex7} ||
     ${family} eq {zynq} } {
   loadRuckusTcl "$::DIR_PATH/gtx7"
}

if { ${family} eq {virtex7} } {
   loadRuckusTcl "$::DIR_PATH/gth7"
}

if { ${family} eq {kintexu} } {
   loadRuckusTcl "$::DIR_PATH/gthUltraScale"
}

if { ${family} eq {kintexuplus} ||
     ${family} eq {zynquplus} } {
   loadRuckusTcl "$::DIR_PATH/gthUltraScale+"
   # loadRuckusTcl "$::DIR_PATH/gtyUltraScale+"
}

# if { ${family} eq {virtexuplus} } {
   # loadRuckusTcl "$::DIR_PATH/gtyUltraScale+"
# }
