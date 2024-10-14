# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib surf -dir "$::DIR_PATH/rtl"
loadSource -lib surf -dir "$::DIR_PATH/blue-crc"
loadSource -lib surf -dir "$::DIR_PATH/blue-rdma"
loadSource -lib surf -dir "$::DIR_PATH/blue-lib"

# Load mem files
for {set i 0} {$i <= 35} {incr i} {
   add_files -norecurse "$::DIR_PATH/blue-crc/tab/crc_tab_$i.mem"
}
