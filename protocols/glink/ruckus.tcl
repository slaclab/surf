# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL_COMBO)

# Load the Core
loadRuckusTcl "$::DIR_PATH/core"

# Get the family type
set family [getFpgaArch]

#############################################################################
# Note: Our G-Link implementation only supported by the Xilinx 7-Series FPGAs
#############################################################################

if { ${family} == "artix7" } {
   loadRuckusTcl "$::DIR_PATH/gtp7"
}

if { ${family} == "kintex7" } {
   loadRuckusTcl "$::DIR_PATH/gtx7"
}

if { ${family} == "zynq" } {
   if { [ regexp "XC7Z(015|012).*" [string toupper "$::env(PRJ_PART)"] ] } {
      loadRuckusTcl "$::DIR_PATH/gtp7"
   } else {
      loadRuckusTcl "$::DIR_PATH/gtx7"
   }
}
