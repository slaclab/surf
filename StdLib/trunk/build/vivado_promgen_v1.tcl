##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

# Vivado PROMGEN Build Script

set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl
source -quiet ${VIVADO_BUILD_DIR}/vivado_proc_v1.tcl

# Target PROMGEN script
set inputFile "$::env(IMPL_DIR)/$::env(PROJECT).bit"
set outputFile "$::env(IMPL_DIR)/$::env(PROJECT).mcs"
set imagesFile "$::env(IMAGES_DIR)/$::env(PROJECT)_$::env(PRJ_VERSION).mcs"
set loadbit    "up 0x0 ${inputFile}"
set loaddata   ""

source ${VIVADO_DIR}/promgen.tcl

if { ${loaddata} != "" } {
   puts ${inputFile}
   puts ${outputFile}
   puts ${loadbit}   
   puts ${loaddata}   
   write_cfgmem -force \
      -format ${format} \
      -interface ${inteface} \
      -size ${size} \
      -loadbit ${loadbit} \
      -loaddata ${loaddata} \
      -file ${outputFile}
} else {   
   puts ${inputFile}
   puts ${outputFile}
   puts ${loadbit}   
   write_cfgmem -force \
      -format ${format} \
      -interface ${inteface} \
      -size ${size} \
      -loadbit ${loadbit} \
      -file ${outputFile}   
}

# Note: We still need to add copy support for -interface = SPIx8
exec cp ${outputFile} ${imagesFile}
