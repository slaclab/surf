# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Check for version 2018.3 of Vivado (or later)
if { [VersionCheck 2018.3] < 0 } {exit -1}

# Load the wrapper source code
loadSource -dir "$::DIR_PATH/rtl"

# Get the family type
set family [getFpgaFamily]

if { ${family} eq {artix7}  ||
     ${family} eq {kintex7} ||
     ${family} eq {virtex7} ||
     ${family} eq {zynq} } {
   set dirType "7Series"
}

if { ${family} eq {kintexu} ||
     ${family} eq {kintexuplus} ||
     ${family} eq {virtexuplus} ||
     ${family} eq {zynquplus} } {
   set dirType "UltraScale"
}

if { [info exists ::env(USE_XVC_DEBUG)] != 1 || $::env(USE_XVC_DEBUG) == 0 } {
	loadSource -path "$::DIR_PATH/dcp/${dirType}/Stub/images/UdpDebugBridge.dcp"
   set_property IS_GLOBAL_INCLUDE {1} [get_files UdpDebugBridge.dcp]
    
} elseif { $::env(USE_XVC_DEBUG) == -1 } {
   puts "Note: USE_XVC_DEBUG = -1"
   puts "The debug bridge is left as a black box"
   puts "and it is the application's responsibility"
   puts "to define a suitable implementation."
   
} else {
	loadSource -path "$::DIR_PATH/dcp/${dirType}/Impl/images/UdpDebugBridge.dcp"
    set_property IS_GLOBAL_INCLUDE {1} [get_files UdpDebugBridge.dcp]
}
