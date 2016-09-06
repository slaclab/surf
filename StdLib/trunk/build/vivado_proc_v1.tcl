##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

# Custom Procedure Script

###############################################################
#### General Functions ########################################
###############################################################

# Refresh a Vivado project
proc VivadoRefresh { vivadoProject } {
   close_project
   open_project -quiet ${vivadoProject}
}

# Achieve a Vivado Project
proc ArchiveProject { } {
   ## Make a copy of the TCL configurations
   set SYNTH_PRE     [get_property {STEPS.SYNTH_DESIGN.TCL.PRE}                [get_runs synth_1]]
   set SYNTH_POST    [get_property {STEPS.SYNTH_DESIGN.TCL.POST}               [get_runs synth_1]]
   set OPT_PRE       [get_property {STEPS.OPT_DESIGN.TCL.PRE}                  [get_runs impl_1]]
   set OPT_POST      [get_property {STEPS.OPT_DESIGN.TCL.POST}                 [get_runs impl_1]]
   set PWR_PRE       [get_property {STEPS.POWER_OPT_DESIGN.TCL.PRE}            [get_runs impl_1]]
   set PWR_POST      [get_property {STEPS.POWER_OPT_DESIGN.TCL.POST}           [get_runs impl_1]]
   set PLACE_PRE     [get_property {STEPS.PLACE_DESIGN.TCL.PRE}                [get_runs impl_1]]
   set PLACE_POST    [get_property {STEPS.PLACE_DESIGN.TCL.POST}               [get_runs impl_1]]
   set PWR_OPT_PRE   [get_property {STEPS.POST_PLACE_POWER_OPT_DESIGN.TCL.PRE} [get_runs impl_1]]
   set PWR_OPT_POST  [get_property {STEPS.POST_PLACE_POWER_OPT_DESIGN.TCL.POST}[get_runs impl_1]]
   set PHYS_OPT_PRE  [get_property {STEPS.PHYS_OPT_DESIGN.TCL.PRE}             [get_runs impl_1]]
   set PHYS_OPT_POST [get_property {STEPS.PHYS_OPT_DESIGN.TCL.POST}            [get_runs impl_1]]
   set ROUTE_PRE     [get_property {STEPS.ROUTE_DESIGN.TCL.PRE}                [get_runs impl_1]]
   set ROUTE_POST    [get_property {STEPS.ROUTE_DESIGN.TCL.POST}               [get_runs impl_1]]
   set WRITE_PRE     [get_property {STEPS.WRITE_BITSTREAM.TCL.PRE}             [get_runs impl_1]]
   set WRITE_POST    [get_property {STEPS.WRITE_BITSTREAM.TCL.POST}            [get_runs impl_1]]

   ## Remove the TCL configurations
   set_property STEPS.SYNTH_DESIGN.TCL.PRE                 "" [get_runs synth_1]
   set_property STEPS.SYNTH_DESIGN.TCL.POST                "" [get_runs synth_1]
   set_property STEPS.OPT_DESIGN.TCL.PRE                   "" [get_runs impl_1] 
   set_property STEPS.OPT_DESIGN.TCL.POST                  "" [get_runs impl_1] 
   set_property STEPS.POWER_OPT_DESIGN.TCL.PRE             "" [get_runs impl_1]
   set_property STEPS.POWER_OPT_DESIGN.TCL.POST            "" [get_runs impl_1]
   set_property STEPS.PLACE_DESIGN.TCL.PRE                 "" [get_runs impl_1]
   set_property STEPS.PLACE_DESIGN.TCL.POST                "" [get_runs impl_1]
   set_property STEPS.POST_PLACE_POWER_OPT_DESIGN.TCL.PRE  "" [get_runs impl_1]
   set_property STEPS.POST_PLACE_POWER_OPT_DESIGN.TCL.POST "" [get_runs impl_1]
   set_property STEPS.PHYS_OPT_DESIGN.TCL.PRE              "" [get_runs impl_1]
   set_property STEPS.PHYS_OPT_DESIGN.TCL.POST             "" [get_runs impl_1]
   set_property STEPS.ROUTE_DESIGN.TCL.PRE                 "" [get_runs impl_1]
   set_property STEPS.ROUTE_DESIGN.TCL.POST                "" [get_runs impl_1]
   set_property STEPS.WRITE_BITSTREAM.TCL.PRE              "" [get_runs impl_1]
   set_property STEPS.WRITE_BITSTREAM.TCL.POST             "" [get_runs impl_1]
   
   ## Archive the project
   archive_project $::env(IMAGES_DIR)/$::env(PROJECT)_project.xpr.zip -force -include_config_settings
   
   ## Restore the TCL configurations
   set_property STEPS.SYNTH_DESIGN.TCL.PRE                 ${SYNTH_PRE}    [get_runs synth_1]
   set_property STEPS.SYNTH_DESIGN.TCL.POST                ${SYNTH_POST}   [get_runs synth_1]
   set_property STEPS.OPT_DESIGN.TCL.PRE                   ${OPT_PRE}      [get_runs impl_1]
   set_property STEPS.OPT_DESIGN.TCL.POST                  ${OPT_POST}     [get_runs impl_1]
   set_property STEPS.POWER_OPT_DESIGN.TCL.PRE             ${PWR_PRE}      [get_runs impl_1]
   set_property STEPS.POWER_OPT_DESIGN.TCL.POST            ${PWR_POST}     [get_runs impl_1]
   set_property STEPS.PLACE_DESIGN.TCL.PRE                 ${PLACE_PRE}    [get_runs impl_1]
   set_property STEPS.PLACE_DESIGN.TCL.POST                ${PLACE_POST}   [get_runs impl_1]
   set_property STEPS.POST_PLACE_POWER_OPT_DESIGN.TCL.PRE  ${PWR_OPT_PRE}  [get_runs impl_1]
   set_property STEPS.POST_PLACE_POWER_OPT_DESIGN.TCL.POST ${PWR_OPT_POST} [get_runs impl_1]
   set_property STEPS.PHYS_OPT_DESIGN.TCL.PRE              ${PHYS_OPT_PRE} [get_runs impl_1]
   set_property STEPS.PHYS_OPT_DESIGN.TCL.POST             ${PHYS_OPT_POST}[get_runs impl_1]
   set_property STEPS.ROUTE_DESIGN.TCL.PRE                 ${ROUTE_PRE}    [get_runs impl_1]
   set_property STEPS.ROUTE_DESIGN.TCL.POST                ${ROUTE_POST}   [get_runs impl_1]
   set_property STEPS.WRITE_BITSTREAM.TCL.PRE              ${WRITE_PRE}    [get_runs impl_1]   
   set_property STEPS.WRITE_BITSTREAM.TCL.POST             ${WRITE_POST}   [get_runs impl_1]     
}

