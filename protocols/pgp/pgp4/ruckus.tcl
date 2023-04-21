# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL_COMBO)

# Load the Core
loadRuckusTcl "$::DIR_PATH/core"

# Check for non-zero Vivado version (in-case non-Vivado project)
if {  $::env(VIVADO_VERSION) > 0.0} {

   # Get the family type
   set family [getFpgaArch]

   if { ${family} eq {artix7} } {
      loadRuckusTcl "$::DIR_PATH/gtp7"
   }

   if { ${family} eq {kintex7} } {
      loadRuckusTcl "$::DIR_PATH/gtx7"
   }

   if { ${family} eq {zynq} } {
      if { [ regexp "XC7Z(015|012).*" [string toupper "$::env(PRJ_PART)"] ] } {
         loadRuckusTcl "$::DIR_PATH/gtp7"
      } else {
         loadRuckusTcl "$::DIR_PATH/gtx7"
      }
   }

   # if { ${family} eq {virtex7} } {
      # loadRuckusTcl "$::DIR_PATH/gth7"
   # }

   if { ${family} eq {kintexu} } {
      loadRuckusTcl "$::DIR_PATH/gthUs"
   }

   if { ${family} eq {kintexuplus} ||
        ${family} eq {zynquplus} ||
        ${family} eq {zynquplusRFSOC} } {
      loadRuckusTcl "$::DIR_PATH/gthUs+"
      loadRuckusTcl "$::DIR_PATH/gtyUs+"
   }

   if { ${family} eq {virtexuplus} ||
        ${family} eq {virtexuplusHBM} } {
      loadRuckusTcl "$::DIR_PATH/gtyUs+"
   }

}