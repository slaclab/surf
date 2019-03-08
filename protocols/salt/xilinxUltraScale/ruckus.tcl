# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
if { $::env(VIVADO_VERSION) >= 2016.4 } {

   loadSource -dir  "$::DIR_PATH/rtl"
   
   loadSource -path "$::DIR_PATH/ip/SaltUltraScaleCore.dcp"
   # loadIpCore -path "$::DIR_PATH/ip/SaltUltraScaleCore.xci"
   
   loadSource -path "$::DIR_PATH/images/SaltUltraScaleRxOnly.dcp"
   loadSource -path "$::DIR_PATH/images/SaltUltraScaleTxOnly.dcp"

   # Load Simulation
   loadSource -sim_only -dir "$::DIR_PATH/tb"
   
} else {
   puts "\n\nWARNING: $::DIR_PATH requires Vivado 2016.4 (or later)\n\n"
} 

if { $::env(VIVADO_VERSION) >= 2017.3 } {
   
   if {    ( [info exists ::env(INCLUDE_SALT)]           != 1 || $::env(INCLUDE_SALT)           == 0 )
        && ( [info exists ::env(INCLUDE_ETH_SGMII_LVDS)] != 1 || $::env(INCLUDE_ETH_SGMII_LVDS) == 0 ) } {
      set nop 0
   } else {

      loadConstraints -path "$::DIR_PATH/xdc/SaltUltraScaleCore.xdc"
      set_property PROCESSING_ORDER {EARLY}                [get_files {SaltUltraScaleCore.xdc}]
      set_property SCOPED_TO_REF    {SaltUltraScaleCore}   [get_files {SaltUltraScaleCore.xdc}]
      set_property SCOPED_TO_CELLS  {U0}                   [get_files {SaltUltraScaleCore.xdc}]
   }   
      
   if { [info exists ::env(INCLUDE_SALT_RX_ONLY)] != 1 || $::env(INCLUDE_SALT_RX_ONLY) == 0 } {
      set nop 0
   } else {
      loadConstraints -path "$::DIR_PATH/xdc/SaltUltraScaleRxOnly.xdc"
      set_property PROCESSING_ORDER {EARLY}                [get_files {SaltUltraScaleRxOnly.xdc}]
      set_property SCOPED_TO_REF    {SaltUltraScaleRxOnly} [get_files {SaltUltraScaleRxOnly.xdc}]
      set_property SCOPED_TO_CELLS  {U0}                   [get_files {SaltUltraScaleRxOnly.xdc}]  
   }   
      
   if { [info exists ::env(INCLUDE_SALT_TX_ONLY)] != 1 || $::env(INCLUDE_SALT_TX_ONLY) == 0 } {
      set nop 0
   } else {      
      loadConstraints -path "$::DIR_PATH/xdc/SaltUltraScaleTxOnly.xdc"
      set_property PROCESSING_ORDER {EARLY}                [get_files {SaltUltraScaleTxOnly.xdc}]
      set_property SCOPED_TO_REF    {SaltUltraScaleTxOnly} [get_files {SaltUltraScaleTxOnly.xdc}]
      set_property SCOPED_TO_CELLS  {U0}                   [get_files {SaltUltraScaleTxOnly.xdc}]        
   }
   
}  