# Custom TLC source function
proc SourceTclFile { filePath } {
   if { [file exists ${filePath}] == 1 } {
      source ${filePath}
      return true;
   } else {
      return false;
   }
}

# Get the number of CPUs available on the Linux box
proc GetCpuNumber { } {
   return [exec cat /proc/cpuinfo | grep processor | wc -l]
}

# Function for putting the TCL script into a wait (in units of seconds)
proc sleep {N} {
   after [expr {int($N * 1000)}]
}

proc BuildIpCores { } {
   # Get variables
   set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
   source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl
   source -quiet ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl

   # Check if the target project has IP cores
   if { [get_ips] != "" } {
      # Clear the list of IP cores
      set ipCoreList ""
      set ipList ""
      # Loop through each IP core
      foreach corePntr [get_ips] {
         # Set the IP core synthesis run name
         set ipSynthRun ${corePntr}_synth_1
         # Check if we need to build the IP core
         if { [get_runs ${ipSynthRun}] == ${ipSynthRun} } {
            if { [CheckIpSynth ${ipSynthRun}] != true } {
               reset_run  ${ipSynthRun}
               append ipSynthRun " "
               append ipCoreList ${ipSynthRun}
               append ipList ${corePntr}            
               append ipList " "
            }
         }
      }
      # Check for IP cores to build
      if { ${ipCoreList} != "" } {
         # Build the IP Core
         launch_runs -quiet ${ipCoreList} -jobs [GetCpuNumber]
         foreach waitPntr ${ipCoreList} {
            set src_rc [catch { 
               wait_on_run ${waitPntr} 
            } _RESULT]   
         }
      }      
      foreach corePntr ${ipList} {
         # Disable the IP Core's XDC (so it doesn't get implemented at the project level)
         set xdcPntr [get_files -quiet -of_objects [get_files ${corePntr}.xci] -filter {FILE_TYPE == XDC}]
         if { ${xdcPntr} != "" } {
            set_property is_enabled false [get_files ${xdcPntr}] 
         }         
         # Set the IP core synthesis run name
         set ipSynthRun ${corePntr}_synth_1         
         # Reset the "needs_refresh" flag
         set_property needs_refresh false [get_runs ${ipSynthRun}]
      }
   }
   # Refresh the project
   VivadoRefresh ${VIVADO_PROJECT}   
}

