# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
loadSource -dir  "$::DIR_PATH/rtl"
# loadIpCore -path "$::DIR_PATH/coregen/TenGigEthGthUltraScale156p25MHzCore.xci"
# loadIpCore -path "$::DIR_PATH/coregen/TenGigEthGthUltraScale312p5MHzCore.xci"
loadSource -path "$::DIR_PATH/coregen/TenGigEthGthUltraScale156p25MHzCore.dcp"
loadSource -path "$::DIR_PATH/coregen/TenGigEthGthUltraScale312p5MHzCore.dcp"
