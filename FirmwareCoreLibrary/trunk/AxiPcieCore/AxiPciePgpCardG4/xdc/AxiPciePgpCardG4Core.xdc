######################################
# BITSTREAM: .bit file Configuration #
######################################

set_property BITSTREAM.CONFIG.CONFIGRATE 9 [current_design]   
set_property CFGBVS VCCO         [current_design]
set_property CONFIG_VOLTAGE 3.3  [current_design] 

##############################
# StdLib: Custom Constraints #
##############################

set_property ASYNC_REG TRUE [get_cells -hierarchical *crossDomainSyncReg_reg*]

######################
# FLASH: Constraints #
######################

set_property -dict { PACKAGE_PIN T24 IOSTANDARD LVCMOS33 } [get_ports { flashAddr[0] }]
set_property -dict { PACKAGE_PIN T25 IOSTANDARD LVCMOS33 } [get_ports { flashAddr[1] }]
set_property -dict { PACKAGE_PIN T27 IOSTANDARD LVCMOS33 } [get_ports { flashAddr[2] }]
set_property -dict { PACKAGE_PIN R27 IOSTANDARD LVCMOS33 } [get_ports { flashAddr[3] }]
set_property -dict { PACKAGE_PIN P24 IOSTANDARD LVCMOS33 } [get_ports { flashAddr[4] }]
set_property -dict { PACKAGE_PIN P25 IOSTANDARD LVCMOS33 } [get_ports { flashAddr[5] }]
set_property -dict { PACKAGE_PIN P26 IOSTANDARD LVCMOS33 } [get_ports { flashAddr[6] }]
set_property -dict { PACKAGE_PIN N26 IOSTANDARD LVCMOS33 } [get_ports { flashAddr[7] }]
set_property -dict { PACKAGE_PIN N24 IOSTANDARD LVCMOS33 } [get_ports { flashAddr[8] }]
set_property -dict { PACKAGE_PIN M24 IOSTANDARD LVCMOS33 } [get_ports { flashAddr[9] }]
set_property -dict { PACKAGE_PIN M25 IOSTANDARD LVCMOS33 } [get_ports { flashAddr[10] }]
set_property -dict { PACKAGE_PIN M26 IOSTANDARD LVCMOS33 } [get_ports { flashAddr[11] }]
set_property -dict { PACKAGE_PIN L22 IOSTANDARD LVCMOS33 } [get_ports { flashAddr[12] }]
set_property -dict { PACKAGE_PIN K23 IOSTANDARD LVCMOS33 } [get_ports { flashAddr[13] }]
set_property -dict { PACKAGE_PIN L25 IOSTANDARD LVCMOS33 } [get_ports { flashAddr[14] }]
set_property -dict { PACKAGE_PIN K25 IOSTANDARD LVCMOS33 } [get_ports { flashAddr[15] }]
set_property -dict { PACKAGE_PIN L23 IOSTANDARD LVCMOS33 } [get_ports { flashAddr[16] }]
set_property -dict { PACKAGE_PIN L24 IOSTANDARD LVCMOS33 } [get_ports { flashAddr[17] }]
set_property -dict { PACKAGE_PIN M27 IOSTANDARD LVCMOS33 } [get_ports { flashAddr[18] }]
set_property -dict { PACKAGE_PIN L27 IOSTANDARD LVCMOS33 } [get_ports { flashAddr[19] }]
set_property -dict { PACKAGE_PIN J23 IOSTANDARD LVCMOS33 } [get_ports { flashAddr[20] }]
set_property -dict { PACKAGE_PIN H24 IOSTANDARD LVCMOS33 } [get_ports { flashAddr[21] }]
set_property -dict { PACKAGE_PIN J26 IOSTANDARD LVCMOS33 } [get_ports { flashAddr[22] }]
set_property -dict { PACKAGE_PIN H26 IOSTANDARD LVCMOS33 } [get_ports { flashAddr[23] }]

set_property -dict { PACKAGE_PIN M20 IOSTANDARD LVCMOS33 PULLUP true} [get_ports { flashData[4] }]
set_property -dict { PACKAGE_PIN L20 IOSTANDARD LVCMOS33 PULLUP true} [get_ports { flashData[5] }]
set_property -dict { PACKAGE_PIN R21 IOSTANDARD LVCMOS33 PULLUP true} [get_ports { flashData[6] }]
set_property -dict { PACKAGE_PIN R22 IOSTANDARD LVCMOS33 PULLUP true} [get_ports { flashData[7] }]
set_property -dict { PACKAGE_PIN P20 IOSTANDARD LVCMOS33 PULLUP true} [get_ports { flashData[8] }]
set_property -dict { PACKAGE_PIN P21 IOSTANDARD LVCMOS33 PULLUP true} [get_ports { flashData[9] }]
set_property -dict { PACKAGE_PIN N22 IOSTANDARD LVCMOS33 PULLUP true} [get_ports { flashData[10] }]
set_property -dict { PACKAGE_PIN M22 IOSTANDARD LVCMOS33 PULLUP true} [get_ports { flashData[11] }]
set_property -dict { PACKAGE_PIN R23 IOSTANDARD LVCMOS33 PULLUP true} [get_ports { flashData[12] }]
set_property -dict { PACKAGE_PIN P23 IOSTANDARD LVCMOS33 PULLUP true} [get_ports { flashData[13] }]
set_property -dict { PACKAGE_PIN R25 IOSTANDARD LVCMOS33 PULLUP true} [get_ports { flashData[14] }]
set_property -dict { PACKAGE_PIN R26 IOSTANDARD LVCMOS33 PULLUP true} [get_ports { flashData[15] }]

