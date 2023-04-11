# Load RUCKUS environment and library
source $::env(RUCKUS_PROC_TCL_COMBO)

# Load ruckus files
loadRuckusTcl "$::DIR_PATH/ad5780"
loadRuckusTcl "$::DIR_PATH/general"

# Check for non-zero Vivado version (in-case non-Vivado project)
if {  $::env(VIVADO_VERSION) > 0.0} {
   loadRuckusTcl "$::DIR_PATH/ad9467"
   loadRuckusTcl "$::DIR_PATH/ad9249"
   loadRuckusTcl "$::DIR_PATH/ad9681"
}