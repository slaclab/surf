
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

exec cp ${outputFile} ${imagesFile}
