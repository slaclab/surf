##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

# Pre-Synthesis Run Script

########################################################
## Get variables and Custom Procedures
########################################################
set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl
source -quiet ${VIVADO_BUILD_DIR}/vivado_proc_v1.tcl

# Setup build string
set DATE [exec date]
set USER [exec whoami]
set MACHINE [exec uname -m]
set BSTR "${PROJECT}: Vivado v${VIVADO_VERSION} (${MACHINE}) Built ${DATE} by ${USER}"
set SEDS "s|\\(constant BUILD_STAMP_C : string := \\).*|\\1\"${BSTR}\";|"

# Update the timestamp in Version.vhd
exec sed ${SEDS} ${PROJ_DIR}/Version.vhd > ${PROJ_DIR}/Version.new

# Move the file
exec mv ${PROJ_DIR}/Version.new ${PROJ_DIR}/Version.vhd

# Message Filtering Script
source -quiet ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl

# Refer to http://www.xilinx.com/support/answers/65415.html
set_param synth.elaboration.rodinMoreOptions {rt::set_parameter ignoreVhdlAssertStmts false}

# Target specific pre_synth_run script
SourceTclFile ${VIVADO_DIR}/pre_synth_run.tcl
