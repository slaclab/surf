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
create_clock -period 4.000 -name gtRefClk250 [get_ports gtRefClk250P]

create_generated_clock \
    -name pgpDataClk \
    -source [get_ports gtRefClk250P] \
     -multiply_by 5 -divide_by 8 \
    [get_pins {U_DataClockManager7/MmcmGen.U_Mmcm/CLKOUT1}]

create_generated_clock \
    -name clk250 \
    -source [get_ports gtRefClk250P] \
    -multiply_by 1 \
    [get_pins {U_DataClockManager7/MmcmGen.U_Mmcm/CLKOUT0}]

create_clock -period 8.000 -name gtRefClk125 [get_ports gtRefClk125P]

create_generated_clock -name axiClk -source [get_ports gtRefClk125P] -multiply_by 1 \
    [get_pins {U_CtrlClockManager7/MmcmGen.U_Mmcm/CLKOUT0}]

create_generated_clock \
    -name clk200 \
    -source [get_ports gtRefClk125P] \
    -multiply_by 8 -divide_by 5 \
    [get_pins {U_CtrlClockManager7/MmcmGen.U_Mmcm/CLKOUT1}]


set rxRecClkPin [get_pins {FebPgp_1/Pgp2bGtp7FixedLat_1/Gtp7Core_1/gtpe2_i/RXOUTCLK}]
create_clock -name pgpRxRecClk -period 8 ${rxRecClkPin}

create_clock -name daqRefClk -period 8 [get_ports daqRefClkP]

set_clock_groups  -asynchronous \ 
-group [get_clocks -include_generated_clocks gtRefClk125] \
-group [get_clocks -include_generated_clocks gtRefClk250] \ 
-group [get_clocks -include_generated_clocks daqRefClk] \ 
-group [get_clocks -include_generated_clocks {pgpRxRecClk}] 

set_clock_groups -asynchronous \
    -group [get_clocks -include_generated_clocks pgpDataClk] \
    -group [get_clocks -include_generated_clocks clk250]


#Assure that sychronization registers are placed in the same slice with no logic between each sync stage
set_property ASYNC_REG TRUE [get_cells -hierarchical *crossDomainSyncReg_reg*]

set_property PACKAGE_PIN AA13 [get_ports gtRefClk125P]
set_property PACKAGE_PIN AB13 [get_ports gtRefClk125N]

set_property PACKAGE_PIN AA11 [get_ports daqRefClkP]
set_property PACKAGE_PIN AB11 [get_ports daqRefClkN]

set_property PACKAGE_PIN B20 [get_ports daqClk125P]
set_property PACKAGE_PIN A20 [get_ports daqClk125N]
set_property IOSTANDARD LVDS_25 [get_ports daqClk125P]
set_property IOSTANDARD LVDS_25 [get_ports daqClk125N]

set_property PACKAGE_PIN F11 [get_ports gtRefClk250P]
set_property PACKAGE_PIN E11 [get_ports gtRefClk250N]

set_property PACKAGE_PIN AD12 [get_ports sysGtRxN]
set_property PACKAGE_PIN AC12 [get_ports sysGtRxP]
set_property PACKAGE_PIN AD10 [get_ports sysGtTxN]
set_property PACKAGE_PIN AC10 [get_ports sysGtTxP]

set_property IOSTANDARD LVCMOS25 [get_ports {leds}]
set_property PACKAGE_PIN G20 [get_ports {leds[0]}]
set_property PACKAGE_PIN G21 [get_ports {leds[1]}]
set_property PACKAGE_PIN K21 [get_ports {leds[7]}]
set_property PACKAGE_PIN J21 [get_ports {leds[6]}]
set_property PACKAGE_PIN H21 [get_ports {leds[2]}]
set_property PACKAGE_PIN H22 [get_ports {leds[4]}]
set_property PACKAGE_PIN J23 [get_ports {leds[5]}]
set_property PACKAGE_PIN H23 [get_ports {leds[3]}]

set_property PACKAGE_PIN A11 [get_ports {dataGtRxN[0]}]
set_property PACKAGE_PIN B11 [get_ports {dataGtRxP[0]}]
set_property PACKAGE_PIN A7 [get_ports {dataGtTxN[0]}]
set_property PACKAGE_PIN B7 [get_ports {dataGtTxP[0]}]

set_property PACKAGE_PIN C14 [get_ports {dataGtRxN[1]}]
set_property PACKAGE_PIN D14 [get_ports {dataGtRxP[1]}]
set_property PACKAGE_PIN C8 [get_ports {dataGtTxN[1]}]
set_property PACKAGE_PIN D8 [get_ports {dataGtTxP[1]}]

