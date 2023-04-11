# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL_COMBO)

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
   # Check for non-zero Vivado version (in-case non-Vivado project)
   if {  $::env(VIVADO_VERSION) > 0.0} {
      puts "\n\nWARNING: surf.base.fifo.xpm requires Vivado 2019.1 (or later)\n\n"
   }
} else {
   # Load the wrapper
   loadSource -lib surf -path "$::DIR_PATH/rtl/xilinx/FifoXpm.vhd"
}

# https://support.xilinx.com/s/article/67815?language=en_US
if { $::env(VIVADO_VERSION) >= 2021.2 } {
   set_property XPM_LIBRARIES XPM_MEMORY [current_project]
}
