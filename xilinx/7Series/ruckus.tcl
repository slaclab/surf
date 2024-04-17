# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load the Core
loadRuckusTcl "$::DIR_PATH/general"
loadRuckusTcl "$::DIR_PATH/xadc"
loadRuckusTcl "$::DIR_PATH/sem"

# Get the family type
set family [getFpgaArch]

if { ${family} == "artix7" } {
   loadRuckusTcl "$::DIR_PATH/gtp7"
}

if { ${family} == "kintex7" } {
   loadRuckusTcl "$::DIR_PATH/gtx7"
}

if { ${family} == "virtex7" } {
   loadRuckusTcl "$::DIR_PATH/gth7"
}

if { ${family} == "zynq" } {
   if { [ regexp "XC7Z(015|012).*" [string toupper "$::env(PRJ_PART)"] ] } {
      loadRuckusTcl "$::DIR_PATH/gtp7"
   } else {
      loadRuckusTcl "$::DIR_PATH/gtx7"
   }
}

