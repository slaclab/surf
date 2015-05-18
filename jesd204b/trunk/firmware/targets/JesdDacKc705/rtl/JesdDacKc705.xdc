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

create_generated_clock -name axilClk -multiply_by 1 -source [get_ports pgpRefClkP] \
    [get_pins {ClockManager7_PGP/MmcmGen.U_Mmcm/CLKOUT0}]

create_generated_clock -name pgpClk  -multiply_by 10 -divide_by 8  -source [get_ports pgpRefClkP] \
    [get_pins {ClockManager7_PGP/MmcmGen.U_Mmcm/CLKOUT1}]

create_clock -period 2.7027 -name jesdRefClk [get_ports fpgaDevClkaP]

create_generated_clock -name jesdRefClkDiv2 -divide_by 2 -source [get_ports fpgaDevClkaP] \
    [get_pins {IBUFDS_GTE2_FPGADEVCLKA/ODIV2}]

create_generated_clock -name jesdClk -divide_by 1 -source [get_pins {IBUFDS_GTE2_FPGADEVCLKA/ODIV2}] \
    [get_pins {ClockManager7_JESD/MmcmGen.U_Mmcm/CLKOUT0}]

set_clock_groups -asynchronous \ 
    -group [get_clocks -include_generated_clocks pgpClk] \
    -group [get_clocks -include_generated_clocks axilClk] \
    -group [get_clocks -include_generated_clocks jesdRefClk]
    -group [get_clocks -include_generated_clocks jesdClk]

#Assure that sychronization registers are placed in the same slice with no logic between each sync stage
set_property ASYNC_REG TRUE [get_cells -hierarchical *crossDomainSyncReg_reg*]


# User clock output
set_property PACKAGE_PIN Y23 [get_ports gpioClk]
set_property IOSTANDARD LVCMOS25 [get_ports gpioClk]

set_property PACKAGE_PIN L25 [get_ports usrClk]
set_property IOSTANDARD LVCMOS25 [get_ports usrClk]

# PGP clock and GTX
set_property PACKAGE_PIN G8 [get_ports pgpRefClkP] 
set_property PACKAGE_PIN G7  [get_ports pgpRefClkN]

set_property PACKAGE_PIN G3 [get_ports pgpGtRxN]
set_property PACKAGE_PIN G4 [get_ports pgpGtRxP]
set_property PACKAGE_PIN H1 [get_ports pgpGtTxN]
set_property PACKAGE_PIN H2 [get_ports pgpGtTxP]

# JESD reference clock FPGA CLK1 (FMC-G6-P,G7-N) 
set_property IOSTANDARD LVDS_25 [get_ports fpgaDevClkaP]
set_property IOSTANDARD LVDS_25 [get_ports fpgaDevClkaN]
set_property PACKAGE_PIN C25 [get_ports fpgaDevClkaP] 
set_property PACKAGE_PIN C26 [get_ports fpgaDevClkaN]

# JESD reference clock FPGA CLK2 (FMC-J2-P,J3-N) - NC on KC705
# set_property IOSTANDARD LVDS_25 [get_ports fpgaDevClkbP]
# set_property IOSTANDARD LVDS_25 [get_ports fpgaDevClkbN]
# set_property PACKAGE_PIN C25 [get_ports fpgaDevClkbP]
# set_property PACKAGE_PIN B25 [get_ports fpgaDevClkbN]

# JESD SYSREF input (FMC-G9-P,G10-N) 
set_property IOSTANDARD LVDS_25 [get_ports fpgaSysRefP]
set_property IOSTANDARD LVDS_25 [get_ports fpgaSysRefN]
set_property PACKAGE_PIN H26 [get_ports fpgaSysRefP]
set_property PACKAGE_PIN H27 [get_ports fpgaSysRefN]

# JESD NSYNC input (FMC-F10-P, F11-N)
set_property IOSTANDARD LVDS_25 [get_ports syncbP]
set_property IOSTANDARD LVDS_25 [get_ports syncbN]
set_property PACKAGE_PIN E14 [get_ports {syncbP}]
set_property PACKAGE_PIN E15 [get_ports {syncbN}]

# Internally generated devClk and SYSREF (going from FPGA to DAC)
# FMC D8-P, D9-N
# set_property PACKAGE_PIN D26 [get_ports dacDevClkP]
# set_property PACKAGE_PIN C26 [get_ports dacDevClkN]
# FMC D11-P, D12-N
# set_property PACKAGE_PIN G29 [get_ports dacSysRefP]
# set_property PACKAGE_PIN F30 [get_ports dacSysRefN]

# GTX RX ports coming from ADC ( DAC has 8 lanes but only 4 anre connected on KC705 )
# Lane 0 - FMC A30-P, A31-N
set_property PACKAGE_PIN A4 [get_ports {adcGtTxP[0]}]
set_property PACKAGE_PIN A3 [get_ports {adcGtTxN[0]}]

# Lane 1 - FMC A26-P, A27-N
set_property PACKAGE_PIN B2 [get_ports {adcGtTxP[1]}]
set_property PACKAGE_PIN B1 [get_ports {adcGtTxN[1]}]

# Lane 2 - FMC A22-P, A23-N
set_property PACKAGE_PIN C4 [get_ports {adcGtTxP[2]}]
set_property PACKAGE_PIN C3 [get_ports {adcGtTxN[2]}]

# Lane 3 - FMC C2-P, C3-N
set_property PACKAGE_PIN D2 [get_ports {adcGtTxP[3]}]
set_property PACKAGE_PIN D1 [get_ports {adcGtTxN[3]}]

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
set_property PACKAGE_PIN AB8  [get_ports {leds[0]}]
set_property PACKAGE_PIN AA8  [get_ports {leds[1]}]
set_property PACKAGE_PIN AC9  [get_ports {leds[2]}]
set_property PACKAGE_PIN AB9  [get_ports {leds[3]}]
set_property PACKAGE_PIN AE26 [get_ports {leds[4]}]
set_property PACKAGE_PIN G19  [get_ports {leds[5]}]
set_property PACKAGE_PIN E18  [get_ports {leds[6]}]
set_property PACKAGE_PIN F16  [get_ports {leds[7]}]
set_property IOSTANDARD LVCMOS15 [get_ports leds[0]]
set_property IOSTANDARD LVCMOS15 [get_ports leds[2]]
set_property IOSTANDARD LVCMOS15 [get_ports leds[1]]
set_property IOSTANDARD LVCMOS15 [get_ports leds[3]]
set_property IOSTANDARD LVCMOS15 [get_ports leds[4]]
set_property IOSTANDARD LVCMOS15 [get_ports leds[5]]
set_property IOSTANDARD LVCMOS15 [get_ports leds[6]]
set_property IOSTANDARD LVCMOS15 [get_ports leds[7]]

#GPIO0 SYSREF output DEBUG
set_property PACKAGE_PIN AB25  [get_ports sysRef]
set_property IOSTANDARD LVCMOS15 [get_ports sysRef]




