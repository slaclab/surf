# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Simulation
loadSource -lib surf -sim_only -dir "$::DIR_PATH/tb"

# Check if not GHDL
if {![info exists ::env(GHDLFLAGS)]} {
   # Include VHPI
   loadSource -lib surf -sim_only -dir "$::DIR_PATH/sim"
} else {
   # Exclude VHPI
   loadSource -lib surf -sim_only -dir "$::DIR_PATH/ghdl"
}
