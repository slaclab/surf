##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

# Vivado VCS Build Script

## Note: 
##    VCS must be version H-2013.06-3 (or newer)
##    based on 2013.3 release notes

########################################################
## Get variables
########################################################
set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl
source -quiet ${VIVADO_BUILD_DIR}/vivado_proc_v1.tcl

########################################################
## Open the project
########################################################
open_project -quiet ${VIVADO_PROJECT}

########################################################
## Generate Verilog simulation models 
## for all .DCP files in the source tree
########################################################
foreach filePntr [get_files {*.dcp}] {
   if { [file extension ${filePntr}] == ".dcp" } {
      ## Open the check point
      open_checkpoint ${filePntr}     
      ## Generate the output file path
      set simName [file tail ${filePntr}]
      set simName [string map {".dcp" "_sim.v"} ${simName}] 
      set simFile ${OUT_DIR}/${PROJECT}_project.sim/${simName}
      ## Write the simulation model to the build tree
      write_verilog -force -mode funcsim -file ${simFile}     
      ## close the check point
      close_design
      # Add the Simulation Files
      add_files -quiet -fileset sim_1 ${simFile} 
      # Force Absolute Path (not relative to project)
      set_property PATH_MODE AbsoluteFirst [get_files ${simFile}]
   } 
}

########################################################
## Update the complie order
########################################################
update_compile_order -quiet -fileset sources_1
update_compile_order -quiet -fileset sim_1

########################################################
## Compile the libraries for VCS
########################################################
set simLibOutDir ${OUT_DIR}/vcs_library
compile_simlib -simulator vcs_mx -library unisim -library simprim -library axi_bfm -directory ${simLibOutDir}

########################################################
## Enable the LIBRARY_SCAN parameter 
## in the synopsys_sim.setup file
########################################################

set LIBRARY_SCAN_OLD "LIBRARY_SCAN                    = FALSE"
set LIBRARY_SCAN_NEW "LIBRARY_SCAN                    = TRUE"

# open the files
set in  [open ${OUT_DIR}/vcs_library/synopsys_sim.setup r]
set out [open ${OUT_DIR}/vcs_library/synopsys_sim.temp  w]

# Find and replace the LIBRARY_SCAN parameter
while { [eof ${in}] != 1 } {
   gets ${in} line
   if { ${line} == ${LIBRARY_SCAN_OLD} } {
      puts ${out} ${LIBRARY_SCAN_NEW}
   } else { 
      puts ${out} ${line} 
   }
}

# Close the files
close ${in}
close ${out}

# over-write the existing file
file rename -force ${OUT_DIR}/vcs_library/synopsys_sim.temp ${OUT_DIR}/vcs_library/synopsys_sim.setup

set simTbFileName [get_property top [get_filesets sim_1]]

###############################################
## Check for Vivado Version 2014.2 (or earlier)
###############################################
if { [version -short] <= 2014.2 } {

   # Save the current top level simulation testbed value
   set simTbOutDir ${OUT_DIR}/vcs_scripts/${simTbFileName}

   # Launch the scripts generator 
   export_simulation -absolute_path -force -simulator vcs_mx -lib_map_path ${simLibOutDir} -directory ${simTbOutDir}/
   
################################################
## Else this is Vivado Version 2014.3 (or later)
################################################   
} else {

   # Save the current top level simulation testbed value
   set simTbOutDir ${OUT_DIR}/${PROJECT}_project.sim/sim_1/behav

   # Configure Vivado to generate the VCS scripts
   set_property target_simulator "VCS" [current_project]
   set_property compxlib.compiled_library_dir ${simLibOutDir} [current_project]
   
   # Launch the scripts generator 
   launch_simulation -absolute_path -scripts_only    
}   

########################################################
## Build the simlink directory
########################################################

set simTbDirName [file dirname [get_files ${simTbFileName}.vhd]]
set simLinkDir   ${simTbDirName}/../simlink/src/
set sharedMem    false

