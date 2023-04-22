# Load RUCKUS environment and library
source $::env(RUCKUS_PROC_TCL)

# Load the source code
loadSource -lib surf -dir "$::DIR_PATH/core"

# Get the family type
set family [getFpgaArch]

if { ${family} eq {kintexu} ||
     ${family} eq {kintexuplus} ||
     ${family} eq {virtexuplus} ||
     ${family} eq {virtexuplusHBM} ||
     ${family} eq {zynquplus} ||
     ${family} eq {zynquplusRFSOC} } {
   loadSource -lib surf -dir  "$::DIR_PATH/lvdsUltraScale"
}
