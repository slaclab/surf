# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib surf -dir "$::DIR_PATH/rtl"

# Load Simulation
loadSource -lib surf -sim_only -dir "$::DIR_PATH/tb"

# Load Source Code
if { $::env(VIVADO_VERSION) >= 2025.1 } {

   loadSource -lib surf   -path "$::DIR_PATH/ip/Pgp4GtyUsIpFec/Pgp4GtyUsIpFec.dcp"
   # loadIpCore -path "$::DIR_PATH/ip/Pgp4GtyUsIpFec/Pgp4GtyUsIpFec.xci"

} else {
   puts "\n\nWARNING: $::DIR_PATH requires Vivado 2025.1 (or later)\n\n"
}
