# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib surf -dir "$::DIR_PATH/rtl"

loadSource -lib surf -dir "$::DIR_PATH/blue-rdma" -fileType "VHDL 2008"
loadSource -lib surf -dir "$::DIR_PATH/blue-lib"  -fileType "VHDL 2008"
