# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load ruckus files
loadRuckusTcl "$::DIR_PATH/adc32rf45"
loadRuckusTcl "$::DIR_PATH/ads42lb69"
loadRuckusTcl "$::DIR_PATH/ads54j60"
loadRuckusTcl "$::DIR_PATH/dac7654"
