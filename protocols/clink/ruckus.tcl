# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Get the family type
set family [getFpgaArch]

# Load Source Code
loadSource -lib surf -dir "$::DIR_PATH/rtl"

# Load Simulation
loadSource -lib surf -sim_only -dir "$::DIR_PATH/tb"

if {  ${family} == "artix7" ||
      ${family} == "kintex7" ||
      ${family} == "virtex7" ||
      ${family} == "zynq" } {
   loadSource -lib surf -dir  "$::DIR_PATH/7Series"
}

if { ${family} eq {kintexu} ||
     ${family} eq {virtexu} ||
     ${family} eq {kintexuplus} ||
     ${family} eq {virtexuplus} ||
     ${family} eq {virtexuplusHBM} ||
     ${family} eq {zynquplus} ||
     ${family} eq {zynquplusRFSOC} } {
   loadSource -lib surf -dir  "$::DIR_PATH/UltraScale"
}
