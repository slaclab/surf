############################
# DO NOT EDIT THE CODE BELOW
############################

# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load target's source code and constraints
loadSource      -dir  "$::DIR_PATH/hdl"
loadSource      -dir  "$::DIR_PATH/hdl/transceiver"
loadConstraints -dir  "$::DIR_PATH/hdl"

# loadIpCore -path "$::DIR_PATH/ip/GigEthGthUltraScaleCore.xci"

