# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
if { $::env(VIVADO_VERSION) >= 2015.2 } {

   loadSource -lib surf -dir  "$::DIR_PATH/rtl"

   # loadIpCore -path "$::DIR_PATH/ip/AxiXadcMinimum.xci"
   loadSource -lib surf -path "$::DIR_PATH/ip/AxiXadcMinimum.dcp"

} else {
   puts "\n\nWARNING: $::DIR_PATH requires Vivado 2015.2 (or later)\n\n"
}