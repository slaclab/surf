
## Get variables and Custom Procedures
set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
source ${VIVADO_BUILD_DIR}/vivado_hls_env_var_v1.tcl
source ${VIVADO_BUILD_DIR}/vivado_hls_proc_v1.tcl 

## Create a Project
open_project ${PROJECT}_project

## Create a solution
open_solution "solution1"

## Run C/C++ simulation testbed
csim_design -clean -ldflags ${LDFLAGS} -argv ${ARGV}

## Synthesis C/C++ code into RTL
csynth_design

## Run co-simulation (compares the C/C++ code to the RTL)
cosim_design -ldflags ${LDFLAGS} -argv ${ARGV} -trace_level all -rtl vhdl -tool vcs

## Export the Design
export_design -evaluate vhdl -format syn_dcp

## Close the solution
close_solution

## Close the project
close_project
exit 0