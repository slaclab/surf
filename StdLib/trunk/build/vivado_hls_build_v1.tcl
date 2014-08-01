
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
exit 0