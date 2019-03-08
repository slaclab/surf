# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load target's source code and constraints
loadSource -sim_only -dir "$::DIR_PATH/tb"

# Set the top-level DDR module as Verilog
set_property FILE_TYPE {Verilog Header} [get_files {arch_defines.v}]
set_property FILE_TYPE {Verilog Header} [get_files {arch_package.sv}]
set_property FILE_TYPE {Verilog Header} [get_files {ddr4_model.sv}]
set_property FILE_TYPE {Verilog Header} [get_files {interface.sv}]
set_property FILE_TYPE {Verilog Header} [get_files {MemoryArray.sv}]
set_property FILE_TYPE {Verilog Header} [get_files {proj_package.sv}]
set_property FILE_TYPE {Verilog Header} [get_files {StateTable.sv}]
set_property FILE_TYPE {Verilog Header} [get_files {StateTableCore.sv}]
set_property FILE_TYPE {Verilog Header} [get_files {timing_tasks.sv}]

# Note: Don't forget to add a SystemVerilog (.sv) file to your 
# project to define the type of DDR4 memory that you are simulating
#######################################
# Example: ddr4_sdram_model_wrapper.sv
#######################################
#`define DDR4_4G_X16 
#`define DDR4_750_Timing
#// Added define SILENT to avoid timeset setting display messages in transcript
#`define SILENT
#`define FIXED_2666
#
#`include "arch_package.sv"
#`include "proj_package.sv"
#`include "interface.sv"
#`include "ddr4_model.sv"
#######################################