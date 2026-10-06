#-----------------------------------------------------------------------------
# Company    : SLAC National Accelerator Laboratory
#-----------------------------------------------------------------------------
# Description: PTP cores with local AXI registers and simulation source manifest
#-----------------------------------------------------------------------------
# This file is part of 'SLAC Firmware Standard Library'.
# It is subject to the license terms in the LICENSE.txt file found in the
# top-level directory of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of 'SLAC Firmware Standard Library', including this file,
# may be copied, modified, propagated, or distributed except according to
# the terms contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------
source $::env(RUCKUS_PROC_TCL)
loadSource -lib surf -dir "$::DIR_PATH/rtl"
# Includes the direct PtpPort transaction/measurement fixture and PHY fixtures.
loadSource -lib surf -sim_only -dir "$::DIR_PATH/wrappers"

# PTP lane compositions are family-specific; PHY adapters and checkpoints are
# owned by GigEthCore and loaded by its normal family manifests.
set family [getFpgaArch]
if { (${family} eq {kintexu} || ${family} eq {virtexu}) &&
     $::env(VIVADO_VERSION) >= 2016.4 } {
   loadSource -lib surf -dir "$::DIR_PATH/gthUltraScale/rtl"
}
if { (${family} eq {kintexuplus} || ${family} eq {zynquplus} ||
      ${family} eq {zynquplusRFSOC} || ${family} eq {virtexuplus} ||
      ${family} eq {virtexuplusHBM}) && $::env(VIVADO_VERSION) >= 2017.3 } {
   loadSource -lib surf -dir "$::DIR_PATH/gtyUltraScale+/rtl"
}
