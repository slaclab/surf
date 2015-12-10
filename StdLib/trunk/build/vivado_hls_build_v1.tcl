
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
if { [info exists ::env(FAST_DCP_GEN)] == 0 } {
   cosim_design -ldflags ${LDFLAGS} -argv ${ARGV} -trace_level all -rtl verilog -tool vcs
}

## Export the Design
export_design -evaluate verilog -format syn_dcp 

## Copy the IP directory to module source tree
exec rm -rf ${PROJ_DIR}/ip/
exec cp -rf ${OUT_DIR}/${PROJECT}_project/solution1/impl/ip ${PROJ_DIR}/.

exec rm -f  [exec ls [glob "${PROJ_DIR}/ip/*.veo"]]
exec cp -f  [exec ls [glob "${OUT_DIR}/${PROJECT}_project/solution1/impl/report/verilog/*.rpt"]] ${PROJ_DIR}/ip/.

## Export the Design
export_design -evaluate verilog -format ip_catalog

## Copy the driver to module source tree
set DRIVER ${OUT_DIR}/${PROJECT}_project/solution1/impl/ip/drivers
if { [file exist  ${DRIVER}] } {
   set DRIVER ${DRIVER}/[exec ls ${DRIVER}]/src
   set DRIVER [glob ${DRIVER}/*_hw.h]
   exec cp -f ${DRIVER} ${PROJ_DIR}/ip/.
}

## Close current solution
close_solution

## Close the project
close_project
exit 0