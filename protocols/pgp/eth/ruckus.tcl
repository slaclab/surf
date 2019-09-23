# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load the Core
loadRuckusTcl "$::DIR_PATH/core"

# Get the family type
set family [getFpgaFamily]

if { ${family} eq {kintexuplus} ||
     ${family} eq {virtexuplus} } {
   loadRuckusTcl "$::DIR_PATH/gtyUs+"
}
