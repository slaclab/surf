# Load RUCKUS library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Check if Microblaze source code path defined
if { [info exists ::env(SDK_SRC_PATH)] != 1 }  {
   
   # Load a dummy module
   loadSource -path "$::DIR_PATH/bypass/MicroblazeBasicCoreWrapper.vhd"
   
} else {

   # Load the wrapper
   loadSource -path "$::DIR_PATH/generate/MicroblazeBasicCoreWrapper.vhd"

   # Case on the Vivado Version
   if { $::env(VIVADO_VERSION) <= 2016.2 } {
      loadBlockDesign -path "$::DIR_PATH/bd/2016.2/MicroblazeBasicCore.bd"
   } elseif { $::env(VIVADO_VERSION) == 2016.3 } {
      puts "\n\nError: $::DIR_PATH/bd/MicroblazeBasicCore doesn't support Vivado 2016.3\n\n"
   } elseif { $::env(VIVADO_VERSION) <= 2017.2 } {
      loadBlockDesign -path "$::DIR_PATH/bd/2016.4/MicroblazeBasicCore.bd"      
   } else {
      loadBlockDesign -path "$::DIR_PATH/bd/2017.3/MicroblazeBasicCore.bd"
   }
   
}