# Copies all defined cores.txt IP cores from the build tree to source tree
proc CopyIpCores { } {
   # Get variables
   set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
   source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl
   source -quiet ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl   
   
   # Make sure the IP Cores have been built
   BuildIpCores
   
   # Check if the target project has IP cores
   if { [get_ips] != "" } {
      # Loop through the IP cores
      foreach corePntr [get_ips] {
         # Create a copy of the IP Core in the source tree
         foreach coreFilePntr ${CORE_FILES} {
            if { [ string match *${corePntr}* ${coreFilePntr} ] } { 
               # Overwrite the existing .xci file in the source tree
               set SRC [get_files ${corePntr}.xci]
               set DST ${coreFilePntr}
               exec cp ${SRC} ${DST}
               puts "exec cp ${SRC} ${DST}"    
               # Overwrite the existing .dcp file in the source tree               
               set SRC [string map {.xci .dcp} ${SRC}]
               set DST [string map {.xci .dcp} ${DST}]
               exec cp ${SRC} ${DST}    
               puts "exec cp ${SRC} ${DST}"    
            }
         }        
      }
   }
}  

# Copies all source code defined cores.txt IP cores from the build tree to source tree
proc CopyIpCoresDebug { } {
   # Get variables
   set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
   source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl
   source -quiet ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl   
   
   # Make sure the IP Cores have been built
   BuildIpCores
   
   # Check if the target project has IP cores
   if { [get_ips] != "" } {
      # Loop through the IP cores
      foreach corePntr [get_ips] {
         # Copy source code from build tree to source tree
         foreach coreFilePntr ${CORE_FILES} {
            if { [ string match *${corePntr}* ${coreFilePntr} ] } { 
               set SRC [get_files ${corePntr}.xci]
               set DST ${coreFilePntr}            
               set SRC  [string trim ${SRC} ${corePntr}.xci]
               set DST  [string trim ${DST} ${corePntr}.xci]
               exec cp -rf ${SRC} ${DST}    
               puts "exec cp -rf ${SRC} ${DST}"    
            }
         }        
      }
   }
}   

# Copies all defined block_design.txt IP cores from the build tree to source tree
proc CopyBdCores { } {
   # Get variables
   set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
   source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl
   source -quiet ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl   
   
   # Check if the target project has IP cores
   if { [get_bd_designs] != "" } {
      # Loop through the IP cores
      foreach bdPntr [get_bd_designs] {
         # Create a copy of the IP Core in the source tree
         foreach bdFilePntr ${BD_FILES} {
            if { [ string match *${bdPntr}* ${bdFilePntr} ] } { 
               # Overwrite the existing .bd file in the source tree
               set SRC [get_files ${bdPntr}.bd]
               set DST ${bdFilePntr}
               exec cp ${SRC} ${DST}
               puts "exec cp ${SRC} ${DST}"    
            }
         }        
      }
   }
} 

# Copies all source code defined block_design.txt IP cores from the build tree to source tree
proc CopyBdCoresDebug { } {
   # Get variables
   set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
   source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl
   source -quiet ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl   
   
   # Check if the target project has IP cores
   if { [get_bd_designs] != "" } {
      # Loop through the IP cores
      foreach bdPntr [get_bd_designs] {
         # Copy source code from build tree to source tree
         foreach bdFilePntr ${BD_FILES} {
            if { [ string match *${bdPntr}* ${bdFilePntr} ] } { 
               set SRC [get_files ${bdPntr}.bd]
               set DST ${bdFilePntr}            
               set SRC  [string trim ${SRC} ${bdPntr}.bd]
               set DST  [string trim ${DST} ${bdPntr}.bd]
               exec cp -rf ${SRC} ${DST}    
               puts "exec cp -rf ${SRC} ${DST}"    
            }
         }        
      }
   }
} 

