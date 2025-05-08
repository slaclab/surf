# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Check for non-zero Vivado version (in-case non-Vivado project)
if {  $::env(VIVADO_VERSION) > 0.0} {

   # Load Source Code
   loadSource -lib surf -dir "$::DIR_PATH/core"   -fileType "VHDL 2008"
   loadSource -lib surf -dir "$::DIR_PATH/fixed"  -fileType "VHDL 2008"
   # loadSource -lib surf -dir "$::DIR_PATH/float" -fileType "VHDL 2008"
   loadSource -lib surf -dir "$::DIR_PATH/logic"  -fileType "VHDL 2008"
   loadSource -lib surf -dir "$::DIR_PATH/xilinx" -fileType "VHDL 2008"

   # Load Simulation
   loadSource -lib surf -sim_only -dir "$::DIR_PATH/tb" -fileType "VHDL 2008"

   # These fixed and float point VHDL libraries were not included until Vivado 2020.2 release
   if { $::env(VIVADO_VERSION) < 2020.2} {
      # Add the fixed and floating point packages (maybe this will get include automatically in a later Vivado release)
      set vhdl2008Path "$::env(XILINX_VIVADO)/data/vhdl/src/ieee_2008"
      loadSource -lib surf -path "${vhdl2008Path}/fixed_float_types.vhdl"      -lib "ieee" -fileType "VHDL 2008"
      loadSource -lib surf -path "${vhdl2008Path}/fixed_generic_pkg.vhdl"      -lib "ieee" -fileType "VHDL 2008"
      loadSource -lib surf -path "${vhdl2008Path}/fixed_generic_pkg-body.vhdl" -lib "ieee" -fileType "VHDL 2008"
      loadSource -lib surf -path "${vhdl2008Path}/fixed_pkg.vhdl"              -lib "ieee" -fileType "VHDL 2008"
      loadSource -lib surf -path "${vhdl2008Path}/float_generic_pkg.vhdl"      -lib "ieee" -fileType "VHDL 2008"
      loadSource -lib surf -path "${vhdl2008Path}/float_generic_pkg-body.vhdl" -lib "ieee" -fileType "VHDL 2008"
      loadSource -lib surf -path "${vhdl2008Path}/float_pkg.vhdl"              -lib "ieee" -fileType "VHDL 2008"
   }

} else {
   loadSource -lib surf -fileType "VHDL 2008" -path "$::DIR_PATH/fixed/DspAddSub.vhd"
   loadSource -lib surf -fileType "VHDL 2008" -path "$::DIR_PATH/fixed/DspComparator.vhd"
}
