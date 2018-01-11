# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load local source Code and constraints
if { $::env(VIVADO_VERSION) >= 2017.3 } {

   loadSource   -dir "$::DIR_PATH/rtl/"

   loadSource    -path "$::DIR_PATH/ip/PgpGthCore.dcp"
   # loadIpCore  -path "$::DIR_PATH/ip/PgpGthCore.xci" 
   
   if { [info exists ::env(INCLUDE_PGP2B)] != 1 || $::env(INCLUDE_PGP2B) == 0 } {
      set nop 0
   } else {    
   
      loadConstraints -path "$::DIR_PATH/rtl/Pgp2bGthUltra.xdc"
      set_property PROCESSING_ORDER {EARLY}   [get_files {Pgp2bGthUltra.xdc}]
      set_property SCOPED_TO_REF {PgpGthCore} [get_files {Pgp2bGthUltra.xdc}]
      set_property SCOPED_TO_CELLS {inst}     [get_files {Pgp2bGthUltra.xdc}]
      
   }      

} else {
   puts "\n\nWARNING: $::DIR_PATH requires Vivado 2017.3 (or later)\n\n"
}      