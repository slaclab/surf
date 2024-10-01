# Load RUCKUS environment and library
source $::env(RUCKUS_PROC_TCL)

# Load ruckus files
loadRuckusTcl "$::DIR_PATH/pgp3"
loadRuckusTcl "$::DIR_PATH/pgp4"
loadSource -lib surf -dir "$::DIR_PATH/shared"

# Check for non-zero Vivado version (in-case non-Vivado project)
if {  $::env(VIVADO_VERSION) > 0.0} {
   # Load ruckus files
   loadRuckusTcl "$::DIR_PATH/pgp2b"
   loadRuckusTcl "$::DIR_PATH/pgp2fc"
   loadSource -lib surf -dir "$::DIR_PATH/shared/xilinx"
}
