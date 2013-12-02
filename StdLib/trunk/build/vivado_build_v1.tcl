
# Get variables
set VIVADO_PROJECT $::env(VIVADO_PROJECT)
set VIVADO_DIR     $::env(VIVADO_DIR)

# Open the project
open_project -quiet ${VIVADO_PROJECT}

# Cleaup runs
reset_run synth_1
reset_run impl_1

# Synthesize
launch_run  synth_1
wait_on_run synth_1

# Target post synthesis script
source ${VIVADO_DIR}/post_synthesis.tcl

# Implement
launch_run -to_step write_bitstream impl_1
wait_on_run impl_1

# Target post route script
source ${VIVADO_DIR}/post_route.tcl

# Close the project
close_project