# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado/proc.tcl

# Load Source Code
if { $::env(VIVADO_VERSION) >= 2016.4 } {
   loadSource -lib surf -dir  "$::DIR_PATH/rtl"
   loadSource -lib surf -path "$::DIR_PATH/images/GigEthGthUltraScaleCore.dcp"
} else {
   puts "\n\nWARNING: $::DIR_PATH requires Vivado 2016.4 (or later)\n\n"
}
