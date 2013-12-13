
# Project GUI Run Script

# Get variables
set XDC_FILES        $::env(XDC_FILES)
set RTL_FILES        $::env(RTL_FILES)
set CORE_FILES       $::env(CORE_FILES)
set PRJ_PART         $::env(PRJ_PART)
set PROJECT          $::env(PROJECT)
set OUT_DIR          $::env(OUT_DIR)
set VIVADO_DIR       $::env(VIVADO_DIR)
set VIVADO_PROJECT   $::env(VIVADO_PROJECT)
set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)

# Load Custom Procedures
source ${VIVADO_BUILD_DIR}/vivado_proc_v1.tcl

# Open the project
open_project -quiet ${VIVADO_PROJECT}
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# Start the GUI
start_gui
