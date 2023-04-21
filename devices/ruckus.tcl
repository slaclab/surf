# Load RUCKUS environment and library
source $::env(RUCKUS_PROC_TCL_COMBO)

# Load ruckus files
loadRuckusTcl "$::DIR_PATH/Marvell"
loadRuckusTcl "$::DIR_PATH/Maxim"
loadRuckusTcl "$::DIR_PATH/Microchip"

# Check for non-zero Vivado version (in-case non-Vivado project)
if {  $::env(VIVADO_VERSION) > 0.0} {
   loadRuckusTcl "$::DIR_PATH/Amphenol"
   loadRuckusTcl "$::DIR_PATH/AnalogDevices"
   loadRuckusTcl "$::DIR_PATH/Linear"
   loadRuckusTcl "$::DIR_PATH/Micron"
   loadRuckusTcl "$::DIR_PATH/Nxp"
   loadRuckusTcl "$::DIR_PATH/Silabs"
   loadRuckusTcl "$::DIR_PATH/Ti"
   loadRuckusTcl "$::DIR_PATH/transceivers"
   loadRuckusTcl "$::DIR_PATH/Xilinx"
}
