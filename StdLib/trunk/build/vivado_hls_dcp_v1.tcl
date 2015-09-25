
## Get variables and Custom Procedures
set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
source  -quiet ${VIVADO_BUILD_DIR}/vivado_hls_env_var_v1.tcl
source  -quiet ${VIVADO_BUILD_DIR}/vivado_hls_proc_v1.tcl 

## Get the file name and path of the new .dcp file
set filename [exec ls [glob "${PROJ_DIR}/ip/*.dcp"]]

## Open the check point
open_checkpoint ${filename}

## Delete all timing constraint for importing into a target vivado project
reset_timing

## Overwrite the checkpoint   
write_checkpoint -force ${filename}

## Print Build complete reminder
PrintBuildComplete ${filename}

## IP is ready for use in target firmware project
exit 0