# Check if the simlink directory exists
if { [file isdirectory ${simLinkDir}] == 1 } {
   
   # Check if the Makefile exists
   if { [file exists  ${simLinkDir}/Makefile] == 1 } {
      
      # Set the flag true
      set sharedMem true   

      # Create the setup environment script: C-SHELL
      set envScript [open ${simTbOutDir}/setup_env.csh  w]
      puts  ${envScript} "limit stacksize 60000"
      set LD_LIBRARY_PATH "setenv LD_LIBRARY_PATH ${simTbOutDir}:$::env(LD_LIBRARY_PATH)"
      puts  ${envScript} ${LD_LIBRARY_PATH} 
      close ${envScript} 

      # Create the setup environment script: S-SHELL
      set envScript [open ${simTbOutDir}/setup_env.sh  w]
      puts  ${envScript} "ulimit -S -s 60000"
      set LD_LIBRARY_PATH "export LD_LIBRARY_PATH=$::env(LD_LIBRARY_PATH):${simTbOutDir}"
      puts  ${envScript} ${LD_LIBRARY_PATH} 
      close ${envScript}          
      
      # Move the working directory to the simlink directory
      cd ${simLinkDir}
      
      # Set up the 
      set ::env(SIMLINK_PWD) ${simLinkDir}
      
      # Run the Makefile
      exec make
      
      # Copy the library to the binary output directory
      exec cp -f [glob -directory ${simLinkDir} *.so] ${simTbOutDir}/.
      
      # Remove the output binary files from the source tree
      exec make clean
   }   
} else {
   
   # Create a blank setup environment .csh script
   set envScript [open ${simTbOutDir}/setup_env.csh  w]
   puts  ${envScript} " "
   close ${envScript}
   
   # Create a blank setup environment .sh script
   set envScript [open ${simTbOutDir}/setup_env.sh  w]
   puts  ${envScript} " "
   close ${envScript}      
}

