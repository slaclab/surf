
# Pre-Synthesis Build Script

# Get Environment Variables
set PROJ_DIR $::env(PROJ_DIR)

# Setup build string
set DATE [exec date]
set USER [exec whoami]
set BSTR "Built $DATE by $USER"
set SEDS "s|\\(constant BUILD_STAMP_C : string := \\).*|\\1\"${BSTR}\";|"

# Update the timestamp in Version.vhd
exec sed ${SEDS} ${PROJ_DIR}/Version.vhd > ${PROJ_DIR}/Version.new

# Move the file
exec mv ${PROJ_DIR}/Version.new ${PROJ_DIR}/Version.vhd

