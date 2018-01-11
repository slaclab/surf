# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
if { $::env(VIVADO_VERSION) >= 2017.3 } {

   # Load Source Code
   loadSource -dir "$::DIR_PATH/rtl/"
   
   loadSource   -path "$::DIR_PATH/ip/Pgp3GthUsIp/Pgp3GthUsIp.dcp"
   # loadIpCore -path "$::DIR_PATH/ip/Pgp3GthUsIp/Pgp3GthUsIp.xci"
   
   if { [info exists ::env(INCLUDE_PGP3)] != 1 || $::env(INCLUDE_PGP3) == 0 } {
      set nop 0
   } else {   
   
      loadConstraints -path "$::DIR_PATH/xdc/Pgp3GthUsIp.xdc"
      set_property PROCESSING_ORDER {EARLY}       [get_files {Pgp3GthUsIp.xdc}]
      set_property SCOPED_TO_REF    {Pgp3GthUsIp} [get_files {Pgp3GthUsIp.xdc}]
      set_property SCOPED_TO_CELLS  {inst}        [get_files {Pgp3GthUsIp.xdc}]   
      
   }   
   
} else {
   puts "\n\nWARNING: $::DIR_PATH requires Vivado 2017.3 (or later)\n\n"
} 
