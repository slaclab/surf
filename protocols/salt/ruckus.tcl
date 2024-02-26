# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Get the family type
set family [getFpgaArch]

if { ${family} eq {artix7}  ||
     ${family} eq {kintex7} ||
     ${family} eq {virtex7} ||
     ${family} eq {zynq} } {
   set fpgaType "7Series"
}

if { ${family} eq {kintexu} ||
     ${family} eq {virtexu} ||
     ${family} eq {kintexuplus} ||
     ${family} eq {virtexuplus} ||
     ${family} eq {virtexuplusHBM} ||
     ${family} eq {zynquplus} ||
     ${family} eq {zynquplusRFSOC} } {
   set fpgaType "UltraScale"
}

# Check for non-zero Vivado version (in-case non-Vivado project)
if { ($::env(VIVADO_VERSION) >= 0.0) && ([isVersal] != true) } {
   # Load the source code
   loadSource -lib surf -dir           "$::DIR_PATH/rtl"
   loadSource -lib surf -dir           "$::DIR_PATH/rtl/${fpgaType}"
   loadSource -lib surf -sim_only -dir "$::DIR_PATH/tb"
}
