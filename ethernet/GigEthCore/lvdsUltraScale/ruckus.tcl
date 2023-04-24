# Load RUCKUS environment and library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
if { $::env(VIVADO_VERSION) >= 2021.2 } {

   loadSource -lib surf -dir  "$::DIR_PATH/rtl"

   loadSource -lib surf -path "$::DIR_PATH/ip/GigEthLvdsUltraScaleCore.dcp"
   # loadIpCore -path "$::DIR_PATH/ip/GigEthLvdsUltraScaleCore.xci"

} else {
   puts "\n\nWARNING: $::DIR_PATH requires Vivado 2021.2 (or later)\n\n"
}
