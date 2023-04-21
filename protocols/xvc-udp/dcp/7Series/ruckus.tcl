# Load RUCKUS environment and library
source $::env(RUCKUS_PROC_TCL_COMBO)

# Load submodules' code and constraints
loadRuckusTcl $::env(MODULES)/surf

# Load target's source code and constraints
loadSource      -path "$::DIR_PATH/../core/UdpDebugBridgePkg.vhd"
loadSource      -path "$::DIR_PATH/../core/UdpDebugBridge$::env(VARIANT)Wrapper.vhd"
