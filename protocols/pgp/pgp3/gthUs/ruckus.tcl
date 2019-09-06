# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
if { $::env(VIVADO_VERSION) >= 2017.3 } {

   # Load Source Code
   loadSource -dir "$::DIR_PATH/rtl"
   
   loadSource   -path "$::DIR_PATH/ip/Pgp3GthUsIp10G/Pgp3GthUsIp10G.dcp"
   # loadIpCore -path "$::DIR_PATH/ip/Pgp3GthUsIp10G/Pgp3GthUsIp10G.xci"
   
   loadSource   -path "$::DIR_PATH/ip/Pgp3GthUsIp6G/Pgp3GthUsIp6G.dcp"
   # loadIpCore -path "$::DIR_PATH/ip/Pgp3GthUsIp6G/Pgp3GthUsIp6G.xci"

   loadSource   -path "$::DIR_PATH/ip/Pgp3GthUsIp3G/Pgp3GthUsIp3G.dcp"
   # loadIpCore -path "$::DIR_PATH/ip/Pgp3GthUsIp3G/Pgp3GthUsIp3G.xci"
   
} else {
   puts "\n\nWARNING: $::DIR_PATH requires Vivado 2017.3 (or later)\n\n"
} 
