##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

# Get variables and Custom Procedures
set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl
source -quiet ${VIVADO_BUILD_DIR}/vivado_proc_v1.tcl

# Open the project (in case not already opened)
open_project -quiet ${VIVADO_PROJECT}

# Check if custom SDK exist
if { [file exists ${VIVADO_DIR}/sdk.tcl] == 1 } {   
   source ${VIVADO_DIR}/sdk.tcl
} else {

   # Generate .ELF
   exec xsdk -batch -source ${VIVADO_BUILD_DIR}/vivado_sdk_elf_v1.tcl >@stdout

   # Add .ELF to the .bit file properties
   add_files -norecurse ${SDK_ELF}  
   set_property SCOPED_TO_REF   [file rootname [file tail ${BD_FILES}]] [get_files ${SDK_ELF} ]
   set_property SCOPED_TO_CELLS { microblaze_0 }                        [get_files ${SDK_ELF} ]

   # Rebuild the .bit file with the .ELF file include
   reset_run impl_1 -prev_step
   launch_runs -to_step write_bitstream impl_1 >@stdout
   set src_rc [catch { 
      wait_on_run impl_1 
   } _RESULT]  

   # Copy over .bit w/ .ELF file to image directory
   exec cp -f ${IMPL_DIR}/${PROJECT}.bit ${IMAGES_DIR}/${PROJECT}_${PRJ_VERSION}.bit
   
}
