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
create_clock -period 8.000 -name pgpRefClk [get_ports pgpRefClkP]

create_generated_clock -name axilClk -source [get_ports pgpRefClkP] -multiply_by 1 [get_pins ClockManager7_PGP/MmcmGen.U_Mmcm/CLKOUT0]

create_generated_clock -name pgpClk -source [get_ports pgpRefClkP] -divide_by 8 -multiply_by 10 [get_pins ClockManager7_PGP/MmcmGen.U_Mmcm/CLKOUT1]

#create_clock -period 5.4254 -name jesdRefClk [get_ports fpgaDevClkaP]
create_clock -period 2.703 -name jesdRefClk [get_ports fpgaDevClkaP]

#create_generated_clock -name jesdRefClkDiv2 -divide_by 2 -source [get_ports fpgaDevClkaP] #   [get_pins {IBUFDS_GTE2_FPGADEVCLKA/ODIV2}]

create_generated_clock -name jesdClk -source [get_pins IBUFDS_GTE2_FPGADEVCLKA/ODIV2] -divide_by 1 [get_pins ClockManager7_JESD/MmcmGen.U_Mmcm/CLKOUT0]

#create_generated_clock -name jesdClk -divide_by 1 -source [get_pins {IBUFDS_GTE2_FPGADEVCLKA/O}] #    [get_pins {ClockManager7_JESD/MmcmGen.U_Mmcm/CLKOUT0}]

set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks pgpClk] -group [get_clocks -include_generated_clocks axilClk] -group [get_clocks -include_generated_clocks jesdRefClk]
#    -group [get_clocks -include_generated_clocks jesdClk]

#Assure that sychronization registers are placed in the same slice with no logic between each sync stage
set_property ASYNC_REG true [get_cells -hierarchical *crossDomainSyncReg_reg*]


# User GPIO clock output (MGT loopback)
set_property IOSTANDARD LVDS_25 [get_ports gpioClkN]
set_property PACKAGE_PIN Y23 [get_ports gpioClkP]
set_property IOSTANDARD LVDS_25 [get_ports gpioClkP]

# PGP clock and GTX
set_property PACKAGE_PIN G7 [get_ports pgpRefClkN]

set_property PACKAGE_PIN H2 [get_ports pgpGtTxP]

# JESD reference clock Devclk A
########################################################
set_property IOSTANDARD LVDS_25 [get_ports fpgaDevClkaP]
set_property IOSTANDARD LVDS_25 [get_ports fpgaDevClkaN]

# From (EXT)SMA
#set_property PACKAGE_PIN J8 [get_ports fpgaDevClkaP]
#set_property PACKAGE_PIN J7 [get_ports fpgaDevClkaN]
# From (ADC)FMC22
set_property PACKAGE_PIN C7 [get_ports fpgaDevClkaN]
# From (ADC)FMC2
#set_property PACKAGE_PIN N8 [get_ports fpgaDevClkaP]
#set_property PACKAGE_PIN N7 [get_ports fpgaDevClkaN]

# JESD reference clock Devclk B
# set_property IOSTANDARD LVDS_25 [get_ports fpgaDevClkbP]
# set_property IOSTANDARD LVDS_25 [get_ports fpgaDevClkbN]
# set_property PACKAGE_PIN C25 [get_ports fpgaDevClkbP]
# set_property PACKAGE_PIN B25 [get_ports fpgaDevClkbN]

# JESD SYSREF input
########################################################
# From (ADC)FMC22
set_property IOSTANDARD LVDS_25 [get_ports fpgaSysRefP]
set_property IOSTANDARD LVDS_25 [get_ports fpgaSysRefN]
set_property PACKAGE_PIN H27 [get_ports fpgaSysRefN]

# From (ADC)FMC2
#set_property PACKAGE_PIN AG20 [get_ports fpgaSysRefP]
#set_property PACKAGE_PIN AH20 [get_ports fpgaSysRefN]

# JESD NSYNC output
########################################################

# To (ADC)FMC22
set_property IOSTANDARD LVDS_25 [get_ports syncbP]
set_property IOSTANDARD LVDS_25 [get_ports syncbN]
set_property PACKAGE_PIN E30 [get_ports syncbN]

# To (ADC)FMC2
#set_property PACKAGE_PIN AJ22 [get_ports {syncbP}]
#set_property PACKAGE_PIN AJ23 [get_ports {syncbN}]


# Internally generated devClk and SYSREF (going from FPGA to ADC)
set_property PACKAGE_PIN C26 [get_ports adcDevClkN]
set_property PACKAGE_PIN F30 [get_ports adcSysRefN]

set_property IOSTANDARD LVDS_25 [get_ports adcDevClkP]
set_property IOSTANDARD LVDS_25 [get_ports adcDevClkN]
set_property IOSTANDARD LVDS_25 [get_ports adcSysRefP]
set_property IOSTANDARD LVDS_25 [get_ports adcSysRefN]

# GTX RX ports coming from ADC ( [0:1]-Two channel 1 lanes, [2:3]-Two channel 2 lanes  )
########################################################

