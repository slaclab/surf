# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL_COMBO)

# Load the Core
loadRuckusTcl "$::DIR_PATH/core"

# Get the family type
set family [getFpgaArch]

if { ${family} eq {kintexu} } {
   loadRuckusTcl "$::DIR_PATH/gthUs"
}

if { ${family} eq {kintexuplus} ||
     ${family} eq {zynquplus} ||
     ${family} eq {zynquplusRFSOC} } {
   # loadRuckusTcl "$::DIR_PATH/gthUs+"
   loadRuckusTcl "$::DIR_PATH/gtyUs+"
}

if { ${family} eq {virtexuplus} ||
     ${family} eq {virtexuplusHBM} } {
   loadRuckusTcl "$::DIR_PATH/gtyUs+"
}
