
# Custom Procedure Script

# Get environment
set PROJ_DIR $::env(PROJ_DIR)

# Force "pwd" function to be "pwd -L" and not "pwd -P"
proc pwd { } {
   return $::env(PWD)
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
