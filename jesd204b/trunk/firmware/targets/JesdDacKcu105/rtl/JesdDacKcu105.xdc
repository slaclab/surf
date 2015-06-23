#-------------------------------------------------------------------------------
#-- Title         : JESD DacKcu105 Board Constraints
#-- File          : JesdDacKcu105.xdc
#-- Author        : Uros Legat <ulegat@slac.stanford.edu>
#-- Created       : 06/04/2015
#-------------------------------------------------------------------------------
#-- Description:
#-- Constrains for the Kcu105 JESD DAC TI DAC38J82EVM
#-------------------------------------------------------------------------------
#-- Copyright (c) 2015 SLAC National Accelerator Laboratory
#-------------------------------------------------------------------------------
#-- Modification history:
#-- 06/04/2015: created.
#-------------------------------------------------------------------------------

#Clocks
create_clock -period 8.000 -name sysClk125 [get_ports sysClk125P]

create_clock -period 6.400 -name pgpRefClk [get_ports pgpRefClkP]

create_generated_clock -name pgpClk  -multiply_by 1  -source [get_ports pgpRefClkP] \
    [get_pins {ClockManager7_PGP/MmcmGen.U_Mmcm/CLKOUT0}]

create_clock -period 5.405 -name jesdRefClk [get_ports fpgaDevClkaP]

create_generated_clock -name jesdClk -divide_by 1 -source [get_ports {fpgaDevClkaP}] \
    [get_pins {ClockManager7_JESD/MmcmGen.U_Mmcm/CLKOUT0}]

set_clock_groups -asynchronous \ 
    -group [get_clocks -include_generated_clocks pgpRefClk] \
    -group [get_clocks -include_generated_clocks jesdRefClk] \
    -group [get_clocks -include_generated_clocks sysClk125]

#Assure that sychronization registers are placed in the same slice with no logic between each sync stage
set_property ASYNC_REG TRUE [get_cells -hierarchical *crossDomainSyncReg_reg*]


# System clock
set_property -dict { PACKAGE_PIN G10 IOSTANDARD LVDS} [get_ports sysClk125P]
set_property -dict { PACKAGE_PIN F10 IOSTANDARD LVDS} [get_ports sysClk125N]

# User clock outputs
set_property -dict { PACKAGE_PIN H27 IOSTANDARD LVCMOS18} [get_ports gpioClk]
set_property -dict { PACKAGE_PIN D23 IOSTANDARD LVCMOS18} [get_ports usrClk]

# PGP REF Clk IO
set_property -dict { PACKAGE_PIN F12 IOSTANDARD LVCMOS18 } [get_ports pgpRefClkSel]
set_property PACKAGE_PIN P6   [get_ports pgpRefClkP]
set_property PACKAGE_PIN P5   [get_ports pgpRefClkN]

# PGP GT ports (SFP0)
set_property PACKAGE_PIN T1 [get_ports pgpGtRxN]
set_property PACKAGE_PIN T2 [get_ports pgpGtRxP]
set_property PACKAGE_PIN U3 [get_ports pgpGtTxN]
set_property PACKAGE_PIN U4 [get_ports pgpGtTxP]

# JESD reference clock FPGA CLK1 (FMC-D5-P,D4-N) 
set_property PACKAGE_PIN K6  [get_ports fpgaDevClkaP]
set_property PACKAGE_PIN K5  [get_ports fpgaDevClkaN]

# JESD SYSREF input (FMC-G9-P,G10-N) 
set_property IOSTANDARD LVDS [get_ports fpgaSysRefP]
set_property IOSTANDARD LVDS [get_ports fpgaSysRefN]
set_property PACKAGE_PIN A13 [get_ports fpgaSysRefP]
set_property PACKAGE_PIN A12 [get_ports fpgaSysRefN]

# JESD NSYNC input (FMC-F10-P, F11-N)
set_property IOSTANDARD LVDS [get_ports syncbP]
set_property IOSTANDARD LVDS [get_ports syncbN]
set_property PACKAGE_PIN K18 [get_ports {syncbP}]
set_property PACKAGE_PIN K17 [get_ports {syncbN}]

# Internally generated devClk and SYSREF (going from FPGA to DAC)
# FMC D8-P, D9-N
# set_property PACKAGE_PIN D26 [get_ports dacDevClkP]
# set_property PACKAGE_PIN C26 [get_ports dacDevClkN]
# FMC D11-P, D12-N
# set_property PACKAGE_PIN G29 [get_ports dacSysRefP]
# set_property PACKAGE_PIN F30 [get_ports dacSysRefN]

