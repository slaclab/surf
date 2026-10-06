# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
if { $::env(VIVADO_VERSION) >= 2016.4 } {
   # Includes the PHY adapter shared by the ordinary Ethernet and PTP lanes.
   loadSource -lib surf -dir  "$::DIR_PATH/rtl"
   loadSource -lib surf -path "$::DIR_PATH/images/GigEthGthUltraScaleCore.dcp"
} else {
   puts "\n\nWARNING: $::DIR_PATH requires Vivado 2016.4 (or later)\n\n"
}
