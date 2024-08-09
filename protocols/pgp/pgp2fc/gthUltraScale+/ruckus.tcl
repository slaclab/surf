# Load RUCKUS library
source $::env(RUCKUS_QUIET_FLAG) $::env(RUCKUS_PROC_TCL)

# Load local source Code and constraints
if { $::env(VIVADO_VERSION) >= 2020.1 } {

   loadSource -lib surf   -dir "$::DIR_PATH/rtl"

   loadSource -lib surf    -path "$::DIR_PATH/ip/Pgp2fcGthCore.dcp"
   #loadIpCore  -path "$::DIR_PATH/ip/Pgp2fcGthCore.xci"

} else {
   puts "\n\nWARNING: $::DIR_PATH requires Vivado 2020.1 (or later)\n\n"
}
