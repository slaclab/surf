
## Get variables and Custom Procedures
set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
source ${VIVADO_BUILD_DIR}/vivado_hls_env_var_v1.tcl
source ${VIVADO_BUILD_DIR}/vivado_hls_proc_v1.tcl 

## Create a Project
open_project ${PROJECT}_project

## Create a solution
open_solution "solution1"

## Run Simulation
if { ${SIM_FILES} != "" } {
   csim_design
}

## Run C/C++ synth
csynth_design

## Run co-simulation
cosim_design -trace_level none -rtl vhdl -tool auto

## Export the Design
export_design -evaluate vhdl -format syn_dcp

## Close the solution
close_solution

## Close the project
close_project

# ## Copy the IP directory to module source tree
exec rm -rf ${PROJ_DIR}/ip/
exec cp -rf ${OUT_DIR}/${PROJECT}_project/solution1/impl/ip ${PROJ_DIR}/.
exec rm -f [exec ls [glob "${PROJ_DIR}/ip/*.veo"]]
exec cp -f [exec ls [glob "${OUT_DIR}/${PROJECT}_project/solution1/impl/report/vhdl//*.rpt"]] ${PROJ_DIR}/ip/.

## Get the file name and path of the new .dcp file
set filename [exec ls [glob "${PROJ_DIR}/ip/*.dcp"]]

## Print Build complete reminder
puts "\n\n********************************************************"
puts "The new .dcp file is located here:"
puts ${filename}
puts "********************************************************\n\n" 

## IP is ready for use in target firmware project
exit 0