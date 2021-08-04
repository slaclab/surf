# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load ruckus files
loadRuckusTcl "$::DIR_PATH/pgp2b"
loadRuckusTcl "$::DIR_PATH/pgp3"
loadRuckusTcl "$::DIR_PATH/pgp4"

loadSource -lib surf -dir "$::DIR_PATH/shared"
