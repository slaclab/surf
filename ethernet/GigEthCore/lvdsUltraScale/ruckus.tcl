# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

loadSource      -dir "$::DIR_PATH/rtl"

loadConstraints -path "$::DIR_PATH/rtl/GigEthLVDSClockMux.xdc"
set_property SCOPED_TO_REF    GigEthLVDSClockMux [get_files "$::DIR_PATH/rtl/GigEthLVDSClockMux.xdc"]
set_property PROCESSING_ORDER LATE               [get_files "$::DIR_PATH/rtl/GigEthLVDSClockMux.xdc"]

loadConstraints -path "$::DIR_PATH/rtl/GigEthLVDSUltraScaleWrapper.xdc"
set_property SCOPED_TO_REF    GigEthLVDSUltraScaleWrapper [get_files "$::DIR_PATH/rtl/GigEthLVDSUltraScaleWrapper.xdc"]
set_property PROCESSING_ORDER LATE                        [get_files "$::DIR_PATH/rtl/GigEthLVDSUltraScaleWrapper.xdc"]
