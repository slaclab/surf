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

create_clock -period 5.405 -name jesdRefClk [get_ports fpgaDevClkaP]

create_generated_clock -name jesdClk -divide_by 1 -source [get_ports {fpgaDevClkaP}] \
    [get_pins {ClockManager7_JESD/MmcmGen.U_Mmcm/CLKOUT0}]

set_clock_groups -asynchronous\
 -group [get_clocks -include_generated_clocks pgpRefClk]\
 -group [get_clocks -include_generated_clocks jesdRefClk]\
 -group [get_clocks -include_generated_clocks sysClk125]

#Assure that sychronization registers are placed in the same slice with no logic between each sync stage
set_property ASYNC_REG true [get_cells -hierarchical *crossDomainSyncReg_reg*]


# System clock
set_property -dict {PACKAGE_PIN G10 IOSTANDARD LVDS} [get_ports sysClk125P]
set_property -dict {PACKAGE_PIN F10 IOSTANDARD LVDS} [get_ports sysClk125N]


# User GPIO clock output (jesdClk)
set_property IOSTANDARD LVCMOS18 [get_ports gpioClk]
set_property PACKAGE_PIN H27 [get_ports gpioClk]

#USER SMA clock(MGT loopback)
set_property PACKAGE_PIN D23 [get_ports userClkP]
set_property IOSTANDARD LVDS [get_ports userClkP]

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
set_property IOSTANDARD LVDS [get_ports fpgaDevClkaP]
set_property IOSTANDARD LVDS [get_ports fpgaDevClkaN]

# From (EXT)SMA
#set_property PACKAGE_PIN V6 [get_ports fpgaDevClkaP]
#set_property PACKAGE_PIN V5 [get_ports fpgaDevClkaN]
# From (ADC)FMC22
set_property PACKAGE_PIN K5 [get_ports fpgaDevClkaN]
set_property PACKAGE_PIN K6 [get_ports fpgaDevClkaP]

# JESD reference clock Devclk B
# set_property IOSTANDARD LVDS [get_ports fpgaDevClkbP]
# set_property IOSTANDARD LVDS [get_ports fpgaDevClkbN]
# set_property PACKAGE_PIN xx [get_ports fpgaDevClkbP]
# set_property PACKAGE_PIN xx [get_ports fpgaDevClkbN]

# JESD SYSREF input
########################################################
# From (ADC)FMC22 (FMC-G9-P,G10-N)
set_property IOSTANDARD LVDS [get_ports fpgaSysRefP]
set_property IOSTANDARD LVDS [get_ports fpgaSysRefN]
set_property PACKAGE_PIN A13 [get_ports fpgaSysRefP]
set_property PACKAGE_PIN A12 [get_ports fpgaSysRefN]

# From (ADC)FMC2
#set_property PACKAGE_PIN xx [get_ports fpgaSysRefP]
#set_property PACKAGE_PIN xx [get_ports fpgaSysRefN]

# JESD NSYNC output
########################################################

# To (ADC)FMC22 (G12-P G13-N)
set_property IOSTANDARD LVDS [get_ports syncbP]
set_property IOSTANDARD LVDS [get_ports syncbN]
set_property PACKAGE_PIN J8 [get_ports syncbP]
set_property PACKAGE_PIN H8 [get_ports syncbN]

# To (ADC)FMC2
#set_property PACKAGE_PIN xx [get_ports {syncbP}]
#set_property PACKAGE_PIN xx [get_ports {syncbN}]


# Internally generated devClk and SYSREF (going from FPGA to ADC)
# (D8-P D9-N)
set_property PACKAGE_PIN G9 [get_ports adcDevClkP]
set_property PACKAGE_PIN F9 [get_ports adcDevClkN]
# (D11-P D12-N)
set_property PACKAGE_PIN L13 [get_ports adcSysRefP]
set_property PACKAGE_PIN K13 [get_ports adcSysRefN]

set_property IOSTANDARD LVDS [get_ports adcDevClkP]
set_property IOSTANDARD LVDS [get_ports adcDevClkN]
set_property IOSTANDARD LVDS [get_ports adcSysRefP]
set_property IOSTANDARD LVDS [get_ports adcSysRefN]

