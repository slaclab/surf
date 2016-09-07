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
   if { ${VIVADO_VERSION} >= 2015.3 } {
      exec cp -f ${IMPL_DIR}/${PROJECT}_routed.dcp ${OUT_DIR}/IncrementalBuild.dcp
   }
   
   ########################################################
   ## Make a copy of the .bit file and .bit.gz
   ######################################################## 
   exec cp -f ${IMPL_DIR}/${PROJECT}.bit ${IMAGES_DIR}/${PROJECT}_${PRJ_VERSION}.bit
   exec gzip -c -f -9 ${IMPL_DIR}/${PROJECT}.bit > ${IMAGES_DIR}/${PROJECT}_${PRJ_VERSION}.bit.gz

   #########################################################
   ## Check if need to include YAML files with the .BIT file
   #########################################################
   if { [file exists ${PROJ_DIR}/yaml.txt] == 1 } {
      source ${VIVADO_BUILD_DIR}/vivado_yaml_v1.tcl
   }
   
   #########################################################
   ## Check if SDK's .sysdef file exists
   #########################################################
   # Check if SDK_SRC_PATH is a valid path
   if { [CheckSdkSrcPath] != false } {
      # Check for .sysdef file (generated when using Microblaze)
      if { [file exists ${OUT_DIR}/${VIVADO_PROJECT}.runs/impl_1/${PROJECT}.sysdef] == 1 } {
         # Check if custom SDK exist
         if { [file exists ${VIVADO_DIR}/sdk.tcl] == 1 } {   
            source ${VIVADO_DIR}/sdk.tcl
         } else {
            set SDK_PRJ_RDY false
            while { ${SDK_PRJ_RDY} != true } {
               set src_rc [catch {exec xsdk -batch -source ${VIVADO_BUILD_DIR}/vivado_sdk_prj_v1.tcl >@stdout}]       
               if {$src_rc} {
                  puts "Retrying to build SDK project"
                  exec rm -rf ${SDK_PRJ}
               } else {
                  set SDK_PRJ_RDY true
               }         
            }
            # Try to build the .ELF file
            catch { 
               # Generate .ELF
               set src_rc [catch {exec xsdk -batch -source ${VIVADO_BUILD_DIR}/vivado_sdk_elf_v1.tcl >@stdout}]    
               # Add .ELF to the .bit file
               source ${VIVADO_BUILD_DIR}/vivado_sdk_bit_v1.tcl       
            }
         }
      }
   }

   # Target specific post_route script
   SourceTclFile ${VIVADO_DIR}/post_route.tcl
}