# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load the source code
loadSource -dir "$::DIR_PATH/core"

# Get the family type
set family [getFpgaFamily]

if { ${family} eq {kintexu} ||
     ${family} eq {kintexuplus} ||
     ${family} eq {virtexuplus} ||
     ${family} eq {zynquplus} } {
   loadSource -dir  "$::DIR_PATH/lvdsUltraScale"
}
