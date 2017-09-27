# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
loadSource -dir "$::DIR_PATH/rtl"
loadSource -dir "$::DIR_PATH/AxiStreamDmaV1"
loadSource -dir "$::DIR_PATH/AxiStreamDmaV2"

# Load Simulation
loadSource -sim_only -dir "$::DIR_PATH/tb/"
loadSource -sim_only -dir "$::DIR_PATH/simlink/sim"
