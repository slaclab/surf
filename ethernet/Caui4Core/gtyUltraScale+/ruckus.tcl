# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL_COMBO)

# Load Source Code
if { $::env(VIVADO_VERSION) >= 2021.1 } {

   loadSource -lib surf -dir  "$::DIR_PATH/rtl"

   loadSource -lib surf -path "$::DIR_PATH/ip/Caui4GtyIpCore156MHz.dcp"
   # loadIpCore -path "$::DIR_PATH/ip/Caui4GtyIpCore156MHz.xci"

   loadSource -lib surf -path "$::DIR_PATH/ip/Caui4GtyIpCore161MHz.dcp"
   # loadIpCore -path "$::DIR_PATH/ip/Caui4GtyIpCore161MHz.xci"

} else {
   puts "\n\nWARNING: $::DIR_PATH requires Vivado 2021.1 (or later)\n\n"
}
