# Load RUCKUS environment and library
source $::env(RUCKUS_PROC_TCL)
# Check for non-zero Vivado version (in-case non-Vivado project)
if {  $::env(VIVADO_VERSION) > 0.0} {

   # Load target's source code and constraints
   loadSource -lib surf -sim_only -dir "$::DIR_PATH/tb"

   # Vivado Verilog bug fix (https://jira.slac.stanford.edu/browse/ESCORE-261)
   set_property USED_IN {implementation} [get_files {ddr3.v}]

   # Note: Don't forget to add a SystemVerilog (.sv) file to your
   # project to define the type of DDR3 memory that you are simulating
   #######################################
   # Example: ddr3_sdram_model_wrapper.sv
   #######################################
   # `define den4096Mb
   # `define sg125
   # `define x8
   # `define MAX_MEM
   # `include "ddr3.v"
   #######################################
}
