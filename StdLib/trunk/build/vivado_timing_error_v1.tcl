
# Timing Error (or Route Error) Message Script
# NOTE: This script sources it's variables from the vivado_post_route_v1.tcl script

if {true} {
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
