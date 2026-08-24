##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file, may be
## copied, modified, propagated, or distributed except according to the terms
## contained in the LICENSE.txt file.
##############################################################################

# SynchronizerHandshake is a clock-enable-controlled bundled-data CDC. Limit
# the held source vector path to the smaller clock period so it settles well
# before the synchronized request enables the destination capture registers.
set srcDataRegs [get_cells -quiet -hierarchical -regexp {(^|.*/)srcDataReg_reg(\[[0-9]+\])?$}]
set destDataRegs [get_cells -quiet -hierarchical -regexp {(^|.*/)destDataReg_reg(\[[0-9]+\])?$}]

if {([llength $srcDataRegs] > 0) && ([llength $destDataRegs] > 0)} {
   set srcClkPins [get_pins -quiet -of_objects $srcDataRegs -filter {REF_PIN_NAME == C}]
   set destClkPins [get_pins -quiet -of_objects $destDataRegs -filter {REF_PIN_NAME == C}]
   set srcClks [get_clocks -quiet -of_objects $srcClkPins]
   set destClks [get_clocks -quiet -of_objects $destClkPins]

   if {([llength $srcClks] > 0) && ([llength $destClks] > 0)} {
      set srcPeriod [get_property PERIOD [lindex $srcClks 0]]
      set destPeriod [get_property PERIOD [lindex $destClks 0]]
      set maxDelay [expr {min(double($srcPeriod), double($destPeriod))}]
      set_max_delay -datapath_only -from $srcDataRegs -to $destDataRegs $maxDelay
   } else {
      puts "WARNING: SynchronizerHandshake.xdc could not resolve source and destination clocks"
   }
} else {
   puts "WARNING: SynchronizerHandshake.xdc could not resolve bundled-data registers"
}
