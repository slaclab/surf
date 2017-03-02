# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
loadSource -dir  "$::DIR_PATH/rtl/"

# SEM Core XCI is not included by default since very few targets will actually need it.
# Targets that do need it should specify it in their top level ruckus.tcl

# loadIpCore -path "$::DIR_PATH/coregen/SemCore.xci"
# loadSource -path "$::DIR_PATH/coregen/SemMon.dcp"
