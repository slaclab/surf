
# Project GUI Run Script

########################################################
## Get variables and Custom Procedures
########################################################
set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl
source -quiet ${VIVADO_BUILD_DIR}/vivado_proc_v1.tcl

# Open the project
open_project -quiet ${VIVADO_PROJECT}
#update_compile_order -fileset sources_1
#update_compile_order -fileset sim_1

# Start the GUI
start_gui
