##-----------------------------------------------------------------------------
## File       : GigEthLvdsClockMux.xdc
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

set c0 [create_generated_clock -divide_by 1 -add -name [get_property NAME [get_pins {U_BUFGMUX_100_1K/I0}]] -master_clock [get_clocks -of [get_ports clk125p0]] -source [get_pins {U_BUFGMUX_100_1K/I0}] [get_pins {U_BUFGMUX_10/O}]]
set c1 [create_generated_clock -divide_by 1 -add -name [get_property NAME [get_pins {U_BUFGMUX_100_1K/I1}]] -master_clock [get_clocks -of [get_ports clk12p50]] -source [get_pins {U_BUFGMUX_100_1K/I1}] [get_pins {U_BUFGMUX_10/O}]]
set c2 [create_generated_clock -divide_by 1 -add -name [get_property NAME [get_pins {U_BUFGMUX_10/I1}]]     -master_clock [get_clocks -of [get_ports clk1p250]] -source [get_pins {U_BUFGMUX_10/I1}] [get_pins {U_BUFGMUX_10/O}]]

set_clock_groups -physically_exclusive -group [get_clocks $c0] -group [get_clocks $c1] -group [get_clocks $c2]
