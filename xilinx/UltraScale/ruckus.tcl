# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL_COMBO)

# Load the Core
loadRuckusTcl "$::DIR_PATH/general"
loadRuckusTcl "$::DIR_PATH/clocking"
loadRuckusTcl "$::DIR_PATH/gthUs"
