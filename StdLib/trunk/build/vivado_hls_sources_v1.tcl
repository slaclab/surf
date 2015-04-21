
## Get variables and Custom Procedures
set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
source ${VIVADO_BUILD_DIR}/vivado_hls_env_var_v1.tcl
source ${VIVADO_BUILD_DIR}/vivado_hls_proc_v1.tcl

## Create a Project
open_project ${PROJECT}_project

## Set the top level module
set_top ${PROJECT}

## Add sources 
source ${PROJ_DIR}/sources.tcl

## Create a solution
open_solution "solution1"

## Setup the csim ldflags
csim_design -setup -ldflags ${LDFLAGS} -argv ${ARGV}

## Target specific solution setup script
source ${PROJ_DIR}/solution.tcl

## Close the solution
close_solution

## Close the project
close_project
exit 0
