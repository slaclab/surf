# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
loadSource -dir  "$::DIR_PATH/rtl"

loadSource -path "$::DIR_PATH/coregen/XauiGthUltraScale156p25MHz10GigECore.dcp"
# loadIpCore -path "$::DIR_PATH/coregen/XauiGthUltraScale156p25MHz10GigECore.xci"

loadSource -path "$::DIR_PATH/coregen/XauiGthUltraScale312p5MHz10GigECore.dcp"
# loadIpCore -path "$::DIR_PATH/coregen/XauiGthUltraScale312p5MHz10GigECore.xci"