proc CreateYamlTarGz { } {   
   # Get variables
   set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
   source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl
   source -quiet ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl
   #########################################################
   ## Check if need to include YAML files with the .BIT file
   #########################################################
   if { [file exists ${PROJ_DIR}/yaml.txt] == 1 } {
      source ${VIVADO_BUILD_DIR}/vivado_yaml_v1.tcl
   }
}

proc CreatePromMcs { } {   
   # Get variables
   set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
   source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl
   source -quiet ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl
   #########################################################
   ## Check if promgen.tcl exist
   #########################################################
   if { [file exists ${PROJ_DIR}/vivado/promgen.tcl] == 1 } {
      source ${VIVADO_BUILD_DIR}/vivado_promgen_v1.tcl
   }
}   
   
proc RemoveUnsuedCode { } { 
   remove_files [get_files -filter {IS_AUTO_DISABLED}]
}

# Checking Timing Function
proc CheckTiming { {printTiming true} } {
   # Check for timing and routing errors 
   set WNS [get_property STATS.WNS [get_runs impl_1]]
   set TNS [get_property STATS.TNS [get_runs impl_1]]
   set WHS [get_property STATS.WHS [get_runs impl_1]]
   set THS [get_property STATS.THS [get_runs impl_1]]
   set TPWS [get_property STATS.TPWS [get_runs impl_1]]
   set FAILED_NETS [get_property STATS.FAILED_NETS [get_runs impl_1]]

   if { ${WNS}<0.0 || ${TNS}<0.0 \
      || ${WHS}<0.0 || ${THS}<0.0 \
      || ${TPWS}<0.0 || ${FAILED_NETS}>0.0 } {
      
      if { ${printTiming} == true } {
         puts "\n\n\n\n\n********************************************************"
         puts "********************************************************"
         puts "********************************************************"
         puts "The design did not meet timing or unable to route:"
         puts "\tSetup: Worst Negative Slack (WNS): ${WNS} ns"
         puts "\tSetup: Total Negative Slack (TNS): ${TNS} ns"
         puts "\tHold: Worst Hold Slack (WHS): ${WHS} ns"
         puts "\tHold: Total Hold Slack (THS): ${THS} ns"  
         puts "\tPulse Width: Total Pulse Width Negative Slack (TPWS): ${TPWS} ns"   
         puts "\tRouting: Number of Failed Nets: ${FAILED_NETS}"       
         puts "********************************************************"
         puts "********************************************************"
         puts "********************************************************\n\n\n\n\n"  
      }
      
      # Check the TIG variable
      set retVar [expr {[info exists ::env(TIG)] && [string is true -strict $::env(TIG)]}]  
      if { ${retVar} == 1 } {
         return true
      } else {
         return false
      }    
      
   } else {
      return true
   }
}

# Check if SDK_SRC_PATH exist, then it checks for a valid path 
proc CheckSdkSrcPath { } {
   if { [expr [info exists ::env(SDK_SRC_PATH)]] == 1 } {
      if { [expr [file exists $::env(SDK_SRC_PATH)]] == 0 } {
         puts "\n\n\n\n\n********************************************************"
         puts "********************************************************"
         puts "********************************************************"   
         puts "SDK_SRC_PATH: $::env(SDK_SRC_PATH) does not exist"
         puts "********************************************************"
         puts "********************************************************"
         puts "********************************************************\n\n\n\n\n"  
         return false
      }      
   }
   return true
}

# Check if the Synthesize is completed
proc CheckSynth { } {

   if { [get_property PROGRESS [get_runs synth_1]] != "100\%" } {
      return false
   } elseif { [get_property NEEDS_REFRESH [get_runs synth_1]] == 1 } {
      return false   
   } elseif { [get_property STATUS [get_runs synth_1]] != "synth_design Complete!" } {
      return false
   } else {
      return true
   }
}

# Check if the Synthesize is completed
proc CheckIpSynth { ipSynthRun } {
   if { [get_property PROGRESS [get_runs ${ipSynthRun}]] != "100\%" } {
      return false
   } elseif { [get_property NEEDS_REFRESH [get_runs ${ipSynthRun}]] == 1 } {
      return false   
   } elseif { [get_property STATUS [get_runs ${ipSynthRun}]] != "synth_design Complete!" } {
      return false
   } else {
      return true
   }
}

