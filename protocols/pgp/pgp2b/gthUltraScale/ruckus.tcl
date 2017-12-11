# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load local source Code and constraints
loadSource   -dir "$::DIR_PATH/rtl/"

#loadSource   -path "$::DIR_PATH/ip/PgpGthCore.dcp"
loadIpCore  -path "$::DIR_PATH/ip/PgpGthCore.xci" 
#loadConstraints -path "$::DIR_PATH/rtl/Pgp2bGthUltra.xdc"

#set_property PROCESSING_ORDER {LATE} [get_files {Pgp2bGthUltra.xdc}]
#set_property SCOPED_TO_REF {PgpGthCore} [get_files {Pgp2bGthUltra.xdc}]
#set_property SCOPED_TO_CELLS {inst} [get_files {Pgp2bGthUltra.xdc}]
