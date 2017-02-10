# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load ruckus files
loadRuckusTcl "$::DIR_PATH/glink"
loadRuckusTcl "$::DIR_PATH/i2c"
loadRuckusTcl "$::DIR_PATH/jesd204b"
loadRuckusTcl "$::DIR_PATH/pgp"
loadRuckusTcl "$::DIR_PATH/rssi"
loadRuckusTcl "$::DIR_PATH/saci"
loadRuckusTcl "$::DIR_PATH/salt"
loadRuckusTcl "$::DIR_PATH/spi"
loadRuckusTcl "$::DIR_PATH/srp"
loadRuckusTcl "$::DIR_PATH/ssi"
loadRuckusTcl "$::DIR_PATH/ssp"
loadRuckusTcl "$::DIR_PATH/uart"
