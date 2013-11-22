
# Get Environment Variables
set XDC_FILES      $::env(XDC_FILES)
set RTL_FILES      $::env(RTL_FILES)
set CORE_FILES     $::env(CORE_FILES)
set PRJ_PART       $::env(PRJ_PART)
set PROJECT        $::env(PROJECT)
set PROJ_DIR       $::env(PROJ_DIR)
set OUT_DIR        $::env(OUT_DIR)
set TOP_DIR        $::env(TOP_DIR)
set VIVADO_DIR     $::env(VIVADO_DIR)
set VIVADO_PROJECT $::env(VIVADO_PROJECT)
set VIVADO_GUI     $::env(VIVADO_GUI)

# Create a project
create_project -quiet ${VIVADO_PROJECT} -force ${OUT_DIR} -part ${PRJ_PART}

# Add source Files
add_files -quiet -fileset sources_1 ${RTL_FILES}

# Add core Files
if { ${CORE_FILES} != " " } {
   add_files -quiet -fileset sources_1 ${CORE_FILES}
}

# Add XDC FILES
add_files -quiet -fileset constrs_1 ${XDC_FILES}

# Set the top level
set_property top ${PROJECT} [current_fileset]

# Messages Suppression: INFO
set_msg_config -suppress -id {Synth 8-256};# SYNTH: done synthesizing module
set_msg_config -suppress -id {Synth 8-113};# SYNTH: binding component instance 'RTL_Inst' to cell 'PRIMITIVE'
set_msg_config -suppress -id {Synth 8-226};# SYNTH: default block is never used
set_msg_config -suppress -id {Synth 8-312};# SYNTH: "ignoring unsynthesizable construct" due to assert error checking
set_msg_config -suppress -id {Synth 8-4472};# SYNTH: Detected and applied attribute shreg_extract = no

# Messages: Change from WARNING to ERROR
set_msg_config -id {Synth 8-3512} -new_severity {ERROR};# SYNTH: Assigned value in logic is out of range 
set_msg_config -id {Synth 8-3919} -new_severity {ERROR};# SYNTH: Null Assignment in logic

# Messages: Change from WARNING to CRITICAL_WARNING
set_msg_config -id {Vivado 12-508} -new_severity "CRITICAL WARNING";# XDC: No pins matched 

# Messages: Change from CRITICAL_WARNING to ERROR
set_msg_config -id {Vivado 12-1387} -new_severity {ERROR};# XDC: No valid object(s) found 

# Enable implementation steps by default
set_property STEPS.POWER_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.POST_PLACE_POWER_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1] 

# Pre-synthesis Target Script
source ${VIVADO_DIR}/pre_synthesis.tcl

# GUI Branch
if { ${VIVADO_GUI} == "true" } {
   start_gui
} else {

# Synthesize
launch_run  synth_1
wait_on_run synth_1

# Checkpoint
write_checkpoint -quiet -force ${PROJECT}_post_synth.dcp

# Post-synthesis Target Script
source ${VIVADO_DIR}/post_synthesis.tcl

# Implement
launch_run  -to_step write_bitstream impl_1
wait_on_run impl_1

# Save the database after post route
write_checkpoint -quiet -force ${PROJECT}_post_route.dcp

# Post-palce & Route Target Script
source ${VIVADO_DIR}/post_route.tcl

}

