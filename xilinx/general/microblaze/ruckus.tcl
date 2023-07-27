# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL)

# Check if Microblaze source code path defined
if { [info exists ::env(VITIS_SRC_PATH)] != 1 }  {

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
      if { $::env(VIVADO_VERSION) == 2023.1 ||
           $::env(VIVADO_VERSION) == 2022.2 } {
         puts "\nVivado v$::env(VIVADO_VERSION) not supported for general/microblaze\n"
         exit -1
      } elseif  { $::env(VIVADO_VERSION) >= 2021.1 } {
         loadBlockDesign -path "$::DIR_PATH/bd/2021.1/MicroblazeBasicCore.bd"
      } else {
         loadBlockDesign -path "$::DIR_PATH/bd/2020.1/MicroblazeBasicCore.bd"
      }

   }

}
