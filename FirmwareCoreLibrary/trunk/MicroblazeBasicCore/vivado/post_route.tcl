# Post-Route Build Script

########################################################
## Get variables and Custom Procedures
########################################################
set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl
source -quiet ${VIVADO_BUILD_DIR}/vivado_proc_v1.tcl

## Make the SDK directory
file mkdir ${OUT_DIR}/${VIVADO_PROJECT}.sdk

## Export the hardware to the image directory
file copy -force ${OUT_DIR}/${VIVADO_PROJECT}.runs/impl_1/${PROJECT}.sysdef ${IMAGES_DIR}/${PROJECT}_${PRJ_VERSION}.hdf
