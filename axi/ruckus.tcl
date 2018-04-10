# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
loadSource -dir "$::DIR_PATH/axi4"
loadSource -dir "$::DIR_PATH/axi-lite"
loadSource -dir "$::DIR_PATH/axi-stream"
loadSource -dir "$::DIR_PATH/bridge"
loadSource -dir "$::DIR_PATH/dma"

# Load Simulation
loadSource -sim_only -dir "$::DIR_PATH/tb"
loadSource -sim_only -dir "$::DIR_PATH/simlink/sim"
