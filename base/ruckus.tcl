# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load ruckus files
loadRuckusTcl "$::DIR_PATH/fifo"
loadRuckusTcl "$::DIR_PATH/general"
loadRuckusTcl "$::DIR_PATH/ram"
loadRuckusTcl "$::DIR_PATH/sync"

# Added VHDL-2008 library for floating point DSP support if not supported in Vivado yet
if { [VersionCheck 2017.2] <= 0 } {
   loadSource -path "$::DIR_PATH/vhdl-libs/ieee2008/fixed_float_types.vhdl"      -lib "ieee" -fileType "VHDL 2008"
   loadSource -path "$::DIR_PATH/vhdl-libs/ieee2008/fixed_generic_pkg.vhdl"      -lib "ieee" -fileType "VHDL 2008"
   loadSource -path "$::DIR_PATH/vhdl-libs/ieee2008/fixed_generic_pkg-body.vhdl" -lib "ieee" -fileType "VHDL 2008"
   loadSource -path "$::DIR_PATH/vhdl-libs/ieee2008/fixed_pkg.vhdl"              -lib "ieee" -fileType "VHDL 2008"
   loadSource -path "$::DIR_PATH/vhdl-libs/ieee2008/float_generic_pkg.vhdl"      -lib "ieee" -fileType "VHDL 2008"
   loadSource -path "$::DIR_PATH/vhdl-libs/ieee2008/float_generic_pkg-body.vhdl" -lib "ieee" -fileType "VHDL 2008"
   loadSource -path "$::DIR_PATH/vhdl-libs/ieee2008/float_pkg.vhdl"              -lib "ieee" -fileType "VHDL 2008"
}