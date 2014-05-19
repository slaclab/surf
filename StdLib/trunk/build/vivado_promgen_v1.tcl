
# Vivado PROMGEN Build Script

set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl
source -quiet ${VIVADO_BUILD_DIR}/vivado_proc_v1.tcl

# Target PROMGEN script
source ${VIVADO_DIR}/promgen.tcl

write_cfgmem -force \
   -format ${format} \
   -interface ${inteface} \
   -size ${size} \
   -loadbit ${loadbit} \
   -file ${outputFile}