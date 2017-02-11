############################
# DO NOT EDIT THE CODE BELOW
############################

# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load target's source code and constraints
loadConstraints -dir  "$::DIR_PATH/hdl/"
loadSource      -path "$::DIR_PATH/Version.vhd"
loadSource      -dir  "$::DIR_PATH/hdl/"
loadSource      -dir  "$::DIR_PATH/hdl/sgmii_adapt"
loadSource      -dir  "$::DIR_PATH/hdl/sgmii_lvds_transceiver"