# Check if the Implementation is completed
proc CheckImpl { } {
   if { [get_property PROGRESS [get_runs impl_1]] != "100\%" } {
      return false 
   } elseif { [get_property STATUS [get_runs impl_1]] != "write_bitstream Complete!" } {
      return false
   } else {
      return true
   }
}
proc VcsCompleteMessage {dirPath sharedMem} {
   puts "\n\n********************************************************"
   puts "The VCS simulation script has been generated."
   puts "To compile and run the simulation:"
   puts "\t\$ cd ${dirPath}/"    
   puts "\t\$ ./sim_vcs_mx.sh"
   puts "\t\$ source setup_env.csh"
   puts "\t\$ ./simv"   
   puts "********************************************************\n\n" 
}

proc DcpCompleteMessage { filename } {
   puts "\n\n********************************************************"
   puts "The new .dcp file is located here:"
   puts ${filename}
   puts "********************************************************\n\n" 
}

proc HlsVersionCheck { } {
   set VersionNumber [version -short]
   if { ${VersionNumber} == 2014.2 } {
      puts "\n\n****************************************************************"
      puts "Vivado_HLS Version = ${VersionNumber} is not support in this build system."
      puts "****************************************************************\n\n" 
      return -1
   } else {
      return 0
   }
}

proc VersionCheck { lockVersion } {
   set VersionNumber [version -short]
   if { ${VersionNumber} < ${lockVersion} } {
      puts "\n\n*********************************************************"
      puts "Your Vivado Version Vivado   = ${VersionNumber}"
      puts "However, Vivado Version Lock = ${lockVersion}"
      puts "You need to change your Vivado software to Version ${lockVersion}"
      puts "*********************************************************\n\n" 
      return -1
   } elseif { ${VersionNumber} == ${lockVersion} } {
      return 0
   } else { 
      return 1
   }
}

###############################################################
#### Partial Reconfiguration Functions ########################
###############################################################

# Check if RECONFIG_NAME environmental variable
proc CheckForReconfigName { } {
   if { [info exists ::env(RECONFIG_NAME)] } {
      return true
   } else {
      puts "\n\nNo RECONFIG_NAME environmental variable was found."
      puts "Please check the project's Makefile\n\n"
      return false   
   }
}

# Check if RECONFIG_CHECKPOINT environmental variable exists
proc CheckForReconfigCheckPoint { } {
   if { [info exists ::env(RECONFIG_CHECKPOINT)] } {
      return true
   } else {
      puts "\n\nNo RECONFIG_CHECKPOINT environmental variable was found."
      puts "Please check the project's Makefile\n\n"
      return false   
   }
}

# Generate Partial Reconfiguration RTL Block's checkpoint
proc GenPartialReconfigDcp {rtlName} {

   puts "\n\nGenerating ${rtlName} RTL ... \n\n"

   # Get variables
   set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
   source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl
   source -quiet ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl
  
   # Get a list of all runs  
   set LIST_RUNS [get_runs]   
   
   # Check if RTL synthesis run already exists
   if { [lsearch ${LIST_RUNS} ${rtlName}_1] == -1 } {
      # create a RTL synthesis run
      create_run -flow {Vivado Synthesis 2013} ${rtlName}_1
   } else {
      # Clean up the run
      reset_run ${rtlName}_1   
   }
   
   # Disable all constraint file 
   set_property is_enabled false [get_files *.xdc]
   
   # Only enable the targeted XDC file
   set_property is_enabled true [get_files ${rtlName}.xdc]   
   
   # Don't flatten the hierarchy
   set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY none [get_runs ${rtlName}_1]
   
   # Prevents I/O insertion for synthesis and downstream tools
   set_property -name {STEPS.SYNTH_DESIGN.ARGS.MORE OPTIONS} -value {-mode out_of_context} -objects [get_runs ${rtlName}_1]   
   
   # Set the top level RTL
   set_property top ${rtlName} [current_fileset]
   
   # Synthesize
   launch_runs ${rtlName}_1
   set src_rc [catch { 
      wait_on_run ${rtlName}_1
   } _RESULT]    
}

