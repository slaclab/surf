#-----------------------------------------------------------------------------
# This file is part of 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

source $::env(RUCKUS_PROC_TCL)

loadSource -lib surf -dir "$::DIR_PATH/rtl" -fileType "VHDL 2008"
loadSource -lib surf -sim_only -dir "$::DIR_PATH/sim"

set family [getFpgaArch]

if { ${family} eq {artix7}  ||
     ${family} eq {kintex7} ||
     ${family} eq {virtex7} ||
     ${family} eq {zynq} } {
   loadRuckusTcl "$::DIR_PATH/7Series"
}

if { ${family} eq {kintexu}         ||
     ${family} eq {virtexu}         ||
     ${family} eq {kintexuplus}     ||
     ${family} eq {zynquplus}       ||
     ${family} eq {zynquplusRFSOC}  ||
     ${family} eq {qzynquplusRFSOC} ||
     ${family} eq {virtexuplus}     ||
     ${family} eq {virtexuplusHBM} } {
   loadRuckusTcl "$::DIR_PATH/UltraScale"
}
