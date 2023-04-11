# Load RUCKUS environment and library
source $::env(RUCKUS_PROC_TCL_COMBO)

# Check for non-zero Vivado version (in-case non-Vivado project)
if {  $::env(VIVADO_VERSION) > 0.0} {
   # Load ruckus files
   loadRuckusTcl "$::DIR_PATH/Sc18Is602"
}
