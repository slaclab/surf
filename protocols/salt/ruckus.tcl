# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Get the family type
set family [getFpgaArch]

if { ${family} eq {artix7}  ||
     ${family} eq {kintex7} ||
     ${family} eq {virtex7} ||
     ${family} eq {zynq} } {
   set fpgaType "7Series"
}

if { ${family} eq {kintexu} ||
     ${family} eq {kintexuplus} ||
     ${family} eq {virtexuplus} ||
     ${family} eq {virtexuplusHBM} ||
     ${family} eq {zynquplus} ||
     ${family} eq {zynquplusRFSOC} } {
   set fpgaType "UltraScale"
}

# Load the source code
loadSource -lib surf -dir           "$::DIR_PATH/rtl"
loadSource -lib surf -dir           "$::DIR_PATH/rtl/${fpgaType}"
loadSource -lib surf -sim_only -dir "$::DIR_PATH/tb"