# Insert the Partial Reconfiguration RTL Block(s) into top level checkpoint checkpoint
proc InsertStaticReconfigDcp { } {

   # Get variables
   set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
   set RECONFIG_NAME    $::env(RECONFIG_NAME)
   source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl
   source -quiet ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl
   
   # Set common variables
   set SYNTH_DIR ${OUT_DIR}/${PROJECT}_project.runs/synth_1
   
   # Enable the RTL Blocks(s) Logic
   foreach rtlPntr ${RECONFIG_NAME} {
      set_property is_enabled true [get_files *${rtlPntr}.vhd]
   }      
   
   # Disable the top level HDL
   set_property is_enabled false [get_files ${PROJECT}.vhd]
   
   # Generate Partial Reconfiguration RTL Block(s) checkpoints
   foreach rtlPntr ${RECONFIG_NAME} {
      GenPartialReconfigDcp ${rtlPntr}
   }

   # Reset all the Partial Reconfiguration RTL Block(s) and 
   # their XDC files to disabled
   foreach rtlPntr ${RECONFIG_NAME} {
      set_property is_enabled false [get_files ${rtlPntr}.vhd]
      set_property is_enabled false [get_files ${rtlPntr}.xdc]
   }   
   
   # Reset the top level module
   set_property is_enabled true [get_files ${PROJECT}.vhd]
   set_property is_enabled true [get_files ${PROJECT}.xdc]
   set_property top ${PROJECT} [current_fileset]
   
   # Reset the "needs_refresh" flag because of top level assignment juggling
   set_property needs_refresh false [get_runs synth_1]
   foreach rtlPntr ${RECONFIG_NAME} {
      set_property needs_refresh false [get_runs ${rtlPntr}_1]
   }   
   
   # Backup the top level checkpoint and reports
   file copy   -force ${SYNTH_DIR}/${PROJECT}.dcp                   ${SYNTH_DIR}/${PROJECT}_backup.dcp
   file rename -force ${SYNTH_DIR}/${PROJECT}_utilization_synth.rpt ${SYNTH_DIR}/${PROJECT}_utilization_synth_backup.rpt
   file rename -force ${SYNTH_DIR}/${PROJECT}_utilization_synth.pb  ${SYNTH_DIR}/${PROJECT}_utilization_synth_backup.pb
   
   # open the top level check point
   open_checkpoint ${SYNTH_DIR}/${PROJECT}.dcp   

   # Load the top-level constraint file
   read_xdc [lsearch -all -inline ${XDC_FILES} *${PROJECT}.xdc]

   # Load the synthesized Partial Reconfiguration RTL Block's check points
   foreach rtlPntr ${RECONFIG_NAME} {
      read_checkpoint -cell ${rtlPntr}_Inst ${SYNTH_DIR}/../${rtlPntr}_1/${rtlPntr}.dcp
   }

   # Define each of these sub-modules as partially reconfigurable
   foreach rtlPntr ${RECONFIG_NAME} {
      set_property HD.RECONFIGURABLE 1 [get_cells ${rtlPntr}_Inst]
   }

   # Check for DRC
   report_drc -file ${SYNTH_DIR}/${PROJECT}_reconfig_drc.txt

   # Overwrite the existing synth_1 checkpoint, which is the 
   # checkpoint that impl_1 will refer to
   write_checkpoint -force ${SYNTH_DIR}/${PROJECT}.dcp   
   
   # Generate new top level reports to update GUI display
   report_utilization -file ${SYNTH_DIR}/${PROJECT}_utilization_synth.rpt -pb ${SYNTH_DIR}/${PROJECT}_utilization_synth.pb
   
   # Close the opened design before launching the impl_1
   close_design
}

# Export static checkpoint
proc ExportStaticReconfigDcp { } {

   # Get variables
   set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
   source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl
   source -quiet ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl
   
   # Set common variables
   set IMPL_DIR ${OUT_DIR}/${PROJECT}_project.runs/impl_1
   
   # Make a copy of the .dcp file with a "_static" suffix for 
   # the Makefile system to copy over
   file copy -force ${IMPL_DIR}/${PROJECT}_routed.dcp ${IMPL_DIR}/${PROJECT}_static.dcp   
   
   # Make a copy of the .bit file with a "_static" suffix for 
   # the Makefile system to copy over
   file copy -force ${IMPL_DIR}/${PROJECT}.bit ${IMPL_DIR}/${PROJECT}_static.bit
}

