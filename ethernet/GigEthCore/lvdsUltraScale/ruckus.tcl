# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

loadSource -dir "$::DIR_PATH/rtl"
   
if { [info exists ::env(INCLUDE_ETH_SGMII_LVDS)] != 1 || $::env(INCLUDE_ETH_SGMII_LVDS) == 0 } {
   set useEthSgmiiLvds 0
} else {


   loadConstraints -path "$::DIR_PATH/xdc/GigEthLvdsClockMux.xdc"
   set_property SCOPED_TO_REF    GigEthLvdsClockMux [get_files "$::DIR_PATH/xdc/GigEthLvdsClockMux.xdc"]
   set_property PROCESSING_ORDER LATE               [get_files "$::DIR_PATH/xdc/GigEthLvdsClockMux.xdc"]

   loadConstraints -path "$::DIR_PATH/xdc/GigEthLvdsUltraScaleWrapper.xdc"
   set_property SCOPED_TO_REF    GigEthLvdsUltraScaleWrapper [get_files "$::DIR_PATH/xdc/GigEthLvdsUltraScaleWrapper.xdc"]
   set_property PROCESSING_ORDER LATE                        [get_files "$::DIR_PATH/xdc/GigEthLvdsUltraScaleWrapper.xdc"]
   
}
