# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
if { $::env(VIVADO_VERSION) >= 2016.4 } {
   # One PHY adapter selects fabric/dedicated reference via USE_GTREFCLK_G.
   loadSource -lib surf -dir  "$::DIR_PATH/rtl"
   # A single dual-mode checkpoint serves both reference paths; the selection is
   # a port on the core, not a choice between separate assets.
   loadSource -lib surf -path "$::DIR_PATH/images/GigEthGthUltraScaleCore.dcp"
} else {
   puts "\n\nWARNING: $::DIR_PATH requires Vivado 2016.4 (or later)\n\n"
}
