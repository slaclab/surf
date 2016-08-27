##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

## Get variables and Custom Procedures
set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
source ${VIVADO_BUILD_DIR}/vivado_hls_env_var_v1.tcl
source ${VIVADO_BUILD_DIR}/vivado_hls_proc_v1.tcl 

## Create a Project
open_project ${PROJECT}_project

## Create a solution
open_solution "solution1"

## Get the directives
source ${PROJ_DIR}/directives.tcl

## Run C/C++ simulation testbed
csim_design -clean -O -ldflags ${LDFLAGS} -argv ${ARGV}

## Synthesis C/C++ code into RTL
csynth_design

## Run co-simulation (compares the C/C++ code to the RTL)
if { [info exists ::env(FAST_DCP_GEN)] == 0 } {
   cosim_design -O -ldflags ${LDFLAGS} -argv ${ARGV} -trace_level all -rtl verilog -tool vcs
}

## Export the Design
export_design -evaluate verilog -format syn_dcp 

## Copy the IP directory to module source tree
if { [file isdirectory ${PROJ_DIR}/ip/] != 1 } {
   exec mkdir ${PROJ_DIR}/ip/
}
foreach filePntr [glob -dir ${OUT_DIR}/${PROJECT}_project/solution1/impl/ip *] {
    exec cp -f ${filePntr} ${PROJ_DIR}/ip/.
}
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