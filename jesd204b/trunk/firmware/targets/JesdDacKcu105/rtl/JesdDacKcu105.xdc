#-------------------------------------------------------------------------------
#-- Title         : HPS Front End Board Constraints
#-- File          : JesdDacKcu105.xdc
#-- Author        : Uros Legat <ulegat@slac.stanford.edu>
#-- Created       : 06/04/2015
#-------------------------------------------------------------------------------
#-- Description:
#-- Constrains for the Kcu105 JESD DAC 
#-------------------------------------------------------------------------------
#-- Copyright (c) 2015 SLAC National Accelerator Laboratory
#-------------------------------------------------------------------------------
#-- Modification history:
#-- 06/04/2015: created.
#-------------------------------------------------------------------------------

#Clocks
create_clock -period 8.000 -name pgpRefClk [get_ports pgpRefClkP]

create_generated_clock -name axilClk -multiply_by 1 -source [get_ports pgpRefClkP] \
    [get_pins {ClockManager7_PGP/MmcmGen.U_Mmcm/CLKOUT0}]

create_generated_clock -name pgpClk  -multiply_by 10 -divide_by 8  -source [get_ports pgpRefClkP] \
    [get_pins {ClockManager7_PGP/MmcmGen.U_Mmcm/CLKOUT1}]

create_clock -period 2.703 -name jesdRefClk [get_ports fpgaDevClkaP]

#create_generated_clock -name jesdRefClkDiv2 -divide_by 2 -source [get_ports fpgaDevClkaP] \
#    [get_pins {IBUFDS_GTE2_FPGADEVCLKA/ODIV2}]

create_generated_clock -name jesdClk -divide_by 2 -source [get_pins {JESDREFCLK_BUFG_GT/O}] \
    [get_pins {ClockManager7_JESD/MmcmGen.U_Mmcm/CLKOUT0}]

set_clock_groups -asynchronous \ 
    -group [get_clocks -include_generated_clocks pgpClk] \
    -group [get_clocks -include_generated_clocks axilClk] \
    -group [get_clocks -include_generated_clocks jesdRefClk] \
    -group [get_clocks -include_generated_clocks jesdClk]

#Assure that sychronization registers are placed in the same slice with no logic between each sync stage
set_property ASYNC_REG TRUE [get_cells -hierarchical *crossDomainSyncReg_reg*]

# User clock outputs
set_property PACKAGE_PIN H27 [get_ports gpioClk]
set_property IOSTANDARD LVCMOS18 [get_ports gpioClk]

set_property PACKAGE_PIN D23 [get_ports usrClk]
set_property IOSTANDARD LVCMOS18 [get_ports usrClk]

# PGP clock and GTX
set_property IOSTANDARD LVDS [get_ports pgpRefClkP]
set_property IOSTANDARD LVDS [get_ports pgpRefClkN]
set_property PACKAGE_PIN G10 [get_ports pgpRefClkP] 
set_property PACKAGE_PIN F10 [get_ports pgpRefClkN]

#set_property PACKAGE_PIN G3 [get_ports pgpGtRxN]
#set_property PACKAGE_PIN G4 [get_ports pgpGtRxP]
#set_property PACKAGE_PIN H1 [get_ports pgpGtTxN]
#set_property PACKAGE_PIN H2 [get_ports pgpGtTxP]

# JESD reference clock FPGA CLK1 (FMC-D5-P,D4-N) 
set_property IOSTANDARD LVDS [get_ports fpgaDevClkaP]
set_property IOSTANDARD LVDS [get_ports fpgaDevClkaN]
set_property PACKAGE_PIN K6 [get_ports fpgaDevClkaP]
set_property PACKAGE_PIN K5 [get_ports fpgaDevClkaN]

# JESD reference clock FPGA CLK2 (FMC-J2-P,J3-N) - NC on KC705
# set_property IOSTANDARD LVDS [get_ports fpgaDevClkbP]
# set_property IOSTANDARD LVDS [get_ports fpgaDevClkbN]
# set_property PACKAGE_PIN C25 [get_ports fpgaDevClkbP]
# set_property PACKAGE_PIN B25 [get_ports fpgaDevClkbN]

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
#set_property LOC GTHE3_CHANNEL_X0Y19 [get_cells {}]
#set_property LOC GTHE3_CHANNEL_X0Y18 [get_cells {}]


# GTX RX ports coming from DAC ( DAC has 8 lanes but only 4 are connected on KC705 )
# Lane 0 - FMC A30-P, A31-N
set_property PACKAGE_PIN B6 [get_ports {adcGtTxP[1]}]
set_property PACKAGE_PIN B5 [get_ports {adcGtTxN[1]}]

# Lane 1 - FMC A26-P, A27-N
set_property PACKAGE_PIN C4 [get_ports {adcGtTxP[0]}]
set_property PACKAGE_PIN C3 [get_ports {adcGtTxN[0]}]

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

#GPIO0 SYSREF output DEBUG
set_property PACKAGE_PIN AL14  [get_ports sysRef]
set_property IOSTANDARD LVCMOS18 [get_ports sysRef]