# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Check for non-zero Vivado version (in-case non-Vivado project)
if {  $::env(VIVADO_VERSION) > 0.0} {
   # Load the Core
   loadRuckusTcl "$::DIR_PATH/general"
   loadRuckusTcl "$::DIR_PATH/xvc-udp"
} else {
   loadSource -lib surf -path "$::DIR_PATH/general/rtl/SelectIoRxGearboxAligner.vhd"
   loadSource -lib surf -dir  "$::DIR_PATH/dummy"
}

# Get the family type
set family [getFpgaArch]

if { ${family} eq {artix7}  ||
     ${family} eq {kintex7} ||
     ${family} eq {virtex7} ||
     ${family} eq {zynq} } {
   loadRuckusTcl "$::DIR_PATH/7Series"
}

if { ${family} eq {kintexu} ||
     ${family} eq {virtexu} } {
   loadRuckusTcl "$::DIR_PATH/UltraScale"
}

if { ${family} eq {kintexuplus} ||
     ${family} eq {virtexuplus} ||
     ${family} eq {virtexuplusHBM} ||
     ${family} eq {zynquplus} ||
     ${family} eq {zynquplusRFSOC} } {
   loadRuckusTcl "$::DIR_PATH/UltraScale+"
}
