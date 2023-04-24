# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
if { $::env(VIVADO_VERSION) >= 2020.1 } {

   # Load Source Code
   loadSource -lib surf -dir "$::DIR_PATH/rtl"

   loadSource -lib surf   -path "$::DIR_PATH/ip/Pgp3GthUsIp15G/Pgp3GthUsIp15G.dcp"
   # loadIpCore -path "$::DIR_PATH/ip/Pgp3GthUsIp15G/Pgp3GthUsIp15G.xci"

   loadSource -lib surf   -path "$::DIR_PATH/ip/Pgp3GthUsIp12G/Pgp3GthUsIp12G.dcp"
   # loadIpCore -path "$::DIR_PATH/ip/Pgp3GthUsIp12G/Pgp3GthUsIp12G.xci"

   loadSource -lib surf   -path "$::DIR_PATH/ip/Pgp3GthUsIp10G/Pgp3GthUsIp10G.dcp"
   # loadIpCore -path "$::DIR_PATH/ip/Pgp3GthUsIp10G/Pgp3GthUsIp10G.xci"

   loadSource -lib surf   -path "$::DIR_PATH/ip/Pgp3GthUsIp6G/Pgp3GthUsIp6G.dcp"
   # loadIpCore -path "$::DIR_PATH/ip/Pgp3GthUsIp6G/Pgp3GthUsIp6G.xci"

   loadSource -lib surf   -path "$::DIR_PATH/ip/Pgp3GthUsIp3G/Pgp3GthUsIp3G.dcp"
   # loadIpCore -path "$::DIR_PATH/ip/Pgp3GthUsIp3G/Pgp3GthUsIp3G.xci"

} else {
   puts "\n\nWARNING: $::DIR_PATH requires Vivado 2020.1 (or later)\n\n"
}
