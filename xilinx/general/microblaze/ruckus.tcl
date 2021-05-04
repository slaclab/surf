# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Check if Microblaze source code path defined
if { [info exists ::env(SDK_SRC_PATH)] != 1 }  {

   # Load a dummy module
   loadSource -lib surf -path "$::DIR_PATH/bypass/MicroblazeBasicCoreWrapper.vhd"

} else {

   # Case on the Vivado Version
   if { $::env(VIVADO_VERSION) < 2020.1 } {
      # Load a dummy module
      loadSource -lib surf -path "$::DIR_PATH/bypass/MicroblazeBasicCoreWrapper.vhd"
   } else {

      # Load the wrapper
      loadSource -lib surf -path "$::DIR_PATH/generate/MicroblazeBasicCoreWrapper.vhd"

      # Load the .bd file
      loadBlockDesign -path "$::DIR_PATH/bd/2020.1/MicroblazeBasicCore.bd"
   }

}
