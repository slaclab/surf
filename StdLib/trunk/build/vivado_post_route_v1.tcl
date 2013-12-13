
# Post-Route Build Script

# Get Environment Variables
set VIVADO_DIR     $::env(VIVADO_DIR)
set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)

# Messages: Change from CRITICAL_WARNING to ERROR
set_msg_config -id {Route 35-39} -new_severity ERROR;# PAR: The design did not meet timing requirements. 

# Target post route script
source ${VIVADO_DIR}/post_route.tcl

# Check for timing and routing errors 
set WNS [get_property STATS.WNS [get_runs impl_1]]
set TNS [get_property STATS.TNS [get_runs impl_1]]
set WHS [get_property STATS.WHS [get_runs impl_1]]
set THS [get_property STATS.THS [get_runs impl_1]]
set TPWS [get_property STATS.TPWS [get_runs impl_1]]
set FAILED_NETS [get_property STATS.FAILED_NETS [get_runs impl_1]]

if { ${WNS}<0.0 || ${TNS}<0.0 \
   || ${WHS}<0.0 || ${THS}<0.0 \
   || ${TPWS}<0.0 || ${FAILED_NETS}>0.0 } {
   source ${VIVADO_BUILD_DIR}/vivado_timing_error_v1.tcl    
}