set_property PACKAGE_PIN A13 [get_ports {dataGtRxN[2]}]
set_property PACKAGE_PIN B13 [get_ports {dataGtRxP[2]}]
set_property PACKAGE_PIN A9 [get_ports {dataGtTxN[2]}]
set_property PACKAGE_PIN B9 [get_ports {dataGtTxP[2]}]

set_property PACKAGE_PIN C12 [get_ports {dataGtRxN[3]}]
set_property PACKAGE_PIN D12 [get_ports {dataGtRxP[3]}]
set_property PACKAGE_PIN C10 [get_ports {dataGtTxN[3]}]
set_property PACKAGE_PIN D10 [get_ports {dataGtTxP[3]}]


#Vivado makes you define IO standard for analog inputs because it is stupid
set_property IOSTANDARD LVCMOS25 [get_ports {vPIn}]
set_property IOSTANDARD LVCMOS25 [get_ports {vNIn}]
set_property IOSTANDARD LVCMOS25 [get_ports {vAuxP[0]}]
set_property IOSTANDARD LVCMOS25 [get_ports {vAuxN[0]}]
set_property IOSTANDARD LVCMOS25 [get_ports {vAuxP[1]}]
set_property IOSTANDARD LVCMOS25 [get_ports {vAuxN[1]}]
set_property IOSTANDARD LVCMOS25 [get_ports {vAuxP[2]}]
set_property IOSTANDARD LVCMOS25 [get_ports {vAuxN[2]}]
set_property IOSTANDARD LVCMOS25 [get_ports {vAuxP[3]}]
set_property IOSTANDARD LVCMOS25 [get_ports {vAuxN[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vAuxP[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vAuxN[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vAuxP[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vAuxN[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vAuxP[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vAuxN[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vAuxP[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vAuxN[7]}]
set_property IOSTANDARD LVCMOS25 [get_ports {vAuxP[8]}]
set_property IOSTANDARD LVCMOS25 [get_ports {vAuxN[8]}]
set_property IOSTANDARD LVCMOS25 [get_ports {vAuxP[9]}]
set_property IOSTANDARD LVCMOS25 [get_ports {vAuxN[9]}]
set_property IOSTANDARD LVCMOS25 [get_ports {vAuxP[10]}]
set_property IOSTANDARD LVCMOS25 [get_ports {vAuxN[10]}]
set_property IOSTANDARD LVCMOS25 [get_ports {vAuxP[11]}]
set_property IOSTANDARD LVCMOS25 [get_ports {vAuxN[11]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vAuxP[12]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vAuxN[12]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vAuxP[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vAuxN[13]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vAuxP[14]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vAuxN[14]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vAuxP[15]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vAuxN[15]}]

# set_property PACKAGE_PIN N12 [get_ports {vPIn}]
# set_property PACKAGE_PIN P11 [get_ports {vNIn}]
# set_property PACKAGE_PIN K15 [get_ports {vAuxP[0]}]
# set_property PACKAGE_PIN J16 [get_ports {vAuxN[0]}]
# set_property PACKAGE_PIN K16 [get_ports {vAuxP[1]}]
# set_property PACKAGE_PIN K17 [get_ports {vAuxN[1]}]
# set_property PACKAGE_PIN J19 [get_ports {vAuxP[2]}]
# set_property PACKAGE_PIN H19 [get_ports {vAuxN[2]}]
# set_property PACKAGE_PIN K20 [get_ports {vAuxP[3]}]
# set_property PACKAGE_PIN J20 [get_ports {vAuxN[3]}]
# set_property PACKAGE_PIN E6 [get_ports {vAuxP[4]}]
# set_property PACKAGE_PIN D6 [get_ports {vAuxN[4]}]
# set_property PACKAGE_PIN H7 [get_ports {vAuxP[5]}]
# set_property PACKAGE_PIN G7 [get_ports {vAuxN[5]}]
# set_property PACKAGE_PIN J6 [get_ports {vAuxP[6]}]
# set_property PACKAGE_PIN J5 [get_ports {vAuxN[6]}]
# set_property PACKAGE_PIN J4 [get_ports {vAuxP[7]}]
# set_property PACKAGE_PIN H4 [get_ports {vAuxN[7]}]
# set_property PACKAGE_PIN J14 [get_ports {vAuxP[8]}]
# set_property PACKAGE_PIN J15 [get_ports {vAuxN[8]}]
# set_property PACKAGE_PIN M15 [get_ports {vAuxP[9]}]
# set_property PACKAGE_PIN L15 [get_ports {vAuxN[9]}]
# set_property PACKAGE_PIN L17 [get_ports {vAuxP[10]}]
# set_property PACKAGE_PIN L18 [get_ports {vAuxN[10]}]
# set_property PACKAGE_PIN J18 [get_ports {vAuxP[11]}]
# set_property PACKAGE_PIN H18 [get_ports {vAuxN[11]}]
# set_property PACKAGE_PIN H8 [get_ports {vAuxP[12]}]
# set_property PACKAGE_PIN G8 [get_ports {vAuxN[12]}]
# set_property PACKAGE_PIN H6 [get_ports {vAuxP[13]}]
# set_property PACKAGE_PIN G6 [get_ports {vAuxN[13]}]
# set_property PACKAGE_PIN L8 [get_ports {vAuxP[14]}]
# set_property PACKAGE_PIN K8 [get_ports {vAuxN[14]}]
# set_property PACKAGE_PIN K7 [get_ports {vAuxP[15]}]
# set_property PACKAGE_PIN K6 [get_ports {vAuxN[15]}]


set_property PACKAGE_PIN  R14 [get_ports {flashDq[0]}] 
set_property PACKAGE_PIN  R15 [get_ports {flashDq[1]}] 
set_property PACKAGE_PIN  P14 [get_ports {flashDq[2]}] 
set_property PACKAGE_PIN  N14 [get_ports {flashDq[3]}] 
set_property PACKAGE_PIN  N16 [get_ports {flashDq[4]}] 
set_property PACKAGE_PIN  N17 [get_ports {flashDq[5]}] 
set_property PACKAGE_PIN  R16 [get_ports {flashDq[6]}] 
set_property PACKAGE_PIN  R17 [get_ports {flashDq[7]}] 
set_property PACKAGE_PIN  N18 [get_ports {flashDq[8]}] 
set_property PACKAGE_PIN  K25 [get_ports {flashDq[9]}] 
set_property PACKAGE_PIN  K26 [get_ports {flashDq[10]}] 
set_property PACKAGE_PIN  M20 [get_ports {flashDq[11]}] 
set_property PACKAGE_PIN  L20 [get_ports {flashDq[12]}] 
set_property PACKAGE_PIN  L25 [get_ports {flashDq[13]}] 
set_property PACKAGE_PIN  M24 [get_ports {flashDq[14]}] 
set_property PACKAGE_PIN  M25 [get_ports {flashDq[15]}] 

set_property PACKAGE_PIN  R23 [get_ports {flashAddr[0]}] 
set_property PACKAGE_PIN  T23 [get_ports {flashAddr[1]}] 
set_property PACKAGE_PIN  R22 [get_ports {flashAddr[2]}] 
set_property PACKAGE_PIN  T22 [get_ports {flashAddr[3]}] 
set_property PACKAGE_PIN  P26 [get_ports {flashAddr[4]}] 
set_property PACKAGE_PIN  R26 [get_ports {flashAddr[5]}] 
set_property PACKAGE_PIN  T25 [get_ports {flashAddr[6]}] 
set_property PACKAGE_PIN  M26 [get_ports {flashAddr[7]}] 
set_property PACKAGE_PIN  N26 [get_ports {flashAddr[8]}] 
set_property PACKAGE_PIN  P25 [get_ports {flashAddr[9]}] 
set_property PACKAGE_PIN  R25 [get_ports {flashAddr[10]}] 
set_property PACKAGE_PIN  R21 [get_ports {flashAddr[11]}] 
set_property PACKAGE_PIN  R20 [get_ports {flashAddr[12]}] 
set_property PACKAGE_PIN  P24 [get_ports {flashAddr[13]}] 
set_property PACKAGE_PIN  P23 [get_ports {flashAddr[14]}] 
set_property PACKAGE_PIN  N19 [get_ports {flashAddr[15]}] 
set_property PACKAGE_PIN  G26 [get_ports {flashAddr[16]}] 
set_property PACKAGE_PIN  H26 [get_ports {flashAddr[17]}] 
set_property PACKAGE_PIN  D26 [get_ports {flashAddr[18]}] 
set_property PACKAGE_PIN  D25 [get_ports {flashAddr[19]}] 
set_property PACKAGE_PIN  E25 [get_ports {flashAddr[20]}] 
set_property PACKAGE_PIN  F24 [get_ports {flashAddr[21]}] 
set_property PACKAGE_PIN  G24 [get_ports {flashAddr[22]}] 
set_property PACKAGE_PIN  K23 [get_ports {flashAddr[23]}] 
set_property PACKAGE_PIN  K22 [get_ports {flashAddr[24]}] 
set_property PACKAGE_PIN  E23 [get_ports {flashAddr[25]}] 
#set_property PACKAGE_PIN  F23 [get_ports {flashAddr[26]}] 

set_property PACKAGE_PIN  P18 [get_ports {flashCeL}] 
set_property PACKAGE_PIN  G25 [get_ports {flashOeL}] 
set_property PACKAGE_PIN  F25 [get_ports {flashWeL}]
set_property PACKAGE_PIN  F22 [get_ports {flashAdv}] 
set_property PACKAGE_PIN  G22 [get_ports {flashWait}]

set_property IOSTANDARD LVCMOS25 [get_ports flash*]
