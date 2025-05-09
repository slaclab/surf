# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load the Core
loadRuckusTcl "$::DIR_PATH/core"

# Check for non-zero Vivado version (in-case non-Vivado project)
if {  $::env(VIVADO_VERSION) > 0.0} {

   # Get the family type
   set family [getFpgaArch]

   if { ${family} eq {kintexuplus} ||
        ${family} eq {virtexuplus} ||
        ${family} eq {virtexuplusHBM} } {
      loadRuckusTcl "$::DIR_PATH/gtyUs+"
   }

}
