# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

loadSource      -dir "$::DIR_PATH/rtl"

loadConstraints -path "$::DIR_PATH/rtl/GigEthLvdsClockMux.xdc"
set_property SCOPED_TO_REF    GigEthLvdsClockMux [get_files "$::DIR_PATH/rtl/GigEthLvdsClockMux.xdc"]
set_property PROCESSING_ORDER LATE               [get_files "$::DIR_PATH/rtl/GigEthLvdsClockMux.xdc"]

loadConstraints -path "$::DIR_PATH/rtl/GigEthLvdsUltraScaleWrapper.xdc"
set_property SCOPED_TO_REF    GigEthLvdsUltraScaleWrapper [get_files "$::DIR_PATH/rtl/GigEthLvdsUltraScaleWrapper.xdc"]
set_property PROCESSING_ORDER LATE                        [get_files "$::DIR_PATH/rtl/GigEthLvdsUltraScaleWrapper.xdc"]
