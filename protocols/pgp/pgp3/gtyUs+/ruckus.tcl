# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
if { $::env(VIVADO_VERSION) >= 2020.1 } {

   # Load Source Code
   loadSource -lib surf -dir "$::DIR_PATH/rtl"

   loadSource -lib surf   -path "$::DIR_PATH/ip/Pgp3GtyUsIp20G/Pgp3GtyUsIp20G.dcp"
   # loadIpCore -path "$::DIR_PATH/ip/Pgp3GtyUsIp20G/Pgp3GtyUsIp20G.xci"

   loadSource -lib surf   -path "$::DIR_PATH/ip/Pgp3GtyUsIp18G/Pgp3GtyUsIp18G.dcp"
   # loadIpCore -path "$::DIR_PATH/ip/Pgp3GtyUsIp18G/Pgp3GtyUsIp18G.xci"

   loadSource -lib surf   -path "$::DIR_PATH/ip/Pgp3GtyUsIp17G/Pgp3GtyUsIp17G.dcp"
   # loadIpCore -path "$::DIR_PATH/ip/Pgp3GtyUsIp17G/Pgp3GtyUsIp17G.xci"

   loadSource -lib surf   -path "$::DIR_PATH/ip/Pgp3GtyUsIp15G/Pgp3GtyUsIp15G.dcp"
   #loadIpCore -path "$::DIR_PATH/ip/Pgp3GtyUsIp15G/Pgp3GtyUsIp15G.xci"

   loadSource -lib surf   -path "$::DIR_PATH/ip/Pgp3GtyUsIp13G/Pgp3GtyUsIp13G.dcp"
   # loadIpCore -path "$::DIR_PATH/ip/Pgp3GtyUsIp13G/Pgp3GtyUsIp13G.xci"

   loadSource -lib surf   -path "$::DIR_PATH/ip/Pgp3GtyUsIp12G/Pgp3GtyUsIp12G.dcp"
   #loadIpCore -path "$::DIR_PATH/ip/Pgp3GtyUsIp12G/Pgp3GtyUsIp12G.xci"

   loadSource -lib surf   -path "$::DIR_PATH/ip/Pgp3GtyUsIp10G/Pgp3GtyUsIp10G.dcp"
   #loadIpCore -path "$::DIR_PATH/ip/Pgp3GtyUsIp10G/Pgp3GtyUsIp10G.xci"

   loadSource -lib surf   -path "$::DIR_PATH/ip/Pgp3GtyUsIp6G/Pgp3GtyUsIp6G.dcp"
   #loadIpCore -path "$::DIR_PATH/ip/Pgp3GtyUsIp6G/Pgp3GtyUsIp6G.xci"

   loadSource -lib surf   -path "$::DIR_PATH/ip/Pgp3GtyUsIp3G/Pgp3GtyUsIp3G.dcp"
   #loadIpCore -path "$::DIR_PATH/ip/Pgp3GtyUsIp3G/Pgp3GtyUsIp3G.xci"

} else {
   puts "\n\nWARNING: $::DIR_PATH requires Vivado 2020.1 (or later)\n\n"
}
