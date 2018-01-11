# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load ruckus files
loadRuckusTcl "$::DIR_PATH/pgp2b"
loadRuckusTcl "$::DIR_PATH/pgp3"