# SA0 - Channel A lane 0

# From (ADC)FMC22
set_property PACKAGE_PIN D5 [get_ports {adcGtRxN[0]}]

# From (ADC)FMC2
#set_property PACKAGE_PIN F5 [get_ports {adcGtRxN[0]}]
#set_property PACKAGE_PIN F6 [get_ports {adcGtRxP[0]}]

# SA1 - Channel A lane 1
set_property PACKAGE_PIN E4 [get_ports {adcGtRxP[1]}]
set_property PACKAGE_PIN E3 [get_ports {adcGtRxN[1]}]

# SB0 - Channel B lane 0
set_property PACKAGE_PIN A7 [get_ports {adcGtRxN[2]}]

# SB1 - Channel B lane 1
set_property PACKAGE_PIN B6 [get_ports {adcGtRxP[3]}]
set_property PACKAGE_PIN B5 [get_ports {adcGtRxN[3]}]

# Output leds DEBUG
set_property PACKAGE_PIN AB8 [get_ports {leds[0]}]
set_property PACKAGE_PIN AA8 [get_ports {leds[1]}]
set_property PACKAGE_PIN AC9 [get_ports {leds[2]}]
set_property PACKAGE_PIN AB9 [get_ports {leds[3]}]
set_property PACKAGE_PIN AE26 [get_ports {leds[4]}]
set_property PACKAGE_PIN G19 [get_ports {leds[5]}]
set_property PACKAGE_PIN E18 [get_ports {leds[6]}]
set_property PACKAGE_PIN F16 [get_ports {leds[7]}]
set_property IOSTANDARD LVCMOS15 [get_ports {leds[0]}]
set_property IOSTANDARD LVCMOS15 [get_ports {leds[1]}]
set_property IOSTANDARD LVCMOS15 [get_ports {leds[2]}]
set_property IOSTANDARD LVCMOS15 [get_ports {leds[3]}]
set_property IOSTANDARD LVCMOS15 [get_ports {leds[4]}]
set_property IOSTANDARD LVCMOS15 [get_ports {leds[5]}]
set_property IOSTANDARD LVCMOS15 [get_ports {leds[6]}]
set_property IOSTANDARD LVCMOS15 [get_ports {leds[7]}]

#SYSREF output DEBUG (XADC_GPIO_0 J46-PIN18)
set_property PACKAGE_PIN AB25 [get_ports sysrefDbg]
set_property IOSTANDARD LVCMOS15 [get_ports sysrefDbg]

#USER SMA clock (jesdClk) DEBUG
set_property PACKAGE_PIN L25 [get_ports usrClk]
set_property IOSTANDARD LVCMOS25 [get_ports usrClk]



