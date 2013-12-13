
# Post-Route Build Script

# Get Environment Variables
set VIVADO_DIR     $::env(VIVADO_DIR)

# Target post route script
source ${VIVADO_DIR}/post_route.tcl
