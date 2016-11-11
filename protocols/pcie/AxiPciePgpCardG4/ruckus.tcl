# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
loadSource -dir  "$::DIR_PATH/rtl"
# loadIpCore -path "$::DIR_PATH/coregen/AxiPciePgpCardG4IpCore.xci"
loadSource -path "$::DIR_PATH/coregen/AxiPciePgpCardG4IpCore.dcp"
# loadIpCore -path "$::DIR_PATH/coregen/AxiPcieCrossbarIpCore.xci"
loadSource -path "$::DIR_PATH/coregen/AxiPcieCrossbarIpCore.dcp"
# loadIpCore -path "$::DIR_PATH/coregen/MigCore.xci"
loadSource -path "$::DIR_PATH/coregen/MigCore.dcp"
