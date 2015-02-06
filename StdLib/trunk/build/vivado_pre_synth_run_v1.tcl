
# Pre-Synthesis Run Script

########################################################
## Get variables and Custom Procedures
########################################################
set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl
source -quiet ${VIVADO_BUILD_DIR}/vivado_proc_v1.tcl

# Setup build string
set DATE [exec date]
set USER [exec whoami]
set VERSION [version -short]
set MACHINE [exec uname -m]
set BSTR "${PROJECT}: Vivado v${VERSION} (${MACHINE}) Built ${DATE} by ${USER}"
set SEDS "s|\\(constant BUILD_STAMP_C : string := \\).*|\\1\"${BSTR}\";|"

# Update the timestamp in Version.vhd
exec sed ${SEDS} ${PROJ_DIR}/Version.vhd > ${PROJ_DIR}/Version.new

# Move the file
exec mv ${PROJ_DIR}/Version.new ${PROJ_DIR}/Version.vhd

# Message Filtering Script
source -quiet ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl

# Target specific pre_synth_run script
SourceTclFile ${VIVADO_DIR}/pre_synth_run.tcl
