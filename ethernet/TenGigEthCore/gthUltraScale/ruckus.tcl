# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL_COMBO)

# Load Source Code
if { $::env(VIVADO_VERSION) >= 2015.4 } {

   loadSource -lib surf -dir  "$::DIR_PATH/rtl"

   # loadIpCore -path "$::DIR_PATH/ip/TenGigEthGthUltraScale156p25MHzCore.xci"
   loadSource -lib surf -path "$::DIR_PATH/ip/TenGigEthGthUltraScale156p25MHzCore.dcp"

} else {
   puts "\n\nWARNING: $::DIR_PATH requires Vivado 2015.4 (or later)\n\n"
}
