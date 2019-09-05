# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
if { $::env(VIVADO_VERSION) >= 2019.1 } {

   # Load Source Code
   loadSource -dir "$::DIR_PATH/rtl"
   
   # loadSource   -path "$::DIR_PATH/ip/PgpEthCaui4GtyIpCore.dcp"
   loadIpCore -path "$::DIR_PATH/ip/PgpEthCaui4GtyIpCore.xci"
   
} else {
   puts "\n\nWARNING: $::DIR_PATH requires Vivado 2019.1 (or later)\n\n"
} 
