##-----------------------------------------------------------------------------
## File       : GigEthLvdsUltraScaleWrapper.xdc
## Company    : SLAC National Accelerator Laboratory
##-----------------------------------------------------------------------------
## Description: Wrapper for SGMII/LVDS Ethernet
##-----------------------------------------------------------------------------
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##-----------------------------------------------------------------------------

# Relax timing for the refRstCnt counter (clocked at 625MHz but it has a CE at half the rate)
set_multicycle_path -through [get_pins -of_objects [get_cells {refRstCnt_reg*}] -filter {REF_PIN_NAME==Q}] -setup -start 2
set_multicycle_path -through [get_pins -of_objects [get_cells {refRstCnt_reg*}] -filter {REF_PIN_NAME==Q}] -hold  -start 1
set_multicycle_path -through [get_pins -of_objects [get_cells {refRst_reg*}]    -filter {REF_PIN_NAME==Q}] -setup -start 2
set_multicycle_path -through [get_pins -of_objects [get_cells {refRst_reg*}]    -filter {REF_PIN_NAME==Q}] -hold  -start 1