# GTX RX ports coming from DAC ( DAC has 8 lanes but only 4 are connected on KC705 )
set_property LOC GTHE3_CHANNEL_X0Y19 [get_cells {Jesd204bTxGthUltra_INST/GthUltrascaleJesdCoregen_INST/inst/gen_gtwizard_gthe3_top.GthUltrascaleJesdCoregen_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_channel_container[4].gen_enabled_channel.gthe3_channel_wrapper_inst/channel_inst/gthe3_channel_gen.gen_gthe3_channel_inst[0].GTHE3_CHANNEL_PRIM_INST}]
set_property LOC GTHE3_CHANNEL_X0Y18 [get_cells {Jesd204bTxGthUltra_INST/GthUltrascaleJesdCoregen_INST/inst/gen_gtwizard_gthe3_top.GthUltrascaleJesdCoregen_gtwizard_gthe3_inst/gen_gtwizard_gthe3.gen_channel_container[4].gen_enabled_channel.gthe3_channel_wrapper_inst/channel_inst/gthe3_channel_gen.gen_gthe3_channel_inst[1].GTHE3_CHANNEL_PRIM_INST}]

# GTX RX ports coming from DAC ( DAC has 8 lanes but only 4 are connected on KC705 )
# Lane 0 - FMC A30-P, A31-N
#set_property PACKAGE_PIN B6 [get_ports {adcGtTxP[1]}]
#set_property PACKAGE_PIN B5 [get_ports {adcGtTxN[1]}]

# Lane 1 - FMC A26-P, A27-N
#set_property PACKAGE_PIN C4 [get_ports {adcGtTxP[0]}]
#set_property PACKAGE_PIN C3 [get_ports {adcGtTxN[0]}]

# Lane 2 - FMC A22-P, A23-N
#set_property PACKAGE_PIN D6 [get_ports {adcGtTxP[2]}]
#set_property PACKAGE_PIN D5 [get_ports {adcGtTxN[2]}]

# Lane 3 - FMC C2-P, C3-N
#set_property PACKAGE_PIN F6 [get_ports {adcGtTxP[3]}]
#set_property PACKAGE_PIN F5 [get_ports {adcGtTxN[3]}]

# Lane 4 - FMC B32-P, B33-N
#set_property PACKAGE_PIN xx [get_ports {adcGtTxP[4]}]
#set_property PACKAGE_PIN xx [get_ports {adcGtTxN[4]}]

# Lane 5 - FMC B36-P, B37-N
#set_property PACKAGE_PIN xx [get_ports {adcGtTxP[5]}]
#set_property PACKAGE_PIN xx [get_ports {adcGtTxN[5]}]

# Lane 6 - FMC A38-P, A39-N
#set_property PACKAGE_PIN xx [get_ports {adcGtTxP[6]}]
#set_property PACKAGE_PIN xx[get_ports {adcGtTxN[6]}]

# Lane 7 - FMC A34-P, A35-N
#set_property PACKAGE_PIN xx [get_ports {adcGtTxP[7]}]
#set_property PACKAGE_PIN xx [get_ports {adcGtTxN[7]}]

# Output leds
set_property -dict { PACKAGE_PIN AP8 IOSTANDARD LVCMOS18 } [get_ports { leds[0] }]
set_property -dict { PACKAGE_PIN H23 IOSTANDARD LVCMOS18 } [get_ports { leds[1] }]
set_property -dict { PACKAGE_PIN P20 IOSTANDARD LVCMOS18 } [get_ports { leds[2] }]
set_property -dict { PACKAGE_PIN P21 IOSTANDARD LVCMOS18 } [get_ports { leds[3] }]
set_property -dict { PACKAGE_PIN N22 IOSTANDARD LVCMOS18 } [get_ports { leds[4] }]
set_property -dict { PACKAGE_PIN M22 IOSTANDARD LVCMOS18 } [get_ports { leds[5] }]
set_property -dict { PACKAGE_PIN R23 IOSTANDARD LVCMOS18 } [get_ports { leds[6] }]
set_property -dict { PACKAGE_PIN P23 IOSTANDARD LVCMOS18 } [get_ports { leds[7] }]

#Rising edge pulse output DEBUG (J53-PIN3)
set_property PACKAGE_PIN AM14 [get_ports rePulseDbg[0]]
set_property IOSTANDARD LVCMOS18 [get_ports rePulseDbg[0]]

#Rising edge pulse output DEBUG (J53-PIN4)
set_property PACKAGE_PIN AM15 [get_ports rePulseDbg[1]]
set_property IOSTANDARD LVCMOS18 [get_ports rePulseDbg[1]]

#GPIO0 SYSREF output DEBUG
set_property PACKAGE_PIN AL14  [get_ports sysRef]
set_property IOSTANDARD LVCMOS18 [get_ports sysRef]

# Bitstream generation options
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]
set_property CONFIG_VOLTAGE 1.8 [current_design]
set_property CFGBVS GND [current_design]
set_property BITSTREAM.CONFIG.SPI_32BIT_ADDR YES [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.SPI_FALL_EDGE YES [current_design]
