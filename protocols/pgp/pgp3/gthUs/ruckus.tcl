# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
if { $::env(VIVADO_VERSION) >= 2017.3 } {

   # Load Source Code
   loadSource -lib surf -dir "$::DIR_PATH/rtl"
   
   # loadIpCore -lib surf -path "$::DIR_PATH/ip/Pgp3GthUsIp10G/Pgp3GthUsIp10G.xci"
   loadSource   -lib surf -path "$::DIR_PATH/ip/Pgp3GthUsIp10G/Pgp3GthUsIp10G.dcp"
   
   # loadIpCore -lib surf -path "$::DIR_PATH/ip/Pgp3GthUsIp6G/Pgp3GthUsIp6G.xci"   
   loadSource   -lib surf -path "$::DIR_PATH/ip/Pgp3GthUsIp6G/Pgp3GthUsIp6G.dcp"
   
} else {
   puts "\n\nWARNING: $::DIR_PATH requires Vivado 2017.3 (or later)\n\n"
} 