# GTX RX ports coming from ADC ( [0:1]-Two channel 1 lanes, [2:3]-Two channel 2 lanes  )
########################################################

#set_property LOC GTHE3_CHANNEL_X0Y17 [get_cells {Jesd204bGthRxUltra_INST/GT_OPER_GEN.GthUltrascaleJesdCoregen_INST/inst/gen_gtwizard_gthe3_top.GthUltrascaleJesdCoregen_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_channel_container[4].gen_enabled_channel.gthe3_channel_wrapper_inst/channel_inst/gthe3_channel_gen.gen_gthe3_channel_inst[0].GTHE3_CHANNEL_PRIM_INST}]
#set_property LOC GTHE3_CHANNEL_X0Y19 [get_cells {Jesd204bGthRxUltra_INST/GT_OPER_GEN.GthUltrascaleJesdCoregen_INST/inst/gen_gtwizard_gthe3_top.GthUltrascaleJesdCoregen_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_channel_container[4].gen_enabled_channel.gthe3_channel_wrapper_inst/channel_inst/gthe3_channel_gen.gen_gthe3_channel_inst[1].GTHE3_CHANNEL_PRIM_INST}]

# SA0 - Channel A lane 0 (A2-P A3-N)
set_property PACKAGE_PIN D2 [get_ports {adcGtRxP[0]}]
set_property PACKAGE_PIN D1 [get_ports {adcGtRxN[0]}]

# SA1 - Channel A lane 1 (C6-P C7-N)
#set_property PACKAGE_PIN E4 [get_ports {adcGtRxP[1]}]
#set_property PACKAGE_PIN E3 [get_ports {adcGtRxN[1]}]

# SB0 - Channel B lane 0 (A10-P A11-N)
set_property PACKAGE_PIN A4 [get_ports {adcGtRxP[1]}]
set_property PACKAGE_PIN A3 [get_ports {adcGtRxN[1]}]

# SB1 - Channel B lane 1 (A6-P A7-N)
#set_property PACKAGE_PIN B2 [get_ports {adcGtRxP[3]}]
#set_property PACKAGE_PIN B1 [get_ports {adcGtRxN[3]}]

# Output leds DEBUG
set_property -dict {PACKAGE_PIN AP8 IOSTANDARD LVCMOS18} [get_ports {leds[0]}]
set_property -dict {PACKAGE_PIN H23 IOSTANDARD LVCMOS18} [get_ports {leds[1]}]
set_property -dict {PACKAGE_PIN P20 IOSTANDARD LVCMOS18} [get_ports {leds[2]}]
set_property -dict {PACKAGE_PIN P21 IOSTANDARD LVCMOS18} [get_ports {leds[3]}]
set_property -dict {PACKAGE_PIN N22 IOSTANDARD LVCMOS18} [get_ports {leds[4]}]
set_property -dict {PACKAGE_PIN M22 IOSTANDARD LVCMOS18} [get_ports {leds[5]}]
set_property -dict {PACKAGE_PIN R23 IOSTANDARD LVCMOS18} [get_ports {leds[6]}]
set_property -dict {PACKAGE_PIN P23 IOSTANDARD LVCMOS18} [get_ports {leds[7]}]

#SYSREF output DEBUG (J53-PIN1)
set_property PACKAGE_PIN AL14 [get_ports sysrefDbg]
set_property IOSTANDARD LVCMOS15 [get_ports sysrefDbg]

#Rising edge pulse output DEBUG (J53-PIN3)
set_property PACKAGE_PIN AM14 [get_ports rePulseDbg[0]]
set_property IOSTANDARD LVCMOS15 [get_ports rePulseDbg[0]]

#Rising edge pulse output DEBUG (J53-PIN4)
set_property PACKAGE_PIN AM15 [get_ports rePulseDbg[1]]
set_property IOSTANDARD LVCMOS15 [get_ports rePulseDbg[1]]

#SYNC output LED indicator on ADC-EVM (FMC H31)
set_property PACKAGE_PIN B21 [get_ports syncDbg]
set_property IOSTANDARD LVCMOS18 [get_ports syncDbg]


# Bitstream generation options
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_VOLTAGE 1.8 [current_design]
set_property CFGBVS GND [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR YES [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES [current_design]

