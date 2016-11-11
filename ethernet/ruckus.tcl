# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load ruckus files
loadRuckusTcl "$::DIR_PATH/EthMacCore"
loadRuckusTcl "$::DIR_PATH/GigEthCore"
loadRuckusTcl "$::DIR_PATH/IpV4Engine"
loadRuckusTcl "$::DIR_PATH/RawEthFramer"
loadRuckusTcl "$::DIR_PATH/TenGigEthCore"
loadRuckusTcl "$::DIR_PATH/UdpEngine"
loadRuckusTcl "$::DIR_PATH/XauiCore"
loadRuckusTcl "$::DIR_PATH/XlauiCore"
