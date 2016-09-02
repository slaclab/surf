##############################################################################
## This file is part of 'AxiPcieCore'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'AxiPcieCore', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################
######################################
# BITSTREAM: .bit file Configuration #
######################################

set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]   
set_property BITSTREAM.CONFIG.BPI_SYNC_MODE Type2 [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN Pullup [current_design]
set_property CONFIG_MODE BPI16 [current_design]
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 2.5 [current_design]

##############################
# StdLib: Custom Constraints #
##############################

set_property ASYNC_REG TRUE [get_cells -hierarchical *crossDomainSyncReg_reg*]

######################
# FLASH: Constraints #
######################

set_property -dict { PACKAGE_PIN J23 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[0] }]
set_property -dict { PACKAGE_PIN K23 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[1] }]
set_property -dict { PACKAGE_PIN K22 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[2] }]
set_property -dict { PACKAGE_PIN L22 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[3] }]
set_property -dict { PACKAGE_PIN J25 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[4] }]
set_property -dict { PACKAGE_PIN J24 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[5] }]
set_property -dict { PACKAGE_PIN H22 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[6] }]
set_property -dict { PACKAGE_PIN H24 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[7] }]
set_property -dict { PACKAGE_PIN H23 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[8] }]
set_property -dict { PACKAGE_PIN G21 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[9] }]
set_property -dict { PACKAGE_PIN H21 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[10] }]
set_property -dict { PACKAGE_PIN H26 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[11] }]
set_property -dict { PACKAGE_PIN J26 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[12] }]
set_property -dict { PACKAGE_PIN E26 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[13] }]
set_property -dict { PACKAGE_PIN F25 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[14] }]
set_property -dict { PACKAGE_PIN G26 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[15] }]
set_property -dict { PACKAGE_PIN K17 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[16] }]
set_property -dict { PACKAGE_PIN K16 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[17] }]
set_property -dict { PACKAGE_PIN L20 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[18] }]
set_property -dict { PACKAGE_PIN J19 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[19] }]
set_property -dict { PACKAGE_PIN J18 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[20] }]
set_property -dict { PACKAGE_PIN J20 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[21] }]
set_property -dict { PACKAGE_PIN K20 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[22] }]
set_property -dict { PACKAGE_PIN G20 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[23] }]
set_property -dict { PACKAGE_PIN H19 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[24] }]
set_property -dict { PACKAGE_PIN E20 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[25] }]
set_property -dict { PACKAGE_PIN F19 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[26] }]
set_property -dict { PACKAGE_PIN F20 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[27] }]
set_property -dict { PACKAGE_PIN G19 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[28] }]

set_property -dict { PACKAGE_PIN B24 IOSTANDARD LVCMOS25 } [get_ports { flashData[0] }]
set_property -dict { PACKAGE_PIN A25 IOSTANDARD LVCMOS25 } [get_ports { flashData[1] }]
set_property -dict { PACKAGE_PIN B22 IOSTANDARD LVCMOS25 } [get_ports { flashData[2] }]
set_property -dict { PACKAGE_PIN A22 IOSTANDARD LVCMOS25 } [get_ports { flashData[3] }]
set_property -dict { PACKAGE_PIN A23 IOSTANDARD LVCMOS25 } [get_ports { flashData[4] }]
set_property -dict { PACKAGE_PIN A24 IOSTANDARD LVCMOS25 } [get_ports { flashData[5] }]
set_property -dict { PACKAGE_PIN D26 IOSTANDARD LVCMOS25 } [get_ports { flashData[6] }]
set_property -dict { PACKAGE_PIN C26 IOSTANDARD LVCMOS25 } [get_ports { flashData[7] }]
set_property -dict { PACKAGE_PIN C24 IOSTANDARD LVCMOS25 } [get_ports { flashData[8] }]
set_property -dict { PACKAGE_PIN D21 IOSTANDARD LVCMOS25 } [get_ports { flashData[9] }]
set_property -dict { PACKAGE_PIN C22 IOSTANDARD LVCMOS25 } [get_ports { flashData[10] }]
set_property -dict { PACKAGE_PIN B20 IOSTANDARD LVCMOS25 } [get_ports { flashData[11] }]
set_property -dict { PACKAGE_PIN A20 IOSTANDARD LVCMOS25 } [get_ports { flashData[12] }]
set_property -dict { PACKAGE_PIN E22 IOSTANDARD LVCMOS25 } [get_ports { flashData[13] }]
set_property -dict { PACKAGE_PIN C21 IOSTANDARD LVCMOS25 } [get_ports { flashData[14] }]
set_property -dict { PACKAGE_PIN B21 IOSTANDARD LVCMOS25 } [get_ports { flashData[15] }]

set_property -dict { PACKAGE_PIN L18 IOSTANDARD LVCMOS25 } [get_ports { flashWe }]
set_property -dict { PACKAGE_PIN M17 IOSTANDARD LVCMOS25 } [get_ports { flashOe }]
set_property -dict { PACKAGE_PIN C23 IOSTANDARD LVCMOS25 } [get_ports { flashCe }]

####################
# PCIe Constraints #
####################

set_property PACKAGE_PIN F2 [get_ports pciTxP[3]]
set_property PACKAGE_PIN F1 [get_ports pciTxN[3]]
set_property PACKAGE_PIN G4 [get_ports pciRxP[3]]
set_property PACKAGE_PIN G3 [get_ports pciRxN[3]]

set_property PACKAGE_PIN D2 [get_ports pciTxP[2]]
set_property PACKAGE_PIN D1 [get_ports pciTxN[2]]
set_property PACKAGE_PIN E4 [get_ports pciRxP[2]]
set_property PACKAGE_PIN E3 [get_ports pciRxN[2]]

set_property PACKAGE_PIN B2 [get_ports pciTxP[1]]
set_property PACKAGE_PIN B1 [get_ports pciTxN[1]]
set_property PACKAGE_PIN C4 [get_ports pciRxP[1]]
set_property PACKAGE_PIN C3 [get_ports pciRxN[1]]

set_property PACKAGE_PIN A4 [get_ports pciTxP[0]]
set_property PACKAGE_PIN A3 [get_ports pciTxN[0]]
set_property PACKAGE_PIN B6 [get_ports pciRxP[0]]
set_property PACKAGE_PIN B5 [get_ports pciRxN[0]]

set_property PACKAGE_PIN D6  [get_ports pciRefClkP]
set_property PACKAGE_PIN D5  [get_ports pciRefClkN]
create_clock -name pciRefClkP -period 10 [get_ports pciRefClkP]
create_generated_clock -name dnaClk [get_pins {U_Core/U_REG/U_Version/GEN_DEVICE_DNA.DeviceDna_1/GEN_7SERIES.DeviceDna7Series_Inst/BUFR_Inst/O}]
create_generated_clock -name pciClk [get_pins {U_Core/U_AxiPciePhy/U_AxiPcie/U0/comp_axi_enhanced_pcie/comp_enhanced_core_top_wrap/axi_pcie_enhanced_core_top_i/pcie_7x_v2_0_2_inst/pcie_top_with_gt_top.gt_ges.gt_top_i/pipe_wrapper_i/pipe_clock_int.pipe_clock_i/mmcm_i/CLKOUT3}]
set_clock_groups -asynchronous -group [get_clocks {dnaClk}] -group [get_clocks {pciClk}]

set_property -dict { PACKAGE_PIN J8 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { pciRstL }]
set_false_path -from [get_ports pciRstL]
