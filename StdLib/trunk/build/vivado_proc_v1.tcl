
# Custom Procedure Script

###############################################################
#### General Functions ########################################
###############################################################

proc VivadoRefresh { vivadoProject } {
   close_project
   open_project -quiet ${vivadoProject}
}

# Get the number of CPUs available on the Linux box
proc GetCpuNumber { } {
   return [exec cat /proc/cpuinfo | grep processor | wc -l]
}

proc BuildIpCores { } {
   # Get variables
   set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
   source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl

   # Check if the target project has IP cores
   if { [get_ips] != "" } {
      # Clear the list of IP cores
      set ipCoreList ""
      # Loop through each IP core
      foreach corePntr [get_ips] {
         # Set the IP core synthesis run name
         set ipSynthRun ${corePntr}_synth_1
         # Check if we need to build the IP core
         if { [CheckIpSynth ${ipSynthRun}] != true } {
            reset_run  ${ipSynthRun}
            append ipSynthRun " "
            append ipCoreList ${ipSynthRun}
         }
      }
      # Check for IP cores to build
      if { ${ipCoreList} != "" } {
         # Build the IP Core
         launch_runs -quiet ${ipCoreList} -jobs [GetCpuNumber]
         foreach waitPntr ${ipCoreList} {
            wait_on_run ${waitPntr} 
         }
      }      
      foreach corePntr [get_ips] {
         # Disable the IP Core's XDC (so it doesn't get implemented at the project level)
         set xdcPntr [get_files -quiet -of_objects [get_files ${corePntr}.xci] -filter {FILE_TYPE == XDC}]
         if { ${xdcPntr} != "" } {
            set_property is_enabled false [get_files ${xdcPntr}] 
         }                 
         # Create a backup copy of the IP Core in the source tree
         foreach coreFilePntr ${CORE_FILES} {
            if { [ string match *${corePntr}* ${coreFilePntr} ] } { 
               # Search for COEFFICIENT_FILE parameter in original .xci file
               set COEFFICIENT_FILE ""
               set COE_FILE ""
               set LOAD_INIT_FILE ""
               set MEM_FILE ""
               set C_MEM_INIT_FILE ""
               set C_LOAD_INIT_FILE ""
               set C_INIT_FILE ""
               set C_INIT_FILE_NAME ""
               set C_COEF_FILE ""
               set C_COEF_FILE_LINES ""
               set Coefficient_File ""
               set Reload_File ""
               set Gen_MIF_Files ""
               set original  [open ${coreFilePntr} r]
               while { [eof ${original}] != 1 } {
                  gets ${original} line
                  if { [string match *COEFFICIENT_FILE* ${line}] } {
                     set COEFFICIENT_FILE ${line}
                  } elseif { [string match *COE_FILE* ${line}] } {
                     set COE_FILE ${line}
                  } elseif { [string match *LOAD_INIT_FILE* ${line}] } {
                     set LOAD_INIT_FILE ${line}
                  } elseif { [string match *MEM_FILE* ${line}] } {
                     set MEM_FILE ${line}
                  } elseif { [string match *C_MEM_INIT_FILE* ${line}] } {
                     set C_MEM_INIT_FILE ${line}
                  } elseif { [string match *C_LOAD_INIT_FILE* ${line}] } {
                     set C_LOAD_INIT_FILE ${line}
                  } elseif { [string match *C_INIT_FILE* ${line}] } {
                     set C_INIT_FILE ${line}
                  } elseif { [string match *C_INIT_FILE_NAME* ${line}] } {
                     set C_INIT_FILE_NAME ${line}
                  } elseif { [string match *C_COEF_FILE* ${line}] } {
                     set C_COEF_FILE ${line}
                  } elseif { [string match *C_COEF_FILE_LINES* ${line}] } {
                     set C_COEF_FILE_LINES ${line}
                  } elseif { [string match *Coefficient_File* ${line}] } {
                     set Coefficient_File ${line}
                  } elseif { [string match *Reload_File* ${line}] } {
                     set Reload_File ${line}
                  } elseif { [string match *Gen_MIF_Files* ${line}] } {
                     set Gen_MIF_Files ${line}                     
                  }
               }
               close ${original} 
               # Modify the build's IP core with original path(s)
               set in  [open [get_files ${corePntr}.xci] r]
               set out [open ${OUT_DIR}/${corePntr}.xci  w]
               while { [eof ${in}] != 1 } {
                  gets ${in} line
                  if { [string match *COEFFICIENT_FILE* ${line}] } {
                     puts ${out} ${COEFFICIENT_FILE}
                  } elseif { [string match *COE_FILE* ${line}] } {
                     puts ${out} ${COE_FILE}    
                  } elseif { [string match *LOAD_INIT_FILE* ${line}] } {
                     puts ${out} ${LOAD_INIT_FILE}    
                  } elseif { [string match *MEM_FILE* ${line}] } {
                     puts ${out} ${MEM_FILE}    
                  } elseif { [string match *C_MEM_INIT_FILE* ${line}] } {
                     puts ${out} ${C_MEM_INIT_FILE}    
                  } elseif { [string match *C_LOAD_INIT_FILE* ${line}] } {
                     puts ${out} ${C_LOAD_INIT_FILE}    
                  } elseif { [string match *C_INIT_FILE* ${line}] } {
                     puts ${out} ${C_INIT_FILE}    
                  } elseif { [string match *C_INIT_FILE_NAME* ${line}] } {
                     puts ${out} ${C_INIT_FILE_NAME}    
                  } elseif { [string match *C_COEF_FILE* ${line}] } {
                     puts ${out} ${C_COEF_FILE}    
                  } elseif { [string match *C_COEF_FILE_LINES* ${line}] } {
                     puts ${out} ${C_COEF_FILE_LINES}    
                  } elseif { [string match *Coefficient_File* ${line}] } {
                     puts ${out} ${Coefficient_File}    
                  } elseif { [string match *Reload_File* ${line}] } {
                     puts ${out} ${Reload_File}    
                  } elseif { [string match *Gen_MIF_Files* ${line}] } {
                     puts ${out} ${Gen_MIF_Files}    
                  } else { 
                     puts ${out} ${line} 
                  }
               }
               close ${in}
               close ${out}
               # overwrite the existing .xci file in the source tree
               file rename -force ${OUT_DIR}/${corePntr}.xci ${coreFilePntr}
            }
         }         
         # Set the IP core synthesis run name
         set ipSynthRun ${corePntr}_synth_1         
         # Reset the "needs_refresh" flag
         set_property needs_refresh false [get_runs ${ipSynthRun}]
      }
   }   
}

