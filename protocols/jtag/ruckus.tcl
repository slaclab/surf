# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

if { [info exists ::env(USE_XVC_DEBUG)] != 1 || $::env(USE_XVC_DEBUG) == 0 } {

	loadSource -path  "$::DIR_PATH/rtl/AxisDebugBridge.vhd"
	loadSource -path  "$::DIR_PATH/rtl/AxisDebugBridgeStub.vhd"

} else {

# Create Debug Bridge IP -- but only if it doesn't exist yet
# which can happen if this is re-run.
	if { [llength [get_ips DebugBridgeJtag]] == 0 } {
    	create_ip -name debug_bridge -vendor xilinx.com -library ip -module_name DebugBridgeJtag
		# C_DEBUG_MODE selects JTAG <-> BSCAN mode
    	set_property -dict [list CONFIG.C_DEBUG_MODE {4}] [get_ips DebugBridgeJtag]
	}

	foreach f {
		AxisDebugBridge.vhd
		AxisDebugBridgeImpl.vhd
		AxisToJtag.vhd
		AxisToJtagCore.vhd
		AxisToJtagPkg.vhd
		AxiStreamSelector.vhd
		JtagSerDesCore.vhd
	} {
		loadSource -path  "$::DIR_PATH/rtl/$f"
	}

}
