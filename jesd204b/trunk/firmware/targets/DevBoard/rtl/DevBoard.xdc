#-------------------------------------------------------------------------------
#-- Title         : JESD AdcKcu105 Board Constraints
#-- File          : JesdAdcKcu105.xdc
#-- Author        : Uros Legat <ulegat@slac.stanford.edu>
#-- Created       : 06/04/2015
#-------------------------------------------------------------------------------
#-- Description:
#-- Constrains for the Kcu105 JESD DAC TI ADC16DX370EVM
#-------------------------------------------------------------------------------
#-- Copyright (c) 2015 SLAC National Accelerator Laboratory
#-------------------------------------------------------------------------------
#-- Modification history:
#-- 06/04/2015: created.
#-------------------------------------------------------------------------------

#Clocks
create_clock -period 8.000 -name sysClk125 [get_ports sysClk125P]

create_clock -period 6.400 -name pgpRefClk [get_ports pgpRefClkP]

create_generated_clock -name pgpClk -source [get_ports pgpRefClkP] -multiply_by 1 [get_pins ClockManager7_PGP/MmcmGen.U_Mmcm/CLKOUT0]

set_clock_groups -asynchronous\
 -group [get_clocks -include_generated_clocks pgpRefClk]\
 -group [get_clocks -include_generated_clocks sysClk125]
 
#Assure that sychronization registers are placed in the same slice with no logic between each sync stage
set_property ASYNC_REG true [get_cells -hierarchical *crossDomainSyncReg_reg*]


# System clock
set_property -dict {PACKAGE_PIN G10 IOSTANDARD LVDS} [get_ports sysClk125P]
set_property -dict {PACKAGE_PIN F10 IOSTANDARD LVDS} [get_ports sysClk125N]


# PGP REF Clk IO
set_property -dict {PACKAGE_PIN F12 IOSTANDARD LVCMOS18} [get_ports pgpRefClkSel]
set_property PACKAGE_PIN P5 [get_ports pgpRefClkN]
set_property PACKAGE_PIN P6 [get_ports pgpRefClkP]

# PGP GT ports (SFP0)
set_property PACKAGE_PIN T2 [get_ports pgpGtRxP]
set_property PACKAGE_PIN T1 [get_ports pgpGtRxN]
set_property PACKAGE_PIN U4 [get_ports pgpGtTxP]
set_property PACKAGE_PIN U3 [get_ports pgpGtTxN]


# JESD reference clock Devclk A (FMC-D5-P,D4-N)
########################################################
#set_property IOSTANDARD LVDS [get_ports fpgaDevClkaP]
#set_property IOSTANDARD LVDS [get_ports fpgaDevClkaN]
#set_property PACKAGE_PIN K5 [get_ports fpgaDevClkaN]
#set_property PACKAGE_PIN K6 [get_ports fpgaDevClkaP]


# JESD SYSREF input
########################################################
# From (ADC)FMC22 (FMC-G9-P,G10-N)
set_property IOSTANDARD LVDS [get_ports fpgaSysRefP]
set_property IOSTANDARD LVDS [get_ports fpgaSysRefN]
set_property PACKAGE_PIN A13 [get_ports fpgaSysRefP]
set_property PACKAGE_PIN A12 [get_ports fpgaSysRefN]

# JESD NSYNC output
########################################################

# To (ADC)FMC22 (G12-P G13-N)
set_property IOSTANDARD LVDS [get_ports syncbP]
set_property IOSTANDARD LVDS [get_ports syncbN]
set_property PACKAGE_PIN J8 [get_ports syncbP]
set_property PACKAGE_PIN H8 [get_ports syncbN]

# SPI ports
set_property -dict {PACKAGE_PIN AJ8  IOSTANDARD LVCMOS18 PULLUP true}  [get_ports {spiCsL_o[0]}]
set_property -dict {PACKAGE_PIN AJ23 IOSTANDARD LVCMOS18 PULLUP true}  [get_ports {spiCsL_o[1]}]
set_property -dict {PACKAGE_PIN AJ24 IOSTANDARD LVCMOS18 PULLUP true}  [get_ports {spiCsL_o[2]}]
set_property -dict {PACKAGE_PIN AH22 IOSTANDARD LVCMOS18 PULLUP true}  [get_ports {spiCsL_o[3]}]

set_property -dict {PACKAGE_PIN AL8 IOSTANDARD LVCMOS18 PULLUP true}  [get_ports spiSclk_o]
set_property -dict {PACKAGE_PIN AM9 IOSTANDARD LVCMOS18 PULLUP true}  [get_ports spiSdi_o]
set_property -dict {PACKAGE_PIN AJ9 IOSTANDARD LVCMOS18 PULLUP true}  [get_ports spiSdo_i]
set_property -dict {PACKAGE_PIN AK8 IOSTANDARD LVCMOS18 PULLUP true}  [get_ports spiSdio_io]

set_property -dict {PACKAGE_PIN AK22 IOSTANDARD LVCMOS18 PULLUP true}  [get_ports spiSclkDac_o]
set_property -dict {PACKAGE_PIN AJ21 IOSTANDARD LVCMOS18 PULLUP true}  [get_ports spiSdioDac_io]
set_property -dict {PACKAGE_PIN AK23 IOSTANDARD LVCMOS18 PULLUP true}  [get_ports spiCsLDac_o]

# Leds
set_property -dict {PACKAGE_PIN AP8 IOSTANDARD LVCMOS18} [get_ports {leds[0]}]
set_property -dict {PACKAGE_PIN H23 IOSTANDARD LVCMOS18} [get_ports {leds[1]}]
set_property -dict {PACKAGE_PIN P20 IOSTANDARD LVCMOS18} [get_ports {leds[2]}]
set_property -dict {PACKAGE_PIN P21 IOSTANDARD LVCMOS18} [get_ports {leds[3]}]
set_property -dict {PACKAGE_PIN N22 IOSTANDARD LVCMOS18} [get_ports {leds[4]}]


# Bitstream generation options
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_VOLTAGE 1.8 [current_design]
set_property CFGBVS GND [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR YES [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES [current_design]


