# Load RUCKUS environment and library
source $::env(RUCKUS_PROC_TCL_QUIET)

# Load ruckus files
loadRuckusTcl "$::DIR_PATH/ad5780"
loadRuckusTcl "$::DIR_PATH/ad9249"
loadRuckusTcl "$::DIR_PATH/ad9467"
loadRuckusTcl "$::DIR_PATH/ad9681"
loadRuckusTcl "$::DIR_PATH/general"
