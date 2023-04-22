# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib surf -dir "$::DIR_PATH/rtl"

# Load Simulation
loadSource -lib surf -sim_only -dir "$::DIR_PATH/tb"

# Check for non-zero Vivado version (in-case non-Vivado project)
if {  $::env(VIVADO_VERSION) > 0.0} {
   loadSource -lib surf -dir "$::DIR_PATH/rtl/7Series"
   loadSource -lib surf -dir "$::DIR_PATH/rtl/UltraScale"
} else {
   loadSource -lib surf -dir "$::DIR_PATH/rtl/dummy"
}
