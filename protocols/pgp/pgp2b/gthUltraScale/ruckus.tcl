# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load local source Code and constraints
loadSource   -dir "$::DIR_PATH/rtl/"

loadSource   -path "$::DIR_PATH/ip/PgpGthCore.dcp"
#loadIpCore  -path "$::DIR_PATH/ip/PgpGthCore.xci" 
