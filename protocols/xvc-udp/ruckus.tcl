# Load RUCKUS environment and library
source $::env(RUCKUS_QUIET_FLAG) $::env(RUCKUS_PROC_TCL)

if { [isVersal] == true } {
   set versalType true

# Check for version 2018.3 of Vivado (or later)
} elseif { $::env(VIVADO_VERSION) >= 2018.3 } {

   # Load the wrapper source code
   loadSource -lib surf -dir "$::DIR_PATH/rtl"

   # Get the family type
   set family [getFpgaArch]

   if { ${family} eq {artix7}  ||
        ${family} eq {kintex7} ||
        ${family} eq {virtex7} ||
        ${family} eq {zynq} } {
      set dirType "7Series"
   }

   if { ${family} eq {kintexu} ||
        ${family} eq {kintexuplus} ||
        ${family} eq {virtexuplus} ||
        ${family} eq {virtexu} ||
        ${family} eq {virtexuplusHBM} ||
        ${family} eq {zynquplus} ||
        ${family} eq {zynquplusRFSOC} } {
      set dirType "UltraScale"
   }

   if { [info exists ::env(USE_XVC_DEBUG)] != 1 || $::env(USE_XVC_DEBUG) == 0 } {
      loadSource -lib surf -path "$::DIR_PATH/dcp/${dirType}/Stub/images/UdpDebugBridge.dcp"

   } elseif { $::env(USE_XVC_DEBUG) == -1 } {
      puts "Note: USE_XVC_DEBUG = -1"
      puts "The debug bridge is left as a black box"
      puts "and it is the application's responsibility"
      puts "to define a suitable implementation."

   } else {
      loadSource -lib surf -path "$::DIR_PATH/dcp/${dirType}/Impl/images/UdpDebugBridge.dcp"
   }

} else {
   # Check for non-zero Vivado version (in-case non-Vivado project)
   if {  $::env(VIVADO_VERSION) > 0.0} {
      puts "\n\nWARNING: $::DIR_PATH requires Vivado 2018.3 (or later)\n\n"
   }
}
