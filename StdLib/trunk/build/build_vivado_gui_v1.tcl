
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

# Start GUI
start_gui