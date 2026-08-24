# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib surf -dir "$::DIR_PATH/rtl"

# Load Vivado-only bundled-data CDC constraints
if { $::env(VIVADO_VERSION) > 0.0 } {
   loadConstraints -path "$::DIR_PATH/xdc/SynchronizerHandshake.xdc"
   set_property SCOPED_TO_REF {SynchronizerHandshake} [get_files {SynchronizerHandshake.xdc}]
}

# Load Simulation
loadSource -lib surf -sim_only -dir "$::DIR_PATH/tb"
