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
      if { $::env(VIVADO_VERSION) >= 2021.1 } {
         loadBlockDesign -path "$::DIR_PATH/bd/2021.1/MicroblazeBasicCore.bd"

         # Word around for the locked IPs
         open_bd_design [get_bd_designs MicroblazeBasicCore]
         upgrade_ip [get_ips {MicroblazeBasicCore_rst_clk_wiz_1_100M_0 MicroblazeBasicCore_axi_gpio_0_0}] -log ip_upgrade.log
         export_ip_user_files -of_objects [get_ips {MicroblazeBasicCore_rst_clk_wiz_1_100M_0 MicroblazeBasicCore_axi_gpio_0_0}] -no_script -sync -force -quiet
         close_bd_design [get_bd_designs MicroblazeBasicCore]

      } else {
         loadBlockDesign -path "$::DIR_PATH/bd/2020.1/MicroblazeBasicCore.bd"
      }

   }

}
