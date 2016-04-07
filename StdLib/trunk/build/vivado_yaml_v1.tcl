##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

########################################################
## Get variables and Custom Procedures
########################################################
set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl
source -quiet ${VIVADO_BUILD_DIR}/vivado_proc_v1.tcl

# Common Variable
set ProjYamlDir "${OUT_DIR}/${PROJECT}_project.yaml"

# Check if the directory exists
if [file exists ${ProjYamlDir}] {
   exec rm -rf ${ProjYamlDir}/*
} else {
   exec mkdir ${ProjYamlDir}
}

# Copy all the YAML files to the project's YAML directory 
foreach yamlFile ${YAML_FILES} {
   exec cp -f ${yamlFile} ${ProjYamlDir}/.
}

# Copy the Version.vhd and the LICENSE.txt to the project's YAML directory
exec cp -f ${PROJ_DIR}/Version.vhd            ${ProjYamlDir}/.
exec cp -f ${VIVADO_BUILD_DIR}/../LICENSE.txt ${ProjYamlDir}/.

# Compress the project's YAML directory to the target's image directory
exec tar -zcvf  ${IMAGES_DIR}/${PROJECT}_${PRJ_VERSION}.tar.gz -C ${OUT_DIR} ${PROJECT}_project.yaml
