# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado/proc.tcl

# Load local source Code and constraints
if { $::env(VIVADO_VERSION) >= 2017.3 } {

   loadSource -lib surf   -dir "$::DIR_PATH/rtl"

   loadSource -lib surf    -path "$::DIR_PATH/ip/PgpGthCore.dcp"
   # loadIpCore  -path "$::DIR_PATH/ip/PgpGthCore.xci"

} else {
   puts "\n\nWARNING: $::DIR_PATH requires Vivado 2017.3 (or later)\n\n"
}