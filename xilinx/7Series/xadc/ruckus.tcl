# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
if { $::env(VIVADO_VERSION) >= 2015.2 } {

   loadSource -dir  "$::DIR_PATH/rtl"

   # loadIpCore -path "$::DIR_PATH/ip/AxiXadcMinimum.xci"
   loadSource -path "$::DIR_PATH/ip/AxiXadcMinimum.dcp"

} else {
   puts "\n\nWARNING: $::DIR_PATH requires Vivado 2015.2 (or later)\n\n"
}      