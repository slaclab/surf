##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

# Project Batch-Mode Build Script

########################################################
## Get variables and Custom Procedures
########################################################
set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl
source -quiet ${VIVADO_BUILD_DIR}/vivado_proc_v1.tcl

# Create a Project
create_project ${VIVADO_PROJECT} -force ${OUT_DIR} -part ${PRJ_PART}

# Message Filtering Script
source -quiet ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl

# Setup project properties
source ${VIVADO_BUILD_DIR}/vivado_properties_v1.tcl

# Target specific project setup script
VivadoRefresh ${VIVADO_PROJECT}
SourceTclFile ${VIVADO_DIR}/project_setup.tcl

# Close the project
close_project
