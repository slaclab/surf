# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
loadSource -dir "$::DIR_PATH/core"
loadSource -sim_only -dir "$::DIR_PATH/tb"

# Get the family type
set family [getFpgaFamily]

if { ${family} eq {artix7}  ||
     ${family} eq {kintex7} ||
     ${family} eq {virtex7} ||
     ${family} eq {zynq} } {
   loadRuckusTcl "$::DIR_PATH/7Series"
}

if { ${family} eq {kintexu} ||
     ${family} eq {kintexuplus} ||
     ${family} eq {virtexuplus} ||
     ${family} eq {zynquplus} } {
   loadRuckusTcl "$::DIR_PATH/UltraScale"
}