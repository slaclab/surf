# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL_COMBO)

# Load local source Code and constraints
if { $::env(VIVADO_VERSION) >= 2020.1 } {

   loadSource -lib surf   -dir "$::DIR_PATH/rtl"

   loadSource -lib surf    -path "$::DIR_PATH/ip/PgpGtyCore.dcp"
   # loadIpCore  -path "$::DIR_PATH/ip/PgpGtyCore.xci"

} else {
   puts "\n\nWARNING: $::DIR_PATH requires Vivado 2020.1 (or later)\n\n"
}