# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load ruckus files
loadRuckusTcl "$::DIR_PATH/fifo"
loadRuckusTcl "$::DIR_PATH/general"
loadRuckusTcl "$::DIR_PATH/ram"
loadRuckusTcl "$::DIR_PATH/sync"

# Added VHDL-2008 library for floating point DSP support if not supported in Vivado by default yet
if { [VersionCheck 2017.2] <= 0 } {
   # Path to VHDL-2008
   set vhdl2008Path "$::env(XILINX_VIVADO)/data/vhdl/src/ieee_2008"

   # Add the fixed and floating point packages
   loadSource -path "${vhdl2008Path}/fixed_float_types.vhdl"      -lib "ieee" -fileType "VHDL 2008"
   loadSource -path "${vhdl2008Path}/fixed_generic_pkg.vhdl"      -lib "ieee" -fileType "VHDL 2008"
   loadSource -path "${vhdl2008Path}/fixed_generic_pkg-body.vhdl" -lib "ieee" -fileType "VHDL 2008"
   loadSource -path "${vhdl2008Path}/fixed_pkg.vhdl"              -lib "ieee" -fileType "VHDL 2008"
   loadSource -path "${vhdl2008Path}/float_generic_pkg.vhdl"      -lib "ieee" -fileType "VHDL 2008"
   loadSource -path "${vhdl2008Path}/float_generic_pkg-body.vhdl" -lib "ieee" -fileType "VHDL 2008"
   loadSource -path "${vhdl2008Path}/float_pkg.vhdl"              -lib "ieee" -fileType "VHDL 2008"
}