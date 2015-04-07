set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl
source -quiet ${VIVADO_BUILD_DIR}/vivado_proc_v1.tcl

## Set the top level file
set_property top XauiGth7Core_block [current_fileset]

## Set the Secure IP library 
set_property library xaui_v12_1 [get_files ${PROJ_DIR}/hdl/xaui_v12_1_rfs.vhd]

