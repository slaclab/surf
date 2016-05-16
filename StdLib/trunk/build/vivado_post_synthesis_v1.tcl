##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

# Post-Synthesis Build Script

########################################################
## Get variables and Custom Procedures
########################################################
set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl
source -quiet ${VIVADO_BUILD_DIR}/vivado_proc_v1.tcl

# Get the number of errors and multi-driven nets during synthesis
open_run synth_1
set NumErr [llength [lsearch -all -regexp [split [read [open ${OUT_DIR}/${VIVADO_PROJECT}.runs/synth_1/runme.log]]] "^ERROR:"]]
set MDRV [report_drc -checks {MDRV-1}]
close_design

# Check for errors during synthesis
if { ${NumErr} != 0 } {
   puts "\n\n\nErrors detected during synthesis!!!"
   puts "\tOpen the GUI to review the error messages\n\n\n" 
   close_project
   exit 0   
}

# Check if Multi-Driven Nets are not allowed
set AllowMultiDriven [expr {[info exists ::env(ALLOW_MULTI_DRIVEN)] && [string is true -strict $::env(ALLOW_MULTI_DRIVEN)]}]  
if { ${AllowMultiDriven} != 1 } {
   # Check if any multi-driven nets during synthesis
   if { ${MDRV} != 0 } {
      puts "\n\n\nMulti-driven nets detected during synthesis!!!n\n\n"    
      close_project
      exit 0   
   }
}

# GUI Related:
# Disable a refresh due to the changes 
# in the Version.vhd file during synthesis 
set_property NEEDS_REFRESH false [get_runs synth_1]

# Target specific post_synthesis script
SourceTclFile ${VIVADO_DIR}/post_synthesis.tcl
