# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
loadSource -dir "$::DIR_PATH/rtl/"
loadSource -path "$::DIR_PATH/ip/Pgp3GthUsIp/Pgp3GthUsIp.dcp"
# loadIpCore -path "$::DIR_PATH/ip/Pgp3GthUsIp/Pgp3GthUsIp.xci"

# Load Simulation
#loadSource -sim_only -dir "$::DIR_PATH/tb/"
