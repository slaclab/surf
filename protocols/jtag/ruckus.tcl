# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

if { ($::env(VIVADO_VERSION) >= 2016.4) && ([isVersal] != true) } {

   # Create Debug Bridge IP -- but only if it doesn't exist yet
   # which can happen if this is re-run.
   if { [llength [get_ips DebugBridgeJtag]] == 0 } {
         create_ip -name debug_bridge -vendor xilinx.com -library ip -module_name DebugBridgeJtag
      # C_DEBUG_MODE selects JTAG <-> BSCAN mode
         set_property -dict [list CONFIG.C_DEBUG_MODE {4}] [get_ips DebugBridgeJtag]
   }

   loadSource -lib surf -dir  "$::DIR_PATH/rtl"

}