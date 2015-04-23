#-------------------------------------------------------------------------------
#-- Title         : HPS Front End Board Constraints
#-- File          : FrontEndBoard.xdc
#-- Author        : Ben Reese <bareese@slac.stanford.edu>
#-- Created       : 11/20/2013
#-------------------------------------------------------------------------------
#-- Description:
#-- Constrains for the HPS Front End Board
#-------------------------------------------------------------------------------
#-- Copyright (c) 2013 by Ben Reese. All rights reserved.
#-------------------------------------------------------------------------------
#-- Modification history:
#-- 11/20/2013: created.
#-------------------------------------------------------------------------------



#Clocks
create_clock -period 4.000 -name gtCtrlRefClk250 [get_ports gt110RefClk0P]

create_generated_clock -name pgpCtrlClk125 -multiply_by 5 -divide_by 10 -source [get_ports gt110RefClk0P] \
    [get_pins {CtrlClkMmcm_1/MmcmGen.U_Mmcm/CLKOUT0}]

create_generated_clock -name pgpSysClk156  -multiply_by 5 -divide_by 8  -source [get_ports gt110RefClk0P] \
    [get_pins {CtrlClkMmcm_1/MmcmGen.U_Mmcm/CLKOUT1}]

create_clock -period 4.000 -name gtDataRefClk250 [get_ports gt109RefClk0P]

create_generated_clock -name pgpDataClk -multiply_by 5 -divide_by 8 -source [get_ports gt109RefClk0P] \
    [get_pins {DataClkMmcm_1/MmcmGen.U_Mmcm/CLKOUT0}]

create_generated_clock -name axilClk  -multiply_by 5 -divide_by 10  -source [get_ports gt109RefClk0P] \
    [get_pins {DataClkMmcm_1/MmcmGen.U_Mmcm/CLKOUT1}]


#create_generated_clock -name dnaClk -source [get_pins {SysClkMmcm_1/mmcm_adv_inst/CLKOUT0}] -edges {1 3 5} [get_pins {AxiVersion_1/GEN_DEVICE_DNA.DeviceDna_1/r_reg[dnaClk]/Q}]

set_clock_groups -asynchronous \ 
    -group [get_clocks -include_generated_clocks gtCtrlRefClk250] \
    -group [get_clocks -include_generated_clocks gtDataRefClk250] 

set_clock_groups -asynchronous \ 
    -group [get_clocks pgpCtrlClk125] \
    -group [get_clocks pgpSysClk156]

set_clock_groups -asynchronous \ 
    -group [get_clocks pgpDataClk] \
    -group [get_clocks axilClk]


#Assure that sychronization registers are placed in the same slice with no logic between each sync stage
set_property ASYNC_REG TRUE [get_cells -hierarchical *crossDomainSyncReg_reg*]

set_property PACKAGE_PIN AA8 [get_ports gt110RefClk0P] 
set_property PACKAGE_PIN AA7 [get_ports gt110RefClk0N]

set_property PACKAGE_PIN AD10 [get_ports gt109RefClk0P] 
set_property PACKAGE_PIN AD9  [get_ports gt109RefClk0N]

set_property PACKAGE_PIN Y5 [get_ports sysGtRxN]
set_property PACKAGE_PIN Y6 [get_ports sysGtRxP]
set_property PACKAGE_PIN W3 [get_ports sysGtTxN]
set_property PACKAGE_PIN W4 [get_ports sysGtTxP]

set_property PACKAGE_PIN AH1 [get_ports ctrlGtRxN[0]]
set_property PACKAGE_PIN AH2 [get_ports ctrlGtRxP[0]]
set_property PACKAGE_PIN AH5 [get_ports ctrlGtTxN[0]]
set_property PACKAGE_PIN AH6 [get_ports ctrlGtTxP[0]]

set_property PACKAGE_PIN AH9  [get_ports {dataGtRxN[0]}]
set_property PACKAGE_PIN AH10 [get_ports {dataGtRxP[0]}]
set_property PACKAGE_PIN AK9  [get_ports {dataGtTxN[0]}]
set_property PACKAGE_PIN AK10 [get_ports {dataGtTxP[0]}]

set_property PACKAGE_PIN AJ7 [get_ports {dataGtRxN[1]}]
set_property PACKAGE_PIN AJ8 [get_ports {dataGtRxP[1]}]
set_property PACKAGE_PIN AK5 [get_ports {dataGtTxN[1]}]
set_property PACKAGE_PIN AK6 [get_ports {dataGtTxP[1]}]

set_property PACKAGE_PIN AG7 [get_ports {dataGtRxN[2]}]
set_property PACKAGE_PIN AG8 [get_ports {dataGtRxP[2]}]
set_property PACKAGE_PIN AJ3 [get_ports {dataGtTxN[2]}]
set_property PACKAGE_PIN AJ4 [get_ports {dataGtTxP[2]}]

set_property PACKAGE_PIN AE7 [get_ports {dataGtRxN[3]}]
set_property PACKAGE_PIN AE8 [get_ports {dataGtRxP[3]}]
set_property PACKAGE_PIN AK1 [get_ports {dataGtTxN[3]}]
set_property PACKAGE_PIN AK2 [get_ports {dataGtTxP[3]}]

set_property PACKAGE_PIN Y21  [get_ports {leds[0]}]
set_property PACKAGE_PIN G2   [get_ports {leds[1]}]
set_property PACKAGE_PIN W21  [get_ports {leds[2]}]
set_property PACKAGE_PIN A17  [get_ports {leds[3]}]
set_property IOSTANDARD LVCMOS25 [get_ports leds[0]]
set_property IOSTANDARD LVCMOS25 [get_ports leds[2]]
set_property IOSTANDARD LVCMOS15 [get_ports leds[1]]
set_property IOSTANDARD LVCMOS15 [get_ports leds[3]]

