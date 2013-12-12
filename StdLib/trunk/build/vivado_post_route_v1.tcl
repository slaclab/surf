
# Post-Route Build Script

# Get Environment Variables
set VIVADO_DIR     $::env(VIVADO_DIR)

# Messages: Change from CRITICAL_WARNING to ERROR
set_msg_config -id {Route 35-39} -new_severity ERROR;# PAR: The design did not meet timing requirements. 

# Target post route script
source ${VIVADO_DIR}/post_route.tcl
