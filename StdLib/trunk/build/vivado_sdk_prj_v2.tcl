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

set SOFT_LINK [info exists ::env(SDK_SRC_PATH)]

# Check if project already exists
if { [file exists ${SDK_PRJ}] != 1 } {
   # Make the project
   file mkdir ${SDK_PRJ}
   file copy -force ${OUT_DIR}/${VIVADO_PROJECT}.runs/impl_1/${PROJECT}.sysdef ${SDK_PRJ}/${PROJECT}.hdf
   sdk setws ${SDK_PRJ}
   sdk createhw  -name hw_0  -hwspec ${SDK_PRJ}/${PROJECT}.hdf
   sdk createbsp -name bsp_0 -proc microblaze_0 -hwproject hw_0 -os standalone
   sdk createapp -name app_0 -app "Empty Application" -proc microblaze_0 -hwproject hw_0 -bsp bsp_0 -os standalone -lang c++

   # Create a soft-link and add new linker to source tree
   if { ${SOFT_LINK} == 1 } {
      file copy   -force ${SDK_PRJ}/app_0/src/lscript.ld ${SDK_PRJ}/app_0/lscript.ld
      file delete -force ${SDK_PRJ}/app_0/src
      exec ln -s $::env(SDK_SRC_PATH) ${SDK_PRJ}/app_0/src
      exec mv -f ${SDK_PRJ}/app_0/lscript.ld ${SDK_PRJ}/app_0/src/lscript.ld
   }   
}
