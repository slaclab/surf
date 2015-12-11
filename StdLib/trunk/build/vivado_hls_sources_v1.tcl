
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
csim_design -O -setup -ldflags ${LDFLAGS} -argv ${ARGV}

## Target specific solution setup script
source ${PROJ_DIR}/solution.tcl

## Close the solution
close_solution

## Close the project
close_project

## Check if directives.tcl exists in the source tree
if { [file exists  ${PROJ_DIR}/directives.tcl] == 0 } {
   exec echo  > ${PROJ_DIR}/directives.tcl
}

## Check if solution1.directive exists in the source tree
if { [file exists  ${PROJ_DIR}/solution1.directive] == 0 } {
   exec echo  > ${PROJ_DIR}/solution1.directive
}

## Make symbolic links for the directives.tcl file
if { [file exists  ${OUT_DIR}/${PROJECT}_project/solution1/directives.tcl] == 0 } {
   exec ln -s  ${PROJ_DIR}/directives.tcl ${OUT_DIR}/${PROJECT}_project/solution1/directives.tcl
}

## Make symbolic links for the solution1.directive file
if { [file exists  ${OUT_DIR}/${PROJECT}_project/solution1/solution1.directive] == 0 } {
   exec ln -s  ${PROJ_DIR}/solution1.directive ${OUT_DIR}/${PROJECT}_project/solution1/solution1.directive
}

exit 0
