# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL_COMBO)

# Load Source Code
loadRuckusTcl "$::DIR_PATH/axi4"
loadRuckusTcl "$::DIR_PATH/axi-lite"
loadRuckusTcl "$::DIR_PATH/axi-stream"
loadRuckusTcl "$::DIR_PATH/bridge"
loadRuckusTcl "$::DIR_PATH/dma"

# Load Simulation
loadSource -lib surf -sim_only -dir "$::DIR_PATH/simlink/sim"
