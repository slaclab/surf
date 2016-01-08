##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

# Sources Batch-Mode Build Script

########################################################
## Get variables and Custom Procedures
########################################################
set VIVADO_BUILD_DIR $::env(VIVADO_BUILD_DIR)
source -quiet ${VIVADO_BUILD_DIR}/vivado_env_var_v1.tcl
source -quiet ${VIVADO_BUILD_DIR}/vivado_proc_v1.tcl

# Open the project
open_project -quiet ${VIVADO_PROJECT}

# Add RTL Source Files
foreach rtlPntr ${RTL_FILES} {
   # Add the RTL Files
   add_files -quiet -fileset sources_1 ${rtlPntr}
   # Force Absolute Path (not relative to project)
   set_property PATH_MODE AbsoluteFirst [get_files ${rtlPntr}]
}

# Add Simulation Source Files
if { ${SIM_FILES} != "" } {
   foreach simPntr ${SIM_FILES} {
      # Add the Simulation Files
      add_files -quiet -fileset sim_1 ${simPntr} 
      # Force Absolute Path (not relative to project)
      set_property PATH_MODE AbsoluteFirst [get_files ${simPntr}]
   }
}

# Add Core Files
if { ${CORE_FILES} != "" } {
   foreach corePntr ${CORE_FILES} {
      if { [file extension ${corePntr}] == ".ngc" } {
         add_files -quiet -fileset sources_1 ${corePntr}
      } else {
         import_ip -quiet -srcset sources_1 ${corePntr}
      }
   }
}

# Add XDC FILES
if { ${XDC_FILES} != "" } {
   foreach xdcPntr ${XDC_FILES} {
      # Add the Constraint Files
      add_files -quiet -fileset constrs_1 ${xdcPntr}
      # Force Absolute Path (not relative to project)
      set_property PATH_MODE AbsoluteFirst [get_files ${xdcPntr}]
   }   
}  

# Add TCL files 
if { ${TCL_FILES} != "" } {
   foreach tclPntr ${TCL_FILES} {
      # Add the Constraint Files
      add_files -quiet -fileset constrs_1 ${tclPntr}
      # Force Absolute Path (not relative to project)
      set_property PATH_MODE AbsoluteFirst [get_files ${tclPntr}]
   }   
}

# Set the Top Level 
set_property top ${PROJECT} [current_fileset]

# Close and reopen project
VivadoRefresh ${VIVADO_PROJECT}

# Generate all IP cores' output files
generate_target all [get_ips]
if { [get_ips] != "" } {
   foreach corePntr [get_ips] {

      # Build the IP Core
      puts "\nUpgrading ${corePntr}.xci IP Core ..."
      upgrade_ip [get_ips ${corePntr}]
      puts "... Upgrade Complete!\n"
      
      # Check if we need to create the IP_run
      set ipSynthRun ${corePntr}_synth_1
      if { [get_runs ${ipSynthRun}] != ${ipSynthRun}} {
         create_ip_run [get_ips ${corePntr}]
      }

   }
}

# Target specific source setup script
VivadoRefresh ${VIVADO_PROJECT}
SourceTclFile ${VIVADO_DIR}/sources.tcl

# Touch dependency file
exec touch ${PROJECT}_sources.txt

# Close the project
close_project