###############################################
## Check for Vivado Version 2014.2 (or earlier)
###############################################
if { [version -short] <= 2014.2 } {

   ########################################################
   ## Customization of the executable bash (.sh) script 
   ########################################################

   # open the files
   set in  [open ${simTbOutDir}/${simTbFileName}_sim_vcs_mx.sh r]
   set out [open ${simTbOutDir}/${simTbFileName}_sim_vcs_mx.temp  w]

   # Find and replace the AFS path 
   while { [eof ${in}] != 1 } {
      
      gets ${in} line

      set simString "  simulate"
      if { ${line} == ${simString} } {
         set simString "  source ${simTbOutDir}/setup_env.sh"
         puts ${out} ${simString}
      } else {              
      
         # Insert -nc flags into the vhdlan_opts and vlogan_opts options
         set line [string map {" -l v" " -nc -l v"} ${line}]
         
         # Replace ${simTbFileName}_simv with the simv
         set replaceString "${simTbFileName}_simv simv"
         set line [string map ${replaceString}  ${line}]       

         # Write to file
          puts ${out} ${line}  
      }      
   }

   # Close the files
   close ${in}
   close ${out}

   # over-write the existing file
   file rename -force ${simTbOutDir}/${simTbFileName}_sim_vcs_mx.temp ${simTbOutDir}/${simTbFileName}_sim_vcs_mx.sh

   # Rename the File
   exec mv ${simTbOutDir}/${simTbFileName}_sim_vcs_mx.sh ${simTbOutDir}/sim_vcs_mx.sh

   # Update the permissions
   exec chmod 0755 ${simTbOutDir}/sim_vcs_mx.sh

   ########################################################
   ## Modify the default .do file 
   ########################################################
   if { ${sharedMem} != false } {

      # open the files
      set in  [open ${simTbOutDir}/${simTbFileName}.do r]
      set out [open ${simTbOutDir}/${simTbFileName}.temp  w]

      # Find and replace the LIBRARY_SCAN parameter
      while { [eof ${in}] != 1 } {
         gets ${in} line
         if { ${line} != "quit" } {
            puts ${out} ${line} 
         }
      }

      # Close the files
      close ${in}
      close ${out}

      # over-write the existing file
      file rename -force ${simTbOutDir}/${simTbFileName}.temp ${simTbOutDir}/${simTbFileName}.do
   }
   
################################################
## Else this is Vivado Version 2014.3 (or later)
################################################   
} else {

   ####################################
   ## Customization of the setup script 
   ####################################

   # open the files
   set in  [open ${simTbOutDir}/setup.sh r]
   set out [open ${simTbOutDir}/sim_vcs_mx.temp  w]

   # Find and replace the AFS path 
   while { [eof ${in}] != 1 } {
      
      gets ${in} line
      
      # Insert the sourcing of the local VCS setup_env.sh script
      set exeString "setup \$1"
      if { ${line} == ${exeString} } {
         puts ${out} ${line}
         puts ${out} "source ${simTbOutDir}/compile.sh"
         puts ${out} "source ${simTbOutDir}/elaborate.sh"
         puts ${out} "source ${simTbOutDir}/setup_env.sh"
      } else {              
         # Replace setup.sh with the sim_vcs_mx.sh
         set replaceString "setup.sh sim_vcs_mx.sh"
         set line [string map ${replaceString}  ${line}]       
      
         # Replace ${simTbFileName}_simv with the simv
         set replaceString "${simTbFileName}_simv simv"
         set line [string map ${replaceString}  ${line}] 

         # Write to file
          puts ${out} ${line}  
      }
   }

   # Close the files
   close ${in}
   close ${out}
   
   # over-write the existing file
   file rename -force ${simTbOutDir}/sim_vcs_mx.temp ${simTbOutDir}/sim_vcs_mx.sh

   # Update the permissions
   exec chmod 0755 ${simTbOutDir}/sim_vcs_mx.sh 

   # Delete the old setup.sh
   file delete -force ${simTbOutDir}/setup.sh
  
   ######################################
   ## Customization of the compile script 
   ######################################
  
   # open the files
   set in  [open ${simTbOutDir}/compile.sh r]
   set out [open ${simTbOutDir}/compile.temp  w]

   # Find and replace the AFS path and added secure Verilog support
   while { [eof ${in}] != 1 } {
      gets ${in} line
      set line [string map {"-full64" "-full64 -nc -l +v2k"} ${line}]
      puts ${out} ${line} 
   }

   # Close the files
   close ${in}
   close ${out}

   # over-write the existing file
   file rename -force ${simTbOutDir}/compile.temp ${simTbOutDir}/compile.sh

   # Update the permissions
   exec chmod 0755 ${simTbOutDir}/compile.sh   
  
   ########################################
   ## Customization of the elaborate script 
   ########################################
  
   # open the files
   set in  [open ${simTbOutDir}/elaborate.sh r]
   set out [open ${simTbOutDir}/elaborate.temp  w]

   # Find and replace the AFS path 
   while { [eof ${in}] != 1 } {
      
      gets ${in} line
      
      # Replace ${simTbFileName}_simv with the simv
      set replaceString "${simTbFileName}_simv simv"
      set line [string map ${replaceString}  ${line}] 

      # By default: Mask off warnings during elaboration
      set line [string map {"-full64" "-full64 +warn=none"} ${line}]

      # Write to file
       puts ${out} ${line} 
   }

   # Close the files
   close ${in}
   close ${out}

   # over-write the existing file
   file rename -force ${simTbOutDir}/elaborate.temp ${simTbOutDir}/elaborate.sh

   # Update the permissions
   exec chmod 0755 ${simTbOutDir}/elaborate.sh  

   # Delete the default simulate.sh and .do file
   file delete -force ${simTbOutDir}/simulate.sh   
   file delete -force ${simTbOutDir}/simulate.log   
   file delete -force ${simTbOutDir}/${simTbFileName}.do   
}

########################################################
## Close the project (required for cd function)
########################################################
close_project

########################################################
## Target specific VCS script
########################################################
SourceTclFile ${VIVADO_DIR}/vcs.tcl

########################################################
## VCS Complete Message
########################################################
VcsCompleteMessage ${simTbOutDir} ${sharedMem}
