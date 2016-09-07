##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

# Project SDK Run Script

#############################
## Get build system variables 
#############################
set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
source ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl
set EmptyApp "Empty Application"

# Check if project already exists
if { [file exists ${SDK_PRJ}] != 1 } {

   # Check the Vivado version (Refer to AR#66629)
   if { ${VIVADO_VERSION} < 2016.1 } {
      # Setup the project for Vivado 2015.4 (or earlier) ....  Refer to AR#66629
      file mkdir ${SDK_PRJ}
      file copy -force ${OUT_DIR}/${VIVADO_PROJECT}.runs/impl_1/${PROJECT}.sysdef ${SDK_PRJ}/${PROJECT}.hdf
      sdk set_workspace ${SDK_PRJ}
      sdk create_hw_project  -name hw_0  -hwspec ${SDK_PRJ}/${PROJECT}.hdf
      sdk create_bsp_project -name bsp_0 -proc microblaze_0 -hwproject hw_0 -os standalone
      sdk create_app_project -name app_0 -app ${EmptyApp} -proc microblaze_0 -hwproject hw_0 -bsp bsp_0 -os standalone -lang c++
      file delete -force ${SDK_PRJ}/app_0/src/main.cc
      # Configure the release build
      sdk get_build_config -app app_0 build-config release
      sdk get_build_config -app  app_0 -set compiler-optimization {Optimize for size (-Os)}      
      foreach sdkLib ${SDK_LIB} {
         set dirName  [file tail ${sdkLib}]
         set softLink ${SDK_PRJ}/app_0/${dirName}
         sdk get_build_config -app app_0 -add include-path ${sdkLib}
         exec ln -s ${sdkLib} ${softLink}
      }       
      # Configure the debug build
      sdk get_build_config -app app_0 build-config debug
      sdk get_build_config -app  app_0 -set compiler-optimization {Optimize for size (-Os)}      
      foreach sdkLib ${SDK_LIB} {
         set dirName  [file tail ${sdkLib}]
         set softLink ${SDK_PRJ}/app_0/${dirName}
         sdk get_build_config -app app_0 -add include-path ${sdkLib}
         exec ln -s ${sdkLib} ${softLink}
      }       
   } else {
      # Make the project for Vivado 2016.1 (or later) ....  Refer to AR#66629
      file mkdir ${SDK_PRJ}
      file copy -force ${OUT_DIR}/${VIVADO_PROJECT}.runs/impl_1/${PROJECT}.sysdef ${SDK_PRJ}/${PROJECT}.hdf
      sdk setws ${SDK_PRJ}
      sdk createhw  -name hw_0  -hwspec ${SDK_PRJ}/${PROJECT}.hdf
      sdk createbsp -name bsp_0 -proc microblaze_0 -hwproject hw_0 -os standalone
      sdk createapp -name app_0 -app ${EmptyApp} -proc microblaze_0 -hwproject hw_0 -bsp bsp_0 -os standalone -lang c++
      file delete -force ${SDK_PRJ}/app_0/src/main.cc
      # Configure the release build
      sdk configapp -app app_0 build-config release
      sdk configapp -app  app_0 -set compiler-optimization {Optimize for size (-Os)}
      foreach sdkLib ${SDK_LIB} {
         set dirName  [file tail ${sdkLib}]
         set softLink ${SDK_PRJ}/app_0/${dirName}
         exec ln -s ${sdkLib} ${softLink}
         sdk configapp -app app_0 -add include-path ${sdkLib}
      }       
      # Configure the debug build
      sdk configapp -app app_0 build-config debug
      sdk configapp -app  app_0 -set compiler-optimization {Optimize for size (-Os)}
      foreach sdkLib ${SDK_LIB} {
         sdk configapp -app app_0 -add include-path ${sdkLib}
      }           
   }       

}

# Create a soft-link and add new linker to source tree
if { [file exists ${SDK_PRJ}/app_0/src/lscript.ld] == 1 } {
   exec cp -f ${SDK_PRJ}/app_0/src/lscript.ld ${SDK_PRJ}/app_0/lscript.ld
}
file delete -force ${SDK_PRJ}/app_0/src
exec ln -s $::env(SDK_SRC_PATH) ${SDK_PRJ}/app_0/src
if { [file exists ${SDK_PRJ}/app_0/lscript.ld] == 1 } {
   exec mv -f ${SDK_PRJ}/app_0/lscript.ld ${SDK_PRJ}/app_0/src/lscript.ld
}
