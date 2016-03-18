##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

# Reset the counter
set CNT 1

# Note: Builds happen in clusters of up to $(PARALLEL_BUILD) 
# builds at a time to prevent over subscribing the server 
foreach target $::env(TARGET_DIRS) {
   # Update the command string
   set CMD   "cd $::env(SETUP_DIR); source $::env(SETUP_NAME); cd ${target}; make"   
   set TITLE [file tail ${target}]
   # Check the counter
   if { ${CNT} != $::env(PARALLEL_BUILD) } {
      # Increment the counter
      set CNT [expr ${CNT} + 1]
      # Lauch the build in the background
      exec konsole --new-tab -p tabtitle=${TITLE} --noclose -e tcsh -e -c "${CMD}"  &
   } else {
      # Reset the counter
      set CNT 1
      # Lauch the build in non-background to throttle the CPU usage
      exec tcsh -e -c "${CMD}" >@stdout
   }
}
