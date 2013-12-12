
# Project Batch-Mode Run Script

# Get variables
set VIVADO_PROJECT   $::env(VIVADO_PROJECT)
set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
set VIVADO_DIR       $::env(VIVADO_DIR)
set CORE_FILES       $::env(CORE_FILES)

# Open the project
open_project -quiet ${VIVADO_PROJECT}

# Cleaup runs
reset_run synth_1
reset_run impl_1

# Re-generate all IP cores' output files
generate_target all [get_ips *]

# Synthesize
launch_run  synth_1
wait_on_run synth_1

# Target post synthesis script
source ${VIVADO_BUILD_DIR}/vivado_post_synthesis_v1.tcl

# Implement
launch_run -to_step write_bitstream impl_1
wait_on_run impl_1

# Target post route script
source ${VIVADO_DIR}/post_route.tcl

# Close the project
close_project
