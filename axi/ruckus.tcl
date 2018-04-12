# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
loadRuckusTcl "$::DIR_PATH/axi4"
loadRuckusTcl "$::DIR_PATH/axi-lite"
loadRuckusTcl "$::DIR_PATH/axi-stream"
loadRuckusTcl "$::DIR_PATH/bridge"
loadRuckusTcl "$::DIR_PATH/dma"

# Load Simulation
loadSource -sim_only -dir "$::DIR_PATH/simlink/sim"
