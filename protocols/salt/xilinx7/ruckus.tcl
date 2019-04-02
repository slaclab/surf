# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
if { $::env(VIVADO_VERSION) >= 2016.4 } {

   loadSource -dir  "$::DIR_PATH/rtl"

   # loadIpCore -path "$::DIR_PATH/ip/Salt7SeriesCore.xci"
   loadSource -path "$::DIR_PATH/ip/Salt7SeriesCore.dcp"

   # Load Simulation
   loadSource -sim_only -dir "$::DIR_PATH/tb"
   
} else {
   puts "\n\nWARNING: $::DIR_PATH requires Vivado 2016.4 (or later)\n\n"
}      
   
