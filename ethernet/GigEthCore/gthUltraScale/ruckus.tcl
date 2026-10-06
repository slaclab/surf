# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
if { $::env(VIVADO_VERSION) >= 2016.4 } {
   # One PHY adapter selects fabric/dedicated reference via USE_GTREFCLK_G.
   loadSource -lib surf -dir  "$::DIR_PATH/rtl"
   loadSource -lib surf -path "$::DIR_PATH/images/GigEthGthUltraScaleCore.dcp"
} else {
   puts "\n\nWARNING: $::DIR_PATH requires Vivado 2016.4 (or later)\n\n"
}

# USE_GTREFCLK_G=true still needs compatible IP from surf-dcp-targets and a
# normal source-manifest entry. Only the legacy checkpoint is supplied here.
