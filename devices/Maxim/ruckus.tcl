# Load RUCKUS environment and library
source $::env(RUCKUS_PROC_TCL)

# Check for non-zero Vivado version (in-case non-Vivado project)
if {  $::env(VIVADO_VERSION) > 0.0} {
   # Load the source code
   loadSource -lib surf -dir "$::DIR_PATH/rtl"
} else {
   loadSource -lib surf -dir  "$::DIR_PATH/dummy"
}