set_property -dict { PACKAGE_PIN G25 IOSTANDARD LVCMOS33 } [get_ports { flashOe }]
set_property -dict { PACKAGE_PIN G26 IOSTANDARD LVCMOS33 } [get_ports { flashWe }]

####################
# PCIe Constraints #
####################

set_property PACKAGE_PIN AN4 [get_ports pciTxP[7]]
set_property PACKAGE_PIN AN3 [get_ports pciTxN[7]]
set_property PACKAGE_PIN AP2 [get_ports pciRxP[7]]
set_property PACKAGE_PIN AP1 [get_ports pciRxN[7]]

set_property PACKAGE_PIN AM6 [get_ports pciTxP[6]]
set_property PACKAGE_PIN AM5 [get_ports pciTxN[6]]
set_property PACKAGE_PIN AM2 [get_ports pciRxP[6]]
set_property PACKAGE_PIN AM1 [get_ports pciRxN[6]]

set_property PACKAGE_PIN AL4 [get_ports pciTxP[5]]
set_property PACKAGE_PIN AL3 [get_ports pciTxN[5]]
set_property PACKAGE_PIN AK2 [get_ports pciRxP[5]]
set_property PACKAGE_PIN AK1 [get_ports pciRxN[5]]

set_property PACKAGE_PIN AK6 [get_ports pciTxP[4]]
set_property PACKAGE_PIN AK5 [get_ports pciTxN[4]]
set_property PACKAGE_PIN AJ4 [get_ports pciRxP[4]]
set_property PACKAGE_PIN AJ3 [get_ports pciRxN[4]]

set_property PACKAGE_PIN AH6 [get_ports pciTxP[3]]
set_property PACKAGE_PIN AH5 [get_ports pciTxN[3]]
set_property PACKAGE_PIN AH2 [get_ports pciRxP[3]]
set_property PACKAGE_PIN AH1 [get_ports pciRxN[3]]

set_property PACKAGE_PIN AG4 [get_ports pciTxP[2]]
set_property PACKAGE_PIN AG3 [get_ports pciTxN[2]]
set_property PACKAGE_PIN AF2 [get_ports pciRxP[2]]
set_property PACKAGE_PIN AF1 [get_ports pciRxN[2]]

set_property PACKAGE_PIN AE4 [get_ports pciTxP[1]]
set_property PACKAGE_PIN AE3 [get_ports pciTxN[1]]
set_property PACKAGE_PIN AD2 [get_ports pciRxP[1]]
set_property PACKAGE_PIN AD1 [get_ports pciRxN[1]]

set_property PACKAGE_PIN AC4 [get_ports pciTxP[0]]
set_property PACKAGE_PIN AC3 [get_ports pciTxN[0]]
set_property PACKAGE_PIN AB2 [get_ports pciRxP[0]]
set_property PACKAGE_PIN AB1 [get_ports pciRxN[0]]

set_property PACKAGE_PIN AB6  [get_ports pciRefClkP]
set_property PACKAGE_PIN AB5  [get_ports pciRefClkN]
create_clock -name pciRefClkP -period 10 [get_ports pciRefClkP]
create_generated_clock -name dnaClk [get_pins {U_Core/U_REG/U_Version/GEN_DEVICE_DNA.DeviceDna_1/GEN_ULTRA_SCALE.DeviceDnaUltraScale_Inst/BUFGCE_DIV_Inst/O}]
create_generated_clock -name pciClk [get_pins {U_Core/U_AxiPciePhy/U_AxiPcie/inst/pcie3_ip_i/inst/gt_top_i/phy_clk_i/bufg_gt_userclk/O}]
set_clock_groups -asynchronous -group [get_clocks {dnaClk}] -group [get_clocks {pciClk}]

set_property -dict { PACKAGE_PIN K22 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { pciRstL }]
set_false_path -from [get_ports pciRstL]

create_pblock PCIE_PHY_GRP; add_cells_to_pblock [get_pblocks PCIE_PHY_GRP] [get_cells {U_Core/U_AxiPciePhy/U_AxiPcie}]
resize_pblock [get_pblocks PCIE_PHY_GRP] -add {CLOCKREGION_X3Y0:CLOCKREGION_X3Y1}