# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL_COMBO)

# Load Source Code
loadSource -lib surf -dir "$::DIR_PATH/core"
loadSource -lib surf -sim_only -dir "$::DIR_PATH/sim"

# Get the family type
set family [getFpgaFamily]

if { ${family} eq {artix7}  ||
     ${family} eq {kintex7} ||
     ${family} eq {virtex7} ||
     ${family} eq {zynq} } {
   loadRuckusTcl "$::DIR_PATH/7Series"
}

# if { ${family} eq {kintexu} ||
     # ${family} eq {kintexuplus} ||
     # ${family} eq {virtexuplus} ||
     # ${family} eq {virtexuplusHBM} ||
     # ${family} eq {zynquplus} ||
     # ${family} eq {zynquplusRFSOC} ||
     # ${family} eq {qzynquplusRFSOC} } {
   # loadRuckusTcl "$::DIR_PATH/UltraScale"
# }
