# Load RUCKUS environment and library
source $::env(RUCKUS_QUIET_FLAG) $::env(RUCKUS_PROC_TCL)

# Load ruckus files
loadRuckusTcl "$::DIR_PATH/pgp2b"
loadRuckusTcl "$::DIR_PATH/pgp2fc"
loadRuckusTcl "$::DIR_PATH/pgp3"
loadRuckusTcl "$::DIR_PATH/pgp4"

loadSource -lib surf -dir "$::DIR_PATH/shared"
