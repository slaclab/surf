# Load RUCKUS environment and library
source $::env(RUCKUS_PROC_TCL)

# Load submodules' code and constraints
loadRuckusTcl $::env(MODULES)/surf
loadRuckusTcl $::DIR_PATH/../../jtag

# Load target's source code and constraints
loadSource -lib surf -path "$::DIR_PATH/../core/UdpDebugBridgePkg.vhd"
loadSource -lib surf -path "$::DIR_PATH/../core/UdpDebugBridge$::env(VARIANT)Wrapper.vhd"