set_property MARK_DEBUG true [get_nets {Jesd204bGtx7_INST/Jesd204b_INST/generateAxiStreamLanes[0].AxiStreamLaneTx_INST/s_sampleDataArr[0]_2[16]}]
set_property MARK_DEBUG true [get_nets {Jesd204bGtx7_INST/Jesd204b_INST/generateAxiStreamLanes[0].AxiStreamLaneTx_INST/s_sampleDataArr[0]_2[17]}]
set_property MARK_DEBUG true [get_nets {Jesd204bGtx7_INST/Jesd204b_INST/generateAxiStreamLanes[0].AxiStreamLaneTx_INST/s_sampleDataArr[0]_2[20]}]
set_property MARK_DEBUG true [get_nets {Jesd204bGtx7_INST/Jesd204b_INST/generateAxiStreamLanes[0].AxiStreamLaneTx_INST/s_sampleDataArr[0]_2[15]}]
set_property MARK_DEBUG true [get_nets {Jesd204bGtx7_INST/Jesd204b_INST/generateAxiStreamLanes[0].AxiStreamLaneTx_INST/s_sampleDataArr[0]_2[4]}]
set_property MARK_DEBUG true [get_nets {Jesd204bGtx7_INST/Jesd204b_INST/generateAxiStreamLanes[0].AxiStreamLaneTx_INST/s_sampleDataArr[0]_2[31]}]
set_property MARK_DEBUG true [get_nets {Jesd204bGtx7_INST/Jesd204b_INST/generateAxiStreamLanes[0].AxiStreamLaneTx_INST/s_sampleDataArr[0]_2[30]}]
set_property MARK_DEBUG true [get_nets {Jesd204bGtx7_INST/Jesd204b_INST/generateAxiStreamLanes[0].AxiStreamLaneTx_INST/s_sampleDataArr[0]_2[29]}]
set_property MARK_DEBUG true [get_nets {Jesd204bGtx7_INST/Jesd204b_INST/generateAxiStreamLanes[0].AxiStreamLaneTx_INST/s_sampleDataArr[0]_2[26]}]
set_property MARK_DEBUG true [get_nets {Jesd204bGtx7_INST/Jesd204b_INST/generateAxiStreamLanes[0].AxiStreamLaneTx_INST/s_sampleDataArr[0]_2[28]}]
set_property MARK_DEBUG true [get_nets {Jesd204bGtx7_INST/Jesd204b_INST/generateAxiStreamLanes[0].AxiStreamLaneTx_INST/s_sampleDataArr[0]_2[25]}]
set_property MARK_DEBUG true [get_nets {Jesd204bGtx7_INST/Jesd204b_INST/generateAxiStreamLanes[0].AxiStreamLaneTx_INST/s_sampleDataArr[0]_2[23]}]
set_property MARK_DEBUG true [get_nets {Jesd204bGtx7_INST/Jesd204b_INST/generateAxiStreamLanes[0].AxiStreamLaneTx_INST/s_sampleDataArr[0]_2[22]}]
set_property MARK_DEBUG true [get_nets {Jesd204bGtx7_INST/Jesd204b_INST/generateAxiStreamLanes[0].AxiStreamLaneTx_INST/s_sampleDataArr[0]_2[3]}]
set_property MARK_DEBUG true [get_nets {Jesd204bGtx7_INST/Jesd204b_INST/generateAxiStreamLanes[0].AxiStreamLaneTx_INST/s_sampleDataArr[0]_2[24]}]
set_property MARK_DEBUG true [get_nets {Jesd204bGtx7_INST/Jesd204b_INST/generateAxiStreamLanes[0].AxiStreamLaneTx_INST/s_sampleDataArr[0]_2[27]}]
set_property MARK_DEBUG true [get_nets {Jesd204bGtx7_INST/Jesd204b_INST/generateAxiStreamLanes[0].AxiStreamLaneTx_INST/s_sampleDataArr[0]_2[1]}]
set_property MARK_DEBUG true [get_nets {Jesd204bGtx7_INST/Jesd204b_INST/generateAxiStreamLanes[0].AxiStreamLaneTx_INST/s_sampleDataArr[0]_2[0]}]
set_property MARK_DEBUG true [get_nets {Jesd204bGtx7_INST/Jesd204b_INST/generateAxiStreamLanes[0].AxiStreamLaneTx_INST/s_sampleDataArr[0]_2[2]}]
set_property MARK_DEBUG true [get_nets {Jesd204bGtx7_INST/Jesd204b_INST/generateAxiStreamLanes[0].AxiStreamLaneTx_INST/s_sampleDataArr[0]_2[14]}]
set_property MARK_DEBUG true [get_nets {Jesd204bGtx7_INST/Jesd204b_INST/generateAxiStreamLanes[0].AxiStreamLaneTx_INST/s_sampleDataArr[0]_2[6]}]
set_property MARK_DEBUG true [get_nets {Jesd204bGtx7_INST/Jesd204b_INST/generateAxiStreamLanes[0].AxiStreamLaneTx_INST/s_sampleDataArr[0]_2[11]}]
set_property MARK_DEBUG true [get_nets {Jesd204bGtx7_INST/Jesd204b_INST/generateAxiStreamLanes[0].AxiStreamLaneTx_INST/s_sampleDataArr[0]_2[13]}]
set_property MARK_DEBUG true [get_nets {Jesd204bGtx7_INST/Jesd204b_INST/generateAxiStreamLanes[0].AxiStreamLaneTx_INST/s_sampleDataArr[0]_2[18]}]
set_property MARK_DEBUG true [get_nets {Jesd204bGtx7_INST/Jesd204b_INST/generateAxiStreamLanes[0].AxiStreamLaneTx_INST/s_sampleDataArr[0]_2[7]}]
set_property MARK_DEBUG true [get_nets {Jesd204bGtx7_INST/Jesd204b_INST/generateAxiStreamLanes[0].AxiStreamLaneTx_INST/s_sampleDataArr[0]_2[5]}]
set_property MARK_DEBUG true [get_nets {Jesd204bGtx7_INST/Jesd204b_INST/generateAxiStreamLanes[0].AxiStreamLaneTx_INST/s_sampleDataArr[0]_2[19]}]
set_property MARK_DEBUG true [get_nets {Jesd204bGtx7_INST/Jesd204b_INST/generateAxiStreamLanes[0].AxiStreamLaneTx_INST/s_sampleDataArr[0]_2[12]}]
set_property MARK_DEBUG true [get_nets {Jesd204bGtx7_INST/Jesd204b_INST/generateAxiStreamLanes[0].AxiStreamLaneTx_INST/s_sampleDataArr[0]_2[10]}]
set_property MARK_DEBUG true [get_nets {Jesd204bGtx7_INST/Jesd204b_INST/generateAxiStreamLanes[0].AxiStreamLaneTx_INST/s_sampleDataArr[0]_2[9]}]
set_property MARK_DEBUG true [get_nets {Jesd204bGtx7_INST/Jesd204b_INST/generateAxiStreamLanes[0].AxiStreamLaneTx_INST/s_sampleDataArr[0]_2[8]}]
set_property MARK_DEBUG true [get_nets {Jesd204bGtx7_INST/Jesd204b_INST/generateAxiStreamLanes[0].AxiStreamLaneTx_INST/s_sampleDataArr[0]_2[21]}]