# Checking Timing Function
proc CheckTiming { } {
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
      return false
   } else {
      return true
   }
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
   } elseif { [get_property NEEDS_REFRESH [get_runs impl_1]] == 1 } {
      return false   
   } elseif { [get_property STATUS [get_runs impl_1]] != "write_bitstream Complete!" } {
      return false
   } else {
      return true
   }
}
proc VcsCompleteMessage {dirPath fileName} {
   puts "\n\n********************************************************"
   puts "The VCS simulation script has been generated."
   puts "To complie the simulation:"
   puts "\t\$ cd ${dirPath}/"    
   puts "\t\$ ./${fileName}_sim_vcs_mx.sh"    
   puts "********************************************************\n\n" 
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
   
   # Message Filtering Script
   source -quiet ${VIVADO_BUILD_DIR}/vivado_messages_v1.tcl   
   
   # Set the top level RTL
   set_property top ${rtlName} [current_fileset]
   
   # Synthesize
   launch_runs ${rtlName}_1
   wait_on_run ${rtlName}_1   
}

# Insert the Partial Reconfiguration RTL Block(s) into top level checkpoint checkpoint
proc InsertStaticReconfigDcp { } {

   # Get variables
   set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
   set RECONFIG_NAME    $::env(RECONFIG_NAME)
   source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl
   
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
