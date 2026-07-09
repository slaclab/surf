# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadRuckusTcl "$::DIR_PATH/axi4"
loadRuckusTcl "$::DIR_PATH/axi-lite"
loadRuckusTcl "$::DIR_PATH/axi-stream"
loadRuckusTcl "$::DIR_PATH/bridge"
loadRuckusTcl "$::DIR_PATH/dma"
loadRuckusTcl "$::DIR_PATH/simlink"
