# Load RUCKUS environment and library
source $::env(RUCKUS_PROC_TCL_QUIET)

# Load ruckus files
loadRuckusTcl "$::DIR_PATH/EthMacCore"
loadRuckusTcl "$::DIR_PATH/GigEthCore"
loadRuckusTcl "$::DIR_PATH/IpV4Engine"
loadRuckusTcl "$::DIR_PATH/RawEthFramer"
loadRuckusTcl "$::DIR_PATH/TenGigEthCore"
loadRuckusTcl "$::DIR_PATH/UdpEngine"
loadRuckusTcl "$::DIR_PATH/XauiCore"
loadRuckusTcl "$::DIR_PATH/XlauiCore"
loadRuckusTcl "$::DIR_PATH/Caui4Core"
