# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load ruckus files
loadRuckusTcl "$::DIR_PATH/adc16dx370"
loadRuckusTcl "$::DIR_PATH/ads42lb69"
loadRuckusTcl "$::DIR_PATH/cdcm6208"
loadRuckusTcl "$::DIR_PATH/dac38j84"
loadRuckusTcl "$::DIR_PATH/dac7654"
loadRuckusTcl "$::DIR_PATH/lmk04828"
