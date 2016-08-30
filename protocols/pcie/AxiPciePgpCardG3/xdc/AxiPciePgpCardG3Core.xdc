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

set_property -dict { PACKAGE_PIN AB25 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[0] }]
set_property -dict { PACKAGE_PIN AB24 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[1] }]
set_property -dict { PACKAGE_PIN AA25 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[2] }]
set_property -dict { PACKAGE_PIN AA24 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[3] }]
set_property -dict { PACKAGE_PIN AB29 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[4] }]
set_property -dict { PACKAGE_PIN AA29 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[5] }]
set_property -dict { PACKAGE_PIN AB27 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[6] }]
set_property -dict { PACKAGE_PIN AA28 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[7] }]
set_property -dict { PACKAGE_PIN AA27 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[8] }]
set_property -dict { PACKAGE_PIN AC29 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[9] }]
set_property -dict { PACKAGE_PIN AC28 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[10] }]
set_property -dict { PACKAGE_PIN AB34 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[11] }]
set_property -dict { PACKAGE_PIN AA34 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[12] }]
set_property -dict { PACKAGE_PIN AC32 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[13] }]
set_property -dict { PACKAGE_PIN AC31 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[14] }]
set_property -dict { PACKAGE_PIN AA33 IOSTANDARD LVCMOS25 } [get_ports { flashAddr[15] }]
set_property -dict { PACKAGE_PIN M34  IOSTANDARD LVCMOS25 } [get_ports { flashAddr[16] }]
set_property -dict { PACKAGE_PIN N34  IOSTANDARD LVCMOS25 } [get_ports { flashAddr[17] }]
set_property -dict { PACKAGE_PIN R33  IOSTANDARD LVCMOS25 } [get_ports { flashAddr[18] }]
set_property -dict { PACKAGE_PIN N33  IOSTANDARD LVCMOS25 } [get_ports { flashAddr[19] }]
set_property -dict { PACKAGE_PIN N32  IOSTANDARD LVCMOS25 } [get_ports { flashAddr[20] }]
set_property -dict { PACKAGE_PIN R32  IOSTANDARD LVCMOS25 } [get_ports { flashAddr[21] }]
set_property -dict { PACKAGE_PIN T32  IOSTANDARD LVCMOS25 } [get_ports { flashAddr[22] }]
set_property -dict { PACKAGE_PIN U32  IOSTANDARD LVCMOS25 } [get_ports { flashAddr[23] }]
set_property -dict { PACKAGE_PIN U31  IOSTANDARD LVCMOS25 } [get_ports { flashAddr[24] }]
set_property -dict { PACKAGE_PIN M32  IOSTANDARD LVCMOS25 } [get_ports { flashAddr[25] }]
set_property -dict { PACKAGE_PIN N31  IOSTANDARD LVCMOS25 } [get_ports { flashAddr[26] }]
set_property -dict { PACKAGE_PIN P31  IOSTANDARD LVCMOS25 } [get_ports { flashAddr[27] }]
set_property -dict { PACKAGE_PIN R31  IOSTANDARD LVCMOS25 } [get_ports { flashAddr[28] }]

