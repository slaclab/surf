# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
loadSource -lib surf -dir  "$::DIR_PATH/rtl"
loadSource -lib surf -dir  "$::DIR_PATH/rtl/inferred"
loadSource -lib surf -path "$::DIR_PATH/rtl/dummy/FifoAlteraMfDummy.vhd"

# Load Simulation
loadSource -lib surf -sim_only -dir "$::DIR_PATH/tb"

# Case on the Vivado Version
if { $::env(VIVADO_VERSION) < 2019.1 } {
   # Load a dummy module
   loadSource -lib surf -path "$::DIR_PATH/rtl/dummy/FifoXpmDummy.vhd"
   puts "\n\nWARNING: surf.base.fifo.xpm requires Vivado 2019.1 (or later)\n\n"
} else {
   # Load the wrapper
   loadSource -lib surf -path "$::DIR_PATH/rtl/xilinx/FifoXpm.vhd"
}
