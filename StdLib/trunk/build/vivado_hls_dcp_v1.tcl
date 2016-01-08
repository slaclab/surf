##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

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