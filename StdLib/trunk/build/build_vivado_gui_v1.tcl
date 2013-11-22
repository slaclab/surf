
# Get Environment Variables
set SOURCE_FILE $::env(SOURCE_FILE)
set XDC_FILES   $::env(XDC_FILES)
set PRJ_PART    $::env(PRJ_PART)
set PROJECT     $::env(PROJECT)
set PROJ_DIR    $::env(PROJ_DIR)
set OUT_DIR     $::env(OUT_DIR)
set TOP_DIR     $::env(TOP_DIR)
set VIVADO_DIR  $::env(VIVADO_DIR)

# Setup Args
set SYNTH_ARGS ""
set OPT_ARGS   ""
set PLACE_ARGS ""
set ROUTE_ARGS ""

# Create a project
create_project -quiet ${PROJECT}_project -force ${OUT_DIR} -part ${PRJ_PART}

# Run source file commands
source ${SOURCE_FILE}

# Read XDC FILES
read_xdc ${XDC_FILES}

# Refresh the GUI with the source files
import_files -force
update_compile_order -fileset sources_1
set_property top ${PROJECT} [current_fileset]

# Pre-synthesis Target Script
source ${VIVADO_DIR}/pre_synthesis.tcl

# Message Suppression: INFO: Synthesizing Module messages
set_msg_config -suppress -id {Synth 8-256}
set_msg_config -suppress -id {Synth 8-113}
set_msg_config -suppress -id {Synth 8-226}
set_msg_config -suppress -id {Synth 8-4472}

# Message Suppression: WARNING: "ignoring unsynthesizable construct" due to assert error checking
set_msg_config -suppress -id {Synth 8-312}

# Messages: Change from WARNING to ERROR
set_msg_config -id {Vivado 12-508} -new_severity {ERROR}

# Messages: Change from CRITICAL_WARNING to ERROR
set_msg_config -id {Vivado 12-1387} -new_severity {ERROR}

# Start GUI
start_gui