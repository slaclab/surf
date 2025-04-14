# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load the Core
loadRuckusTcl "$::DIR_PATH/core"

# Get the family type
set family [getFpgaArch]


if { ${family} eq {artix7} } {
   loadRuckusTcl "$::DIR_PATH/gtp7"
}

if { ${family} eq {kintexuplus} } {
    loadRuckusTcl "$::DIR_PATH/gthUltraScale+"
    loadRuckusTcl "$::DIR_PATH/gtyUltraScale+"
}

if { ${family} eq {virtexuplus} ||
     ${family} eq {virtexuplusHBM} } {
   loadRuckusTcl "$::DIR_PATH/gtyUltraScale+"
}

if { ${family} eq {zynquplus} ||
     ${family} eq {zynquplusRFSOC} } {
   loadRuckusTcl "$::DIR_PATH/gthUltraScale+"
}