set_property -dict { PACKAGE_PIN V28 IOSTANDARD LVCMOS25 PULLUP true} [get_ports { flashData[0] }]
set_property -dict { PACKAGE_PIN V29 IOSTANDARD LVCMOS25 PULLUP true} [get_ports { flashData[1] }]
set_property -dict { PACKAGE_PIN V26 IOSTANDARD LVCMOS25 PULLUP true} [get_ports { flashData[2] }]
set_property -dict { PACKAGE_PIN V27 IOSTANDARD LVCMOS25 PULLUP true} [get_ports { flashData[3] }]
set_property -dict { PACKAGE_PIN W28 IOSTANDARD LVCMOS25 PULLUP true} [get_ports { flashData[4] }]
set_property -dict { PACKAGE_PIN W29 IOSTANDARD LVCMOS25 PULLUP true} [get_ports { flashData[5] }]
set_property -dict { PACKAGE_PIN W25 IOSTANDARD LVCMOS25 PULLUP true} [get_ports { flashData[6] }]
set_property -dict { PACKAGE_PIN Y25 IOSTANDARD LVCMOS25 PULLUP true} [get_ports { flashData[7] }]
set_property -dict { PACKAGE_PIN Y28 IOSTANDARD LVCMOS25 PULLUP true} [get_ports { flashData[8] }]
set_property -dict { PACKAGE_PIN V31 IOSTANDARD LVCMOS25 PULLUP true} [get_ports { flashData[9] }]
set_property -dict { PACKAGE_PIN V32 IOSTANDARD LVCMOS25 PULLUP true} [get_ports { flashData[10] }]
set_property -dict { PACKAGE_PIN W33 IOSTANDARD LVCMOS25 PULLUP true} [get_ports { flashData[11] }]
set_property -dict { PACKAGE_PIN W34 IOSTANDARD LVCMOS25 PULLUP true} [get_ports { flashData[12] }]
set_property -dict { PACKAGE_PIN V34 IOSTANDARD LVCMOS25 PULLUP true} [get_ports { flashData[13] }]
set_property -dict { PACKAGE_PIN Y32 IOSTANDARD LVCMOS25 PULLUP true} [get_ports { flashData[14] }]
set_property -dict { PACKAGE_PIN Y33 IOSTANDARD LVCMOS25 PULLUP true} [get_ports { flashData[15] }]

set_property -dict { PACKAGE_PIN Y27 IOSTANDARD LVCMOS25 } [get_ports { flashCe }]
set_property -dict { PACKAGE_PIN U34 IOSTANDARD LVCMOS25 } [get_ports { flashOe }]
set_property -dict { PACKAGE_PIN T34 IOSTANDARD LVCMOS25 } [get_ports { flashWe }]

####################
# PCIe Constraints #
####################

set_property PACKAGE_PIN B23 [get_ports pciTxP[3]]
set_property PACKAGE_PIN A23 [get_ports pciTxN[3]]
set_property PACKAGE_PIN F21 [get_ports pciRxP[3]]
set_property PACKAGE_PIN E21 [get_ports pciRxN[3]]

set_property PACKAGE_PIN D22 [get_ports pciTxP[2]]
set_property PACKAGE_PIN C22 [get_ports pciTxN[2]]
set_property PACKAGE_PIN D20 [get_ports pciRxP[2]]
set_property PACKAGE_PIN C20 [get_ports pciRxN[2]]

set_property PACKAGE_PIN B21 [get_ports pciTxP[1]]
set_property PACKAGE_PIN A21 [get_ports pciTxN[1]]
set_property PACKAGE_PIN F19 [get_ports pciRxP[1]]
set_property PACKAGE_PIN E19 [get_ports pciRxN[1]]

set_property PACKAGE_PIN B19 [get_ports pciTxP[0]]
set_property PACKAGE_PIN A19 [get_ports pciTxN[0]]
set_property PACKAGE_PIN D18 [get_ports pciRxP[0]]
set_property PACKAGE_PIN C18 [get_ports pciRxN[0]]

set_property PACKAGE_PIN H18  [get_ports pciRefClkP]
set_property PACKAGE_PIN G18  [get_ports pciRefClkN]
create_clock -name pciRefClkP -period 10 [get_ports pciRefClkP]
create_generated_clock -name dnaClk [get_pins {U_Core/U_REG/U_Version/GEN_DEVICE_DNA.DeviceDna_1/GEN_7SERIES.DeviceDna7Series_Inst/BUFR_Inst/O}]
create_generated_clock -name pciClk [get_pins {U_Core/U_AxiPciePhy/U_AxiPcie/U0/comp_axi_enhanced_pcie/comp_enhanced_core_top_wrap/axi_pcie_enhanced_core_top_i/pcie_7x_v2_0_2_inst/pcie_top_with_gt_top.gt_ges.gt_top_i/pipe_wrapper_i/pipe_clock_int.pipe_clock_i/mmcm_i/CLKOUT3}]
set_clock_groups -asynchronous -group [get_clocks {dnaClk}] -group [get_clocks {pciClk}]

set_property -dict { PACKAGE_PIN L23 IOSTANDARD LVCMOS33 PULLUP true } [get_ports { pciRstL }]
set_false_path -from [get_ports pciRstL]
