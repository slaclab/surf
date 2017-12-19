# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Get the family type
set family [getFpgaFamily]

if {  ${family} == "artix7" ||
      ${family} == "kintex7" ||
      ${family} == "virtex7" ||
      ${family} == "zynq" } {
                         
   # Load Source Code
   loadSource -dir "$::DIR_PATH/hdl/"

   # Load Simulation
   loadSource -sim_only -dir "$::DIR_PATH/sim/"

}

