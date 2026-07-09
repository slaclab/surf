# Load RUCKUS environment and library
source $::env(RUCKUS_PROC_TCL)

# Check for non-zero Vivado version (in-case non-Vivado project)
if {  $::env(VIVADO_VERSION) > 0.0} {
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
   loadRuckusTcl "$::DIR_PATH/RoCEv2"
} else {
   loadSource -lib surf -path "$::DIR_PATH/EthMacCore/rtl/EthMacPkg.vhd"
}
