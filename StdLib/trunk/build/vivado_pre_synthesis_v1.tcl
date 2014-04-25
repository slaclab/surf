
# Pre-Synthesis Build Script

# Get variables
set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl

# Load Custom Procedures
source -quiet ${VIVADO_BUILD_DIR}/vivado_proc_v1.tcl

# Setup build string
set DATE [exec date]
set USER [exec whoami]
set BSTR "Built $DATE by $USER"
set SEDS "s|\\(constant BUILD_STAMP_C : string := \\).*|\\1\"${BSTR}\";|"

# Update the timestamp in Version.vhd
exec sed ${SEDS} ${PROJ_DIR}/Version.vhd > ${PROJ_DIR}/Version.new

# Move the file
exec mv ${PROJ_DIR}/Version.new ${PROJ_DIR}/Version.vhd

# Message Filtering Script
source -quiet ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl

# Target pre synthesis script
#source ${VIVADO_DIR}/pre_synthesis.tcl
