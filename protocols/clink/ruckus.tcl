# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Get the family type
set family [getFpgaFamily]

# Load Source Code
loadSource -dir "$::DIR_PATH/rtl"

# Load Simulation
loadSource -sim_only -dir "$::DIR_PATH/tb"
   
if {  ${family} == "artix7" ||
      ${family} == "kintex7" ||
      ${family} == "virtex7" ||
      ${family} == "zynq" } {
   loadSource -dir  "$::DIR_PATH/7Series"
}

if { ${family} eq {kintexu} ||
     ${family} eq {kintexuplus} ||
     ${family} eq {virtexuplus} ||
     ${family} eq {zynquplus} } {
   loadSource -dir  "$::DIR_PATH/UltraScale"
}
