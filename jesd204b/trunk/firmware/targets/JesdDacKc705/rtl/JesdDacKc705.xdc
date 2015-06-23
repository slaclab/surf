#-------------------------------------------------------------------------------
#-- Title         : JESD DacKc705 Board Constraints
#-- File          : JesdDacKc705.xdc
#-- Author        : Uros Legat <ulegat@slac.stanford.edu>
#-- Created       : 06/04/2015
#-------------------------------------------------------------------------------
#-- Description:
#-- Constrains for the Kc705 JESD DAC TI DAC38J82EVM
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

create_clock -period 5.405 -name jesdRefClk [get_ports fpgaDevClkaP]

create_generated_clock -name jesdClk -divide_by 1 -source [get_ports {fpgaDevClkaP}] \
    [get_pins {ClockManager7_JESD/MmcmGen.U_Mmcm/CLKOUT0}]

set_clock_groups -asynchronous \ 
    -group [get_clocks -include_generated_clocks pgpClk] \
    -group [get_clocks -include_generated_clocks axilClk] \
    -group [get_clocks -include_generated_clocks jesdRefClk]

#Assure that sychronization registers are placed in the same slice with no logic between each sync stage
set_property ASYNC_REG TRUE [get_cells -hierarchical *crossDomainSyncReg_reg*]

# User clock outputs
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
set_property PACKAGE_PIN C8 [get_ports fpgaDevClkaP]
set_property PACKAGE_PIN C7 [get_ports fpgaDevClkaN]

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

# GTX RX ports coming from DAC ( DAC has 8 lanes but only 4 are connected on KC705 2 are used)
# Lane 0 - FMC A30-P, A31-N
set_property PACKAGE_PIN A4 [get_ports {adcGtTxP[0]}]
set_property PACKAGE_PIN A3 [get_ports {adcGtTxN[0]}]

# Lane 1 - FMC A26-P, A27-N
set_property PACKAGE_PIN B2 [get_ports {adcGtTxP[1]}]
set_property PACKAGE_PIN B1 [get_ports {adcGtTxN[1]}]

# Lane 2 - FMC A22-P, A23-N
#set_property PACKAGE_PIN C4 [get_ports {adcGtTxP[2]}]
#set_property PACKAGE_PIN C3 [get_ports {adcGtTxN[2]}]

# Lane 3 - FMC C2-P, C3-N
#set_property PACKAGE_PIN D2 [get_ports {adcGtTxP[3]}]
#set_property PACKAGE_PIN D1 [get_ports {adcGtTxN[3]}]

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

#Rising edge pulse output DEBUG (J46-PIN20)
set_property PACKAGE_PIN AB28 [get_ports rePulseDbg[0]]
set_property IOSTANDARD LVCMOS15 [get_ports rePulseDbg[0]]

#Rising edge pulse output DEBUG (J46-PIN19)
set_property PACKAGE_PIN AA27 [get_ports rePulseDbg[1]]
set_property IOSTANDARD LVCMOS15 [get_ports rePulseDbg[1]]