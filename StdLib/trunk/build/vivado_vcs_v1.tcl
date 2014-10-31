
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
## Check if we re-synthesis any of the IP cores
########################################################
BuildIpCores

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

########################################################
## Generate the VCS simulation scripts for each testbed
## Note:
##    This script will automatically build the top level
##    simulation script.  Make sure to set your desired
##    testbed as top level either in GUI interface or 
##    the target's project_setup.tcl script
##
## Example:: project_setup.tcl script:
##    set_property top {HeartbeatTb} [get_filesets sim_1]
########################################################

# Save the current top level simulation testbed value
set simTbFileName [get_property top [get_filesets sim_1]]
set simTbOutDir ${OUT_DIR}/vcs_scripts/${simTbFileName}

if { [version -short] <= 2014.2 } {
   export_simulation -absolute_path -force -simulator vcs_mx -lib_map_path ${simLibOutDir} -directory ${simTbOutDir}/
} else {
   set_property target_simulator "VCS" [current_project]
   launch_simulation -scripts_only -absolute_path ${simLibOutDir} -install_path ${simTbOutDir}
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
      
      # Create the setup environment script
      set envScript [open ${simTbOutDir}/setup_env.csh  w]
      puts  ${envScript} "limit stacksize 60000"
      set LD_LIBRARY_PATH "setenv LD_LIBRARY_PATH ${simTbOutDir}:$::env(LD_LIBRARY_PATH)"
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

########################################################
## Customization of the executable bash (.sh) script 
########################################################

# open the files
set in  [open ${simTbOutDir}/${simTbFileName}_sim_vcs_mx.sh r]
set out [open ${simTbOutDir}/${simTbFileName}_sim_vcs_mx.temp  w]

# Find and replace the AFS path 
while { [eof ${in}] != 1 } {
   
   gets ${in} line
   
   # Insert the sourcing of the local VCS setup_env.sh script
   set setupString {  # Add any setup/initialization commands here:-}
   if { ${line} == ${setupString} } {
      puts ${out} ${line}
      
      # Check for shared memory interface
      if { ${sharedMem} != false } {
         puts  ${out} "  ulimit -S -s 60000"
         set LD_LIBRARY_PATH "  export LD_LIBRARY_PATH=$::env(LD_LIBRARY_PATH):${simTbOutDir}"      
         # Write to file
         puts ${out} ${LD_LIBRARY_PATH}       
      }
  
   } else { 
#       set line [string map {"reference_dir=\".\"" "reference_dir=${pwd()}"} ${line}]
 
       # Insert -nc flags into the vhdlan_opts and vlogan_opts options
       set line [string map {" -l v" " -nc -l v"} ${line}]

      # Replace relative path with the absolute path
      #set line [string map {"../" ""} ${line}]
      #set line [string map {"$reference_dir" ""} ${line}]
      
      # Replace ${simTbFileName}_simv with the simv
		set replaceString "${simTbFileName}_simv simv"
      set line [string map ${replaceString}  ${line}] 
      
      # Mask off the simulate function call in run() 
      set line [string map {"  simulate" ""} ${line}]

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
