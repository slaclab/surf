
## Get variables and Custom Procedures
set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
source  -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl
source  -quiet ${VIVADO_BUILD_DIR}/vivado_proc_v1.tcl 

## Get the top level name
set topName [get_property top [current_fileset]]

## Get the file name and path of the new .dcp file
set filename [exec ls [glob "${OUT_DIR}/${PROJECT}_project.runs/synth_1/*.dcp"]]

## Get the ouput file path and name
set outputFile "${IMAGES_DIR}/${topName}_${PRJ_VERSION}.dcp"

## Open the check point
open_checkpoint ${filename}

## Delete all timing constraint for importing into a target vivado project
reset_timing

## Overwrite the checkpoint   
write_checkpoint -force ${filename}

## Copy the .dcp file from the run directory to images directory in the source tree
file copy -force ${filename} ${outputFile}

## Print Build complete reminder
DcpCompleteMessage ${outputFile}

## IP is ready for use in target firmware project
exit 0