# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
if { $::env(VIVADO_VERSION) >= 2019.1 } {

   loadSource -dir  "$::DIR_PATH/rtl"

   loadSource -path "$::DIR_PATH/ip/Caui4GtyIpCore156MHz.dcp"
   # loadIpCore -path "$::DIR_PATH/ip/Caui4GtyIpCore156MHz.xci"
   
   loadSource -path "$::DIR_PATH/ip/Caui4GtyIpCore161MHz.dcp"
   # loadIpCore -path "$::DIR_PATH/ip/Caui4GtyIpCore161MHz.xci"   

} else {
   puts "\n\nWARNING: $::DIR_PATH requires Vivado 2019.1 (or later)\n\n"
}   
