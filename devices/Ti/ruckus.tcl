# Load RUCKUS environment and library
source $::env(RUCKUS_PROC_TCL_COMBO)

# Check for non-zero Vivado version (in-case non-Vivado project)
if {  $::env(VIVADO_VERSION) > 0.0} {
   # Load ruckus files
   loadRuckusTcl "$::DIR_PATH/adc32rf45"
   loadRuckusTcl "$::DIR_PATH/ads42lb69"
   loadRuckusTcl "$::DIR_PATH/ads54j60"
   loadRuckusTcl "$::DIR_PATH/dac7654"
   loadRuckusTcl "$::DIR_PATH/dp83867"
   loadRuckusTcl "$::DIR_PATH/Lmk048Base"
}
