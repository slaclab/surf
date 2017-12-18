# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
if { $::env(VIVADO_VERSION) >= 2016.4 } {

   loadSource -dir  "$::DIR_PATH/rtl"
   loadSource -path "$::DIR_PATH/coregen/SaltUltraScaleCore.dcp"
   loadSource -path "$::DIR_PATH/rxonly/images/SaltUltraScaleRxOnly.dcp"
   loadSource -path "$::DIR_PATH/txonly/images/SaltUltraScaleTxOnly.dcp"

   # Load Simulation
   loadSource -sim_only -dir "$::DIR_PATH/tb/"
   
} else {
   puts "\n\nWARNING: $::DIR_PATH requires Vivado 2016.4 (or later)\n\n"
}  