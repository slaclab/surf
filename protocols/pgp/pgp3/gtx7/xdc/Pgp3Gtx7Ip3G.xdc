##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC Firmware Standard Library', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

create_clock -period 10.24 [get_pins -hier -filter {name=~*gt0_Pgp3Gtx7Ip3G_i*gtxe2_i*TXOUTCLK}]
create_clock -period 10.24 [get_pins -hier -filter {name=~*gt0_Pgp3Gtx7Ip3G_i*gtxe2_i*RXOUTCLK}]
set_false_path -to [get_cells -hierarchical -filter {NAME =~ *data_sync_reg1}]
