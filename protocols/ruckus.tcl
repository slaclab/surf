# Load RUCKUS environment and library
source $::env(RUCKUS_QUIET_FLAG) $::env(RUCKUS_PROC_TCL)

# Load ruckus files
loadRuckusTcl "$::DIR_PATH/batcher"
loadRuckusTcl "$::DIR_PATH/hamming-ecc"
loadRuckusTcl "$::DIR_PATH/i2c"
loadRuckusTcl "$::DIR_PATH/jesd204b"
loadRuckusTcl "$::DIR_PATH/jtag"
loadRuckusTcl "$::DIR_PATH/line-codes"
loadRuckusTcl "$::DIR_PATH/mdio"
loadRuckusTcl "$::DIR_PATH/packetizer"
loadRuckusTcl "$::DIR_PATH/rssi"
loadRuckusTcl "$::DIR_PATH/saci"
loadRuckusTcl "$::DIR_PATH/srp"
loadRuckusTcl "$::DIR_PATH/ssi"
loadRuckusTcl "$::DIR_PATH/ssp"
loadRuckusTcl "$::DIR_PATH/sugoi"
loadRuckusTcl "$::DIR_PATH/uart"


# Check for non-zero Vivado version (in-case non-Vivado project)
if {  $::env(VIVADO_VERSION) > 0.0} {
   loadRuckusTcl "$::DIR_PATH/clink"
   loadRuckusTcl "$::DIR_PATH/coaxpress"
   loadRuckusTcl "$::DIR_PATH/glink"
   loadRuckusTcl "$::DIR_PATH/htsp"
   loadRuckusTcl "$::DIR_PATH/pgp"
   loadRuckusTcl "$::DIR_PATH/pmbus"
   loadRuckusTcl "$::DIR_PATH/salt"
   loadRuckusTcl "$::DIR_PATH/spi"
   loadRuckusTcl "$::DIR_PATH/xvc-udp"
}