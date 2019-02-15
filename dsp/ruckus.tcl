# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
loadSource -dir "$::DIR_PATH/core"  -fileType "VHDL 2008"
loadSource -dir "$::DIR_PATH/fixed" -fileType "VHDL 2008"
loadSource -dir "$::DIR_PATH/logic" -fileType "VHDL 2008"
# loadSource -dir "$::DIR_PATH/float" -fileType "VHDL 2008"

# Load Simulation
loadSource -sim_only -dir "$::DIR_PATH/tb" -fileType "VHDL 2008"

# Add the fixed and floating point packages (maybe this will get include automatically in a later Vivado release)
set vhdl2008Path "$::env(XILINX_VIVADO)/data/vhdl/src/ieee_2008"
loadSource -path "${vhdl2008Path}/fixed_float_types.vhdl"      -lib "ieee" -fileType "VHDL 2008"
loadSource -path "${vhdl2008Path}/fixed_generic_pkg.vhdl"      -lib "ieee" -fileType "VHDL 2008"
loadSource -path "${vhdl2008Path}/fixed_generic_pkg-body.vhdl" -lib "ieee" -fileType "VHDL 2008"
loadSource -path "${vhdl2008Path}/fixed_pkg.vhdl"              -lib "ieee" -fileType "VHDL 2008"
loadSource -path "${vhdl2008Path}/float_generic_pkg.vhdl"      -lib "ieee" -fileType "VHDL 2008"
loadSource -path "${vhdl2008Path}/float_generic_pkg-body.vhdl" -lib "ieee" -fileType "VHDL 2008"
loadSource -path "${vhdl2008Path}/float_pkg.vhdl"              -lib "ieee" -fileType "VHDL 2008"
