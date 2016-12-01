# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load ruckus files
loadRuckusTcl "$::DIR_PATH/AnalogDevices"
loadRuckusTcl "$::DIR_PATH/Linear"
loadRuckusTcl "$::DIR_PATH/Microchip"
loadRuckusTcl "$::DIR_PATH/Micron"
loadRuckusTcl "$::DIR_PATH/Ti"
loadRuckusTcl "$::DIR_PATH/transceivers"
loadRuckusTcl "$::DIR_PATH/Xilinx"
