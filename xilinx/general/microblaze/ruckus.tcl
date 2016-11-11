# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load Source Code
loadSource -path "$::DIR_PATH/bd/MicroblazeBasicCoreWrapper.vhd"

if { $::env(VIVADO_VERSION) <= 2016.2 } {
   loadBlockDesign -path "$::DIR_PATH/bd/2016.2/MicroblazeBasicCore.bd"
} else {
   loadBlockDesign -path "$::DIR_PATH/bd/2016.3/MicroblazeBasicCore.bd"
}