# Import static checkpoint
proc ImportStaticReconfigDcp { } {

   # Get variables
   set VIVADO_BUILD_DIR    $::env(VIVADO_BUILD_DIR)
   set RECONFIG_CHECKPOINT $::env(RECONFIG_CHECKPOINT)
   source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl
   source -quiet ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl
   
   # Set common variables
   set SYNTH_DIR ${OUT_DIR}/${PROJECT}_project.runs/synth_1
   
   # Backup the Partial Reconfiguration RTL Block checkpoint and reports
   file copy   -force ${SYNTH_DIR}/${PROJECT}.dcp                   ${SYNTH_DIR}/${PROJECT}_backup.dcp
   file rename -force ${SYNTH_DIR}/${PROJECT}_utilization_synth.rpt ${SYNTH_DIR}/${PROJECT}_utilization_synth_backup.rpt
   file rename -force ${SYNTH_DIR}/${PROJECT}_utilization_synth.pb  ${SYNTH_DIR}/${PROJECT}_utilization_synth_backup.pb
   
   # Open the static design check point
   open_checkpoint ${RECONFIG_CHECKPOINT}   
   
   # Clear out the targeted reconfigurable module logic
   update_design -cell ${PROJECT}_Inst -black_box 
   
   # Lock down all placement and routing of the static design
   lock_design -level routing     

   # Read the targeted reconfiguration RTL block's checkpoint
   read_checkpoint -cell ${PROJECT}_Inst ${SYNTH_DIR}/${PROJECT}.dcp   
   
   # Check for DRC
   report_drc -file ${SYNTH_DIR}/${PROJECT}_reconfig_drc.txt   

   # Overwrite the existing synth_1 checkpoint, which is the 
   # checkpoint that impl_1 will refer to
   write_checkpoint -force ${SYNTH_DIR}/${PROJECT}.dcp   
   
   # Generate new top level reports to update GUI display
   report_utilization -file ${SYNTH_DIR}/${PROJECT}_utilization_synth.rpt -pb ${SYNTH_DIR}/${PROJECT}_utilization_synth.pb
   
   # Close the opened design before launching the impl_1
   close_design
}

# Export partial configuration bit file
proc ExportPartialReconfigBit { } {

   # Get variables
   set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
   source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl
   source -quiet ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl
   
   # Set common variables
   set IMPL_DIR ${OUT_DIR}/${PROJECT}_project.runs/impl_1
 
   # Make a copy of the partial .bit file with a "_static" suffix for 
   # the Makefile system to copy over
   file copy -force ${IMPL_DIR}/${PROJECT}_pblock_${PROJECT}_partial.bit ${IMPL_DIR}/${PROJECT}_dynamic.bit
}

###############################################################
#### Hardware Debugging Functions #############################
###############################################################

# Create a Debug Core Function
proc CreateDebugCore {ilaName} {
   
   # Delete the Core if it already exist
   delete_debug_core -quiet [get_debug_cores ${ilaName}]

   # Create the debug core
   create_debug_core ${ilaName} labtools_ila_v3
   set_property C_DATA_DEPTH 1024       [get_debug_cores ${ilaName}]
   set_property C_INPUT_PIPE_STAGES 2   [get_debug_cores ${ilaName}]
   
   # set_property C_EN_STRG_QUAL true     [get_debug_cores ${ilaName}]
   
   # Force a reset of the implementation
   reset_run impl_1
}

# Sets the clock on the debug core
proc SetDebugCoreClk {ilaName clkNetName} {
   set_property port_width 1 [get_debug_ports  ${ilaName}/clk]
   connect_debug_port ${ilaName}/clk [get_nets ${clkNetName}]
}

# Get Current Debug Probe Function
proc GetCurrentProbe {ilaName} {
   return ${ilaName}/probe[expr [llength [get_debug_ports ${ilaName}/probe*]] - 1]
}

# Probe Configuring function
proc ConfigProbe {ilaName netName} {
   
   # determine the probe index
   set probeIndex ${ilaName}/probe[expr [llength [get_debug_ports ${ilaName}/probe*]] - 1]
   
   # get the list of netnames
   set probeNet [lsort -increasing -dictionary [get_nets ${netName}]]
   
   # calculate the probe width
   set probeWidth [llength ${probeNet}]
   
   # set the width of the probe
   set_property port_width ${probeWidth} [get_debug_ports ${probeIndex}]   
   
   # connect the probe to the ila module
   connect_debug_port ${probeIndex} ${probeNet}

   # increment the probe index
   create_debug_port ${ilaName} probe
}

# Write the port map file
proc WriteDebugProbes {ilaName filePath} {

   # Delete the last unused port
   delete_debug_port [get_debug_ports [GetCurrentProbe ${ilaName}]]

   # Write the port map file
   write_debug_probes -force ${filePath}
}
