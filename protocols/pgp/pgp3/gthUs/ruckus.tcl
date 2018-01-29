# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
if { $::env(VIVADO_VERSION) >= 2017.3 } {

   # Load Source Code
   loadSource -dir "$::DIR_PATH/rtl/"
   
   loadSource   -path "$::DIR_PATH/ip/Pgp3GthUsIp/Pgp3GthUsIp.dcp"
   # loadIpCore -path "$::DIR_PATH/ip/Pgp3GthUsIp/Pgp3GthUsIp.xci"
   
} else {
   puts "\n\nWARNING: $::DIR_PATH requires Vivado 2017.3 (or later)\n\n"
} 
