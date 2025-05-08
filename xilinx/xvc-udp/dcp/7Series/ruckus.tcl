# Load RUCKUS environment and library
source $::env(RUCKUS_PROC_TCL)

# Must be exactly Vivado v2018.3
if { [VersionCheck 2018.3 "mustBeExact"] < 0 } {exit -1}

# Load submodules' code and constraints
loadRuckusTcl $::env(MODULES)/surf
loadRuckusTcl $::DIR_PATH/../../jtag

# Load target's source code and constraints
loadSource -lib surf -path "$::DIR_PATH/../core/UdpDebugBridgePkg.vhd"
loadSource -lib surf -path "$::DIR_PATH/../core/UdpDebugBridge$::env(VARIANT)Wrapper.vhd"
