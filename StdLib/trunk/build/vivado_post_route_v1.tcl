##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

# Post-Route Build Script

########################################################
## Get variables and Custom Procedures
########################################################
set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl
source -quiet ${VIVADO_BUILD_DIR}/vivado_proc_v1.tcl

########################################################
## Make a copy of the routed .DCP file for future use 
## in an "incremental compile" build
########################################################
if { ([CheckTiming false] == true) && ([version -short] >= 2015.3) } {
   exec cp -f ${IMPL_DIR}/${PROJECT}_routed.dcp ${OUT_DIR}/IncrementalBuild.dcp
}

# Target specific post_route script
SourceTclFile ${VIVADO_DIR}/post_route.tcl
