# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL_COMBO)

# Get the family type
set family [getFpgaArch]

if { ${family} eq {kintexuplus} ||
     ${family} eq {virtexuplus} ||
     ${family} eq {virtexuplusHBM} ||
     ${family} eq {zynquplus} ||
     ${family} eq {zynquplusRFSOC} } {
   loadRuckusTcl "$::DIR_PATH/gtyUltraScale+"
}
