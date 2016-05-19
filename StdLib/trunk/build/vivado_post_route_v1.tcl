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
## Check if passed timing
########################################################
if { [CheckTiming false] == true } {

   ########################################################
   ## Make a copy of the routed .DCP file for future use 
   ## in an "incremental compile" build
   ########################################################
   if { [version -short] >= 2015.3 } {
      exec cp -f ${IMPL_DIR}/${PROJECT}_routed.dcp ${OUT_DIR}/IncrementalBuild.dcp
   }
   
   #########################################################
   ## Check if need to include YAML files with the .BIT file
   #########################################################
   if { [file exists ${PROJ_DIR}/yaml.txt] == 1 } {
      source ${VIVADO_BUILD_DIR}/vivado_yaml_v1.tcl
   }
   
   #########################################################
   ## Check if SDK's .sysdef file exists
   #########################################################
   if { [file exists ${OUT_DIR}/${VIVADO_PROJECT}.runs/impl_1/${PROJECT}.sysdef] == 1 } {
      # Setup the project
      exec xsdk -batch -source ${VIVADO_BUILD_DIR}/vivado_sdk_prj_v1.tcl >@stdout
      # Target specific SDK project script
      SourceTclFile ${VIVADO_DIR}/sdk_prj.tcl
      # Try to build the .ELF file
      catch { 
         # Setup the project
         exec xsdk -batch -source ${VIVADO_BUILD_DIR}/vivado_sdk_elf_v1.tcl >@stdout   
         # Add .ELF to the .bit file properties
         if { [get_files ${SDK_ELF} ] != "" } {
            add_files -norecurse                                      ${SDK_ELF}  
            set_property used_in_simulation 0              [get_files ${SDK_ELF} ] 
            set_property SCOPED_TO_REF MicroblazeBasicCore [get_files ${SDK_ELF} ]
            set_property SCOPED_TO_CELLS { microblaze_0 }  [get_files ${SDK_ELF} ]
            # Rebuild the .bit file with the .ELF file include
            if { [file exists ${OUT_DIR}/IncrementalBuild.dcp] == 1 } {
               set_property incremental_checkpoint ${OUT_DIR}/IncrementalBuild.dcp [get_runs impl_1]
            }
            reset_run impl_1 -prev_step
            launch_runs -to_step write_bitstream impl_1 >@stdout
            set src_rc [catch { 
               wait_on_run impl_1 
            } _RESULT]           
         }
      }
   }
   
   # Target specific post_route script
   SourceTclFile ${VIVADO_DIR}/post_route.tcl
   
}
