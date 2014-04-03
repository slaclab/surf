
# Project Batch-Mode Build Script

# Get variables
set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl

# Load Custom Procedures
source -quiet ${VIVADO_BUILD_DIR}/vivado_proc_v1.tcl

# Create a Project
create_project ${VIVADO_PROJECT} -force ${OUT_DIR} -part ${PRJ_PART}

# Message Filtering Script
source -quiet ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl

# Setup project properties
source ${VIVADO_BUILD_DIR}/vivado_properties_v1.tcl

# Target specific project setup script
source ${VIVADO_DIR}/project_setup.tcl

# Close the project
close_project
