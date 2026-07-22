# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Load Source Code
loadSource -lib surf -fileType "VHDL 2008" -dir "$::DIR_PATH/rtl"
