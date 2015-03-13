
## Get variables and Custom Procedures
set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
source  -quiet ${VIVADO_BUILD_DIR}/vivado_hls_env_var_v1.tcl
source  -quiet ${VIVADO_BUILD_DIR}/vivado_hls_proc_v1.tcl 

## Copy the IP directory to module source tree
exec rm -rf ${PROJ_DIR}/ip/
exec cp -rf ${OUT_DIR}/${PROJECT}_project/solution1/impl/ip ${PROJ_DIR}/.

exec rm -rf ${PROJ_DIR}/rtl/
exec cp -rf ${OUT_DIR}/${PROJECT}_project/solution1/syn/vhdl ${PROJ_DIR}/rtl

exec rm -f  [exec ls [glob "${PROJ_DIR}/ip/*.veo"]]
exec cp -f  [exec ls [glob "${OUT_DIR}/${PROJECT}_project/solution1/impl/report/vhdl/*.rpt"]] ${PROJ_DIR}/ip/.

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