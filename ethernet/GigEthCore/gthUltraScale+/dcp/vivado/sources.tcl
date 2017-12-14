set RUCKUS_DIR $::env(RUCKUS_DIR)
source -quiet ${RUCKUS_DIR}/vivado_env_var.tcl
source -quiet ${RUCKUS_DIR}/vivado_proc.tcl

## Set the top level file
set_property top GigEthGthUltraScaleCore [current_fileset]

## Set the Secure IP library 
set_property library gig_ethernet_pcs_pma_v16_1_1 [get_files ${PROJ_DIR}/hdl/gig_ethernet_pcs_pma_v16_1_rfs.vhd]

