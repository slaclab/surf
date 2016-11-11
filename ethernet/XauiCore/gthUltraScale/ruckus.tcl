# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
loadSource -dir  "$::DIR_PATH/rtl"
# loadIpCore -path "$::DIR_PATH/coregen/XauiGthUltraScale125MHz10GigECore.xci"
# loadIpCore -path "$::DIR_PATH/coregen/XauiGthUltraScale125MHz20GigECore.xci"
# loadIpCore -path "$::DIR_PATH/coregen/XauiGthUltraScale156p25MHz10GigECore.xci"
# loadIpCore -path "$::DIR_PATH/coregen/XauiGthUltraScale156p25MHz20GigECore.xci"
# loadIpCore -path "$::DIR_PATH/coregen/XauiGthUltraScale312p5MHz10GigECore.xci"
# loadIpCore -path "$::DIR_PATH/coregen/XauiGthUltraScale312p5MHz20GigECore.xci"
loadSource -path "$::DIR_PATH/coregen/XauiGthUltraScale125MHz10GigECore.dcp"
loadSource -path "$::DIR_PATH/coregen/XauiGthUltraScale125MHz20GigECore.dcp"
loadSource -path "$::DIR_PATH/coregen/XauiGthUltraScale156p25MHz10GigECore.dcp"
loadSource -path "$::DIR_PATH/coregen/XauiGthUltraScale156p25MHz20GigECore.dcp"
loadSource -path "$::DIR_PATH/coregen/XauiGthUltraScale312p5MHz10GigECore.dcp"
loadSource -path "$::DIR_PATH/coregen/XauiGthUltraScale312p5MHz20GigECore.dcp"
