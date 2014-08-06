
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

## Target specific project setup script
SourceTclFile ${PROJ_DIR}/project.tcl

## Create a solution
open_solution "solution1"

## Set default part
set_part {XC7Z045FFG900-2}

## Set default clock (units of ns)
create_clock -period 10 -name clk

## Set default clock uncertainty (units of ns)
set_clock_uncertainty 0.1

## Configure the RTL to be one-shot encode and reset all logic on reset
config_rtl -encoding onehot -reset all

## Set the data flow to be FIFO (not ping-pong) and default of 512 deep
config_dataflow -default_channel fifo -fifo_depth 512

## Target specific solution setup script
SourceTclFile ${PROJ_DIR}/solution.tcl

## Close the solution
close_solution

## Close the project
close_project
exit 0
