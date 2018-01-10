# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
if { $::env(VIVADO_VERSION) >= 2017.3 } {

   # Load Source Code
   loadSource -dir "$::DIR_PATH/rtl"

   loadSource -path "$::DIR_PATH/ip/Pgp3Gtx7Ip10G.dcp"
   # loadIpCore -path "$::DIR_PATH/ip/Pgp3Gtx7Ip10G.xci"

   loadSource -path "$::DIR_PATH/ip/Pgp3Gtx7Ip6G.dcp"
   # loadIpCore -path "$::DIR_PATH/ip/Pgp3Gtx7Ip6G.xci"


   if { [info exists ::env(INCLUDE_PGP3_10G)] != 1 || $::env(INCLUDE_PGP3_10G) == 0 } {
      set nop 0
   } else {

      loadConstraints -path "$::DIR_PATH/xdc/Pgp3Gtx7Ip10G.xdc"
      set_property PROCESSING_ORDER {EARLY}         [get_files {Pgp3Gtx7Ip10G.xdc}]
      set_property SCOPED_TO_REF    {Pgp3Gtx7Ip10G} [get_files {Pgp3Gtx7Ip10G.xdc}]
      set_property SCOPED_TO_CELLS  {U0}            [get_files {Pgp3Gtx7Ip10G.xdc}]
      
   }

   if { [info exists ::env(INCLUDE_PGP3_6G)] != 1 || $::env(INCLUDE_PGP3_6G) == 0 } {
      set nop 0
   } else {

      loadConstraints -path "$::DIR_PATH/xdc/Pgp3Gtx7Ip6G.xdc"
      set_property PROCESSING_ORDER {EARLY}        [get_files {Pgp3Gtx7Ip6G.xdc}]
      set_property SCOPED_TO_REF    {Pgp3Gtx7Ip6G} [get_files {Pgp3Gtx7Ip6G.xdc}]
      set_property SCOPED_TO_CELLS  {U0}           [get_files {Pgp3Gtx7Ip6G.xdc}]
      
   }

} else {
   puts "\n\nWARNING: $::DIR_PATH requires Vivado 2017.3 (or later)\n\n"
} 