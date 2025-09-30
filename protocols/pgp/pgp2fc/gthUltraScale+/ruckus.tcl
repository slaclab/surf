# Load RUCKUS library
source $::env(RUCKUS_QUIET_FLAG) $::env(RUCKUS_PROC_TCL)

# Load local source Code and constraints
if { $::env(VIVADO_VERSION) >= 2024.1 } {

   loadSource -lib surf   -dir "$::DIR_PATH/rtl"

   if { [info exists ::env(PGP2FC_XCI)] != 0 && $::env(PGP2FC_XCI) == 1 } {
       loadIpCore -path "$::DIR_PATH/ip/Pgp2fcGthCore/Pgp2fcGthCore.xci"
       loadIpCore -path "$::DIR_PATH/ip/Pgp2fcGthCore_refclk2x/Pgp2fcGthCore_refclk2x.xci"
       puts "Loading XCI file for PGP2FC"
   } else {
       loadSource -lib surf    -path "$::DIR_PATH/ip/Pgp2fcGthCore/Pgp2fcGthCore.dcp"
       loadSource -lib surf    -path "$::DIR_PATH/ip/Pgp2fcGthCore_refclk2x/Pgp2fcGthCore_refclk2x.dcp"
   }


} else {
   puts "\n\nWARNING: $::DIR_PATH requires Vivado 2024.1 (or later)\n\n"
}
