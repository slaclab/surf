# Load RUCKUS library
source $::env(RUCKUS_PROC_TCL_COMBO)

# Load Source Code
loadSource -lib surf -dir "$::DIR_PATH/inferred"

# Check for min. Vivado version with XPM support
if {  $::env(VIVADO_VERSION) >= 2019.1} {
   loadSource -lib surf  -dir "$::DIR_PATH/xilinx"
   loadSource -lib surf -path "$::DIR_PATH/dummy/SimpleDualPortRamAlteraMfDummy.vhd"
   loadSource -lib surf -path "$::DIR_PATH/dummy/TrueDualPortRamXpmAlteraMfDummy.vhd"

   # https://support.xilinx.com/s/article/67815?language=en_US
   if { $::env(VIVADO_VERSION) >= 2021.2 } {
      set_property XPM_LIBRARIES XPM_MEMORY [current_project]
   }
} else {
   loadSource -lib surf -dir "$::DIR_PATH/dummy"
}
