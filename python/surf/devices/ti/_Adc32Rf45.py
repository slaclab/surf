#-----------------------------------------------------------------------------
# Description:
# PyRogue Adc32Rf45 Module
#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https:#confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr
import time
import surf.devices.ti

class Adc32Rf45(pr.Device):
    def __init__( self, verify=True, **kwargs):
        super().__init__(**kwargs)

        ################
        # Base addresses
        ################
        generalAddr     = (0x0 << 14) # 0000000
        masterPage      = (0x7 << 14) # 0x1C000
        analogPage      = (0x8 << 14) # 0x20000
        chA             = (0x0 << 14) # 0x00000
        chB             = (0x8 << 14) # 0x20000
        rawInterface    = (0x1 << 18) # 0x40000

        #####################
        # Add Device Channels
        #####################
        self.add(surf.devices.ti.Adc32Rf45Channel(name='CH[0]',description='Channel A',offset=chA,expand=False,verify=verify))
        self.add(surf.devices.ti.Adc32Rf45Channel(name='CH[1]',description='Channel B',offset=chB,expand=False,verify=verify))

        ##################
        # General Register
        ##################
        self.add(pr.RemoteVariable(name='GeneralAddr',
                                   offset       = generalAddr + (4*0x0000),  # 0x00000 - 0x00FFF, 4096 Bytes
                                   base         = pr.UInt,
                                   bitOffset    = 0,
                                   numValues    = 0x400, # 0x400 * 4 = 4096 Bytes
                                   valueBits    = 32,
                                   valueStride  = 32,
                                   updateNotify = False,
                                   bulkOpEn     = True, # bulkOpEn=True required when overlap with YAML loaded registers
                                   hidden       = True,
                                   overlapEn    = True,
                                   verify       = False))

        self.add(pr.RemoteCommand(
            name         = "RESET",
            description  = "Send 0x81 value to reset the device",
            offset       =  (generalAddr + (4*0x000)),  # 0x00000000
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            # mode         = "WO",
            hidden       =  True,
            function     = pr.BaseCommand.createTouch(0x81),
            overlapEn    =  True,
        ))

        self.add(pr.RemoteVariable(
            name         = "HW_RST",
            description  = "Hardware Reset",
            offset       =  (0xF << 14),  # 0x0003C000
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            hidden       =  True,
            overlapEn    =  True,
        ))

        ##################
        # Raw Interface
        ##################
        self.add(pr.RemoteVariable(name='RawInterface0',
                                   offset       = rawInterface + (4*0x0000), # 0x40000 - 0x401FF, 512 Bytes
                                   base         = pr.UInt,
                                   bitOffset    = 0,
                                   numValues    = 0x80,
                                   valueBits    = 32,
                                   valueStride  = 32,
                                   updateNotify = False,
                                   bulkOpEn     = True, # bulkOpEn=True required when overlap with YAML loaded registers
                                   hidden       = True,
                                   verify       = False))

        self.add(pr.RemoteVariable(name='RawInterface4',
                                   offset       = rawInterface + (4*0x4000), # 0x50000 - 0x5003F, 64 Bytes
                                   base         = pr.UInt,
                                   bitOffset    = 0,
                                   numValues    = 0x10,
                                   valueBits    = 32,
                                   valueStride  = 32,
                                   updateNotify = False,
                                   bulkOpEn     = True, # bulkOpEn=True required when overlap with YAML loaded registers
                                   hidden       = True,
                                   verify       = False))

        self.add(pr.RemoteVariable(name='RawInterface6',
                                   offset       = rawInterface + (4*0x6000), # 0x58000 - 0x583FF, 1024 Bytes
                                   base         = pr.UInt,
                                   bitOffset    = 0,
                                   numValues    = 0x100,
                                   valueBits    = 32,
                                   valueStride  = 32,
                                   updateNotify = False,
                                   bulkOpEn     = True, # bulkOpEn=True required when overlap with YAML loaded registers
                                   hidden       = True,
                                   verify       = False))

        #############
        # Master Page
        #############
        self.add(pr.RemoteVariable(
            name         = "PDN_SYSREF",
            description  = "0 = Normal operation, 1 = SYSREF input capture buffer is powered down and further SYSREF input pulses are ignored",
            offset       =  (masterPage + (4*0x020)),
            bitSize      =  1,
            bitOffset    =  4,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(
            name         = "PDN_CHB",
            description  = "0 = Normal operation, 1 = Channel B is powered down",
            offset       =  (masterPage + (4*0x020)),
            bitSize      =  1,
            bitOffset    =  1,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(
            name         = "GLOBAL_PDN",
            description  = "0 = Normal operation, 1 = Global power-down enabled",
            offset       =  (masterPage + (4*0x020)),
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(
            name         = "INCR_CM_IMPEDANCE",
            description  = "0 = VCM buffer directly drives the common point of biasing resistors, 1 = VCM buffer drives the common point of biasing resistors with > 5 kOhm",
            offset       =  (masterPage + (4*0x032)),
            bitSize      =  1,
            bitOffset    =  5,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(
            name         = "AlwaysWrite0x1_A",
            description  = "Always set this bit to 1",
            offset       =  (masterPage + (4*0x039)),
            bitSize      =  1,
            bitOffset    =  6,
            base         = pr.UInt,
            mode         = "WO",
            value        = 0x1,
            hidden       = True,
            verify       = False,
        ))

        self.add(pr.RemoteVariable(
            name         = "AlwaysWrite0x1_B",
            description  = "Always set this bit to 1",
            offset       =  (masterPage + (4*0x039)),
            bitSize      =  1,
            bitOffset    =  4,
            base         = pr.UInt,
            mode         = "WO",
            value        = 0x1,
            hidden       = True,
            verify       = False,
        ))

        self.add(pr.RemoteVariable(
            name         = "PDN_CHB_EN",
            description  = "This bit enables the power-down control of channel B through the SPI in register 20h: 0 = PDN control disabled, 1 = PDN control enabled",
            offset       =  (masterPage + (4*0x039)),
            bitSize      =  1,
            bitOffset    =  1,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(
            name         = "SYNC_TERM_DIS",
            description  = "0 = On-chip, 100-Ohm termination enabled, 1 = On-chip, 100-Ohm termination disabled",
            offset       =  (masterPage + (4*0x039)),
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(
            name         = "SYSREF_DEL_EN",
            description  = "0 = SYSREF delay disabled, 1 = SYSREF delay enabled through register settings [3Ch (bits 1-0), 5Ah (bits 7-5)]",
            offset       =  (masterPage + (4*0x03C)),
            bitSize      =  1,
            bitOffset    =  6,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(
            name         = "SYSREF_DEL_HI",
            description  = "When the SYSREF delay feature is enabled (3Ch, bit 6) the delay can be adjusted in 25-ps steps; the first step is 175 ps. The PVT variation of each 25-ps step is +/-10 ps. The 175-ps step is +/-50 ps",
            offset       =  (masterPage + (4*0x03C)),
            bitSize      =  2,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(
            name         = "JESD_OUTPUT_SWING",
            description  = "These bits select the output amplitude (VOD) of the JESD transmitter for all lanes.",
            offset       =  (masterPage + (4*0x3D)),
            bitSize      =  3,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(
            name         = "SYSREF_DEL_LO",
            description  = "When the SYSREF delay feature is enabled (3Ch, bit 6) the delay can be adjusted in 25-ps steps; the first step is 175 ps. The PVT variation of each 25-ps step is +/-10 ps. The 175-ps step is +/-50 ps",
            offset       =  (masterPage + (4*0x05A)),
            bitSize      =  3,
            bitOffset    =  5,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(
            name         = "SEL_SYSREF_REG",
            description  = "0 = SYSREF is logic low, 1 = SYSREF is logic high",
            offset       =  (masterPage + (4*0x057)),
            bitSize      =  1,
            bitOffset    =  4,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(
            name         = "ASSERT_SYSREF_REG",
            description  = "0 = SYSREF is asserted by device pins, 1 = SYSREF can be asserted by the ASSERT SYSREF REG register bit",
            offset       =  (masterPage + (4*0x057)),
            bitSize      =  1,
            bitOffset    =  3,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(
            name         = "SYNCB_POL",
            description  = "0 = Polarity is not inverted, 1 = Polarity is inverted",
            offset       =  (masterPage + (4*0x058)),
            bitSize      =  1,
            bitOffset    =  5,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        # ##########
        # # ADC PAGE
        # ##########
        self.add(pr.RemoteVariable(
            name         = "SLOW_SP_EN1",
            description  = "0 = ADC sampling rates are faster than 2.5 GSPS, 1 = ADC sampling rates are slower than 2.5 GSPS",
            offset       =  (analogPage + (4*0x03F)),
            bitSize      =  1,
            bitOffset    =  2,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))

        self.add(pr.RemoteVariable(
            name         = "SLOW_SP_EN2",
            description  = "0 = ADC sampling rates are faster than 2.5 GSPS, 1 = ADC sampling rates are slower than 2.5 GSPS",
            offset       =  (analogPage + (4*0x042)),
            bitSize      =  1,
            bitOffset    =  4,
            base         = pr.UInt,
            mode         = "RW",
            verify       = verify,
        ))


        ##############################
        # Commands
        ##############################
        @self.command(description  = "Device Initiation")
        def Init():
            self.GeneralAddr.set(value=0x04,index=0x012) # write 4 to address 12 page select
            self.GeneralAddr.set(value=0x00,index=0x056) # sysref dis - check this was written earlier
            self.GeneralAddr.set(value=0x00,index=0x057) # sysref dis - whether it has to be zero
            self.GeneralAddr.set(value=0x00,index=0x020)
            self.CH[0].JesdDigital.set(value=0x00,index=0x03E)
            self.CH[1].JesdDigital.set(value=0x00,index=0x03E)

            self.IL_Config_Nyq1_ChA()
            self.IL_Config_Nyq1_ChB()

            time.sleep(0.250)

            self.SetNLTrim()

            time.sleep(0.250)

            self.JESD_DDC_config()

            time.sleep(0.250)

            self.CH[0].OffsetCorrector.set(value=0xA2,index=0x068) #... freeze offset estimation
            self.CH[1].OffsetCorrector.set(value=0xA2,index=0x068) #... freeze offset estimation

            self.GeneralAddr.set(value=0x04,index=0x012) # write 4 to address 12 page select
            self.GeneralAddr.set(value=0x00,index=0x056) # sysref dis - check this was written earlier
            self.GeneralAddr.set(value=0x00,index=0x057) # sysref dis - whether it has to be zero
            self.GeneralAddr.set(value=0x00,index=0x020)

            self.GeneralAddr.set(value=0x04,index=0x012) # write 4 to address 12 page select
            self.CH[0].JesdDigital.set(value=0x40,index=0x03E) #... MASK CLKDIV SYSREF
            self.CH[1].JesdDigital.set(value=0x40,index=0x03E) #... MASK CLKDIV SYSREF

            self.CH[0].JesdDigital.set(value=0x60,index=0x03E) #... MASK CLKDIV SYSREF + MASK NCO SYSREF
            self.CH[1].JesdDigital.set(value=0x60,index=0x03E) #... MASK CLKDIV SYSREF + MASK NCO SYSREF

            self.GeneralAddr.set(value=0x10,index=0x020) # PDN_SYSREF = 0x1

        @self.command()
        def Powerup_AnalogConfig():
            self.GeneralAddr.set(value=0x81,index=0x000) # Global software reset. Remember the sequence of programming the config files is Powerup_Analog_Config-->IL_Config_Nyqx_chA-->IL_Config_Nyqx_chB-->NL_Config_Nyqx_chA-->NL_Config_Nyqx_chB-->JESD_Config
            self.GeneralAddr.set(value=0xFF,index=0x011) # Select ADC page.
            self.GeneralAddr.set(value=0xC0,index=0x022) # Analog trims start here.
            self.GeneralAddr.set(value=0x80,index=0x032) # ...
            self.GeneralAddr.set(value=0x08,index=0x033) # ...
            self.GeneralAddr.set(value=0x03,index=0x042) # ...
            self.GeneralAddr.set(value=0x03,index=0x043) # ...
            self.GeneralAddr.set(value=0x58,index=0x045) # ...
            self.GeneralAddr.set(value=0xC4,index=0x046) # ...
            self.GeneralAddr.set(value=0x01,index=0x047) # ...
            self.GeneralAddr.set(value=0x01,index=0x053) # ...
            self.GeneralAddr.set(value=0x08,index=0x054) # ...
            self.GeneralAddr.set(value=0x05,index=0x064) # ...
            self.GeneralAddr.set(value=0x84,index=0x072) # ...
            self.GeneralAddr.set(value=0x80,index=0x08C) # ...
            self.GeneralAddr.set(value=0x80,index=0x097) # ...
            self.GeneralAddr.set(value=0x38,index=0x0F0) # ...
            self.GeneralAddr.set(value=0xBF,index=0x0F1) # Analog trims ended here.
            self.GeneralAddr.set(value=0x00,index=0x011) # Disable ADC Page
            self.GeneralAddr.set(value=0x04,index=0x012) # Select Master Page
            self.GeneralAddr.set(value=0x01,index=0x025) # Global Analog Trims start here.
            self.GeneralAddr.set(value=0x40,index=0x026) #...
            self.GeneralAddr.set(value=0x80,index=0x027) #...
            self.GeneralAddr.set(value=0x40,index=0x029) #...
            self.GeneralAddr.set(value=0x80,index=0x02A) #...
            self.GeneralAddr.set(value=0x40,index=0x02C) #...
            self.GeneralAddr.set(value=0x80,index=0x02D) #...
            self.GeneralAddr.set(value=0x40,index=0x02F) #...
            self.GeneralAddr.set(value=0x01,index=0x034) #...
            self.GeneralAddr.set(value=0x01,index=0x03F) #...
            self.GeneralAddr.set(value=0x50,index=0x039) #...
            self.GeneralAddr.set(value=0x28,index=0x03B) #...
            self.GeneralAddr.set(value=0x80,index=0x040) #...
            self.GeneralAddr.set(value=0x40,index=0x042) #...
            self.GeneralAddr.set(value=0x80,index=0x043) #...
            self.GeneralAddr.set(value=0x40,index=0x045) #...
            self.GeneralAddr.set(value=0x80,index=0x046) #...
            self.GeneralAddr.set(value=0x40,index=0x048) #...
            self.GeneralAddr.set(value=0x80,index=0x049) #...
            self.GeneralAddr.set(value=0x40,index=0x04B) #...
            self.GeneralAddr.set(value=0x60,index=0x053) #...
            self.GeneralAddr.set(value=0x02,index=0x059) #...
            self.GeneralAddr.set(value=0x08,index=0x05B) #...
            self.GeneralAddr.set(value=0x07,index=0x05C) #...
            self.GeneralAddr.set(value=0x10,index=0x057) # Register control for SYSREF --these lines are added in revision SBAA226C.
            self.GeneralAddr.set(value=0x18,index=0x057) # Pulse SYSREF, pull high --these lines are added in revision SBAA226C.
            self.GeneralAddr.set(value=0x10,index=0x057) # Pulse SYSREF, pull back low --these lines are added in revision SBAA226C.
            self.GeneralAddr.set(value=0x18,index=0x057) # Pulse SYSREF, pull high --these lines are added in revision SBAA226C.
            self.GeneralAddr.set(value=0x10,index=0x057) # Pulse SYSREF, pull back low --these lines are added in revision SBAA226C.
            self.GeneralAddr.set(value=0x00,index=0x057) # Give SYSREF control back to device pin --these lines are added in revision SBAA226C.
            self.GeneralAddr.set(value=0x00,index=0x056) # sysref dis - check this was written earlier
            self.GeneralAddr.set(value=0x00,index=0x020) # Pdn sysref = 0
            self.GeneralAddr.set(value=0x00,index=0x012) # Master page disabled
            self.GeneralAddr.set(value=0xFF,index=0x011) # Select ADC Page
            self.GeneralAddr.set(value=0x07,index=0x083) # Additioanal Analog trims
            self.GeneralAddr.set(value=0x00,index=0x05C) #...
            self.GeneralAddr.set(value=0x01,index=0x05C) #...
            self.GeneralAddr.set(value=0x00,index=0x011) #Disable ADC Page. Power up Analog writes end here. Program appropriate -->IL_Config_Nyqx_chA-->IL_Config_Nyqx_chB-->NL_Config_Nyqx_chA-->NL_Config_Nyqx_chB-->JESD_Config

            self.RawInterface4.set(value=0x00,index=0x001) #DC corrector Bandwidth settings
            self.RawInterface4.set(value=0x00,index=0x002) #...
            self.RawInterface4.set(value=0x00,index=0x003) #...
            self.RawInterface4.set(value=0x61,index=0x004)  #...
            self.RawInterface6.set(value=0x22,index=0x068)  #...
            self.RawInterface4.set(value=0x01,index=0x003)  #...
            self.RawInterface6.set(value=0x22,index=0x068)  #...

        @self.command(description = "Set IL ChA")
        def IL_Config_Nyq1_ChA():
            self.CH[0].MainDigital.set(value=0x01,index=0x044) # Program global settings for Interleaving Corrector
            self.CH[0].MainDigital.set(value=0x04,index=0x068) #
            self.CH[0].MainDigital.set(value=0xC0,index=0x0FF) #...
            self.CH[0].MainDigital.set(value=0x08,index=0x0A2) # Progam nyquist zone 1 for chA, nyquist zone = 1 : 0x08, nyquist zone = 2 : 0x09, nyquist zone = 3 : 0x0A
            self.CH[0].MainDigital.set(value=0x03,index=0x0A9) #...
            self.CH[0].MainDigital.set(value=0x77,index=0x0AB) #...
            self.CH[0].MainDigital.set(value=0x01,index=0x0AC) #...
            self.CH[0].MainDigital.set(value=0x77,index=0x0AD) #...
            self.CH[0].MainDigital.set(value=0x01,index=0x0AE) #...
            self.CH[0].MainDigital.set(value=0x0F,index=0x096) #...
            self.CH[0].MainDigital.set(value=0x26,index=0x097) #...
            self.CH[0].MainDigital.set(value=0x0C,index=0x08F) #...
            self.CH[0].MainDigital.set(value=0x08,index=0x08C) #...
            self.CH[0].MainDigital.set(value=0x0F,index=0x080) #...
            self.CH[0].MainDigital.set(value=0xCB,index=0x081) #...
            self.CH[0].MainDigital.set(value=0x03,index=0x07D) #...
            self.CH[0].MainDigital.set(value=0x75,index=0x056) #...
            self.CH[0].MainDigital.set(value=0x75,index=0x057) #...
            self.CH[0].MainDigital.set(value=0x00,index=0x053) #...
            self.CH[0].MainDigital.set(value=0x03,index=0x04B) #...
            self.CH[0].MainDigital.set(value=0x80,index=0x049) #...
            self.CH[0].MainDigital.set(value=0x26,index=0x043) #...
            self.CH[0].MainDigital.set(value=0x01,index=0x05E) #...
            self.CH[0].MainDigital.set(value=0x38,index=0x042) #...
            self.CH[0].MainDigital.set(value=0x04,index=0x05A) #...
            self.CH[0].MainDigital.set(value=0x20,index=0x071) #...
            self.CH[0].MainDigital.set(value=0x00,index=0x062) #...
            self.CH[0].MainDigital.set(value=0x00,index=0x098) #...
            self.CH[0].MainDigital.set(value=0x08,index=0x099) #...
            self.CH[0].MainDigital.set(value=0x08,index=0x09C) #...
            self.CH[0].MainDigital.set(value=0x20,index=0x09D) #...
            self.CH[0].MainDigital.set(value=0x03,index=0x0BE) #...
            self.CH[0].MainDigital.set(value=0x00,index=0x069) #...
            self.CH[0].MainDigital.set(value=0x10,index=0x045) #...
            self.CH[0].MainDigital.set(value=0x64,index=0x08D) #...
            self.CH[0].MainDigital.set(value=0x20,index=0x08B) #...
            self.CH[0].MainDigital.set(value=0x00,index=0x000) # Dig Core reset
            self.CH[0].MainDigital.set(value=0x01,index=0x000) #...
            self.CH[0].MainDigital.set(value=0x00,index=0x000) #...

        @self.command()
        def IL_Config_Nyq1_ChB():
            self.CH[1].MainDigital.set(value=0x80,index=0x049) # Special setting for chB
            self.CH[1].MainDigital.set(value=0x20,index=0x042) # Special setting for chB
            self.CH[1].MainDigital.set(value=0x08,index=0x0A2) # Progam nyquist zone 1 for chB, nyquist zone = 1 : 0x08, nyquist zone = 2 : 0x09, nyquist zone = 3 : 0x0A
            self.CH[1].MainDigital.set(value=0x00,index=0x003) # Main digital page selected for chA
            self.CH[1].MainDigital.set(value=0x00,index=0x000) #...
            self.CH[1].MainDigital.set(value=0x01,index=0x000) #...
            self.CH[1].MainDigital.set(value=0x00,index=0x000) #...

        @self.command(description  = "Set nonlinear trims")
        def SetNLTrim():
            # Nonlinearity trims
            self.RawInterface4.set(value=0x00,index=0x003) #chA Non Linearity Trims for Nyq1. Remember the sequence of programming the config files is Powerup_Analog_Config-->IL_Config_Nyqx_chA-->IL_Config_Nyqx_chB-->NL_Config_Nyqx_chA-->NL_Config_Nyqx_chB-->JESD_Config
            self.RawInterface4.set(value=0x20,index=0x004) #...
            self.RawInterface4.set(value=0xF8,index=0x002) #...
            self.RawInterface6.set(value=0xF5,index=0x03C) #...
            self.RawInterface6.set(value=0x01,index=0x03D) #...
            self.RawInterface6.set(value=0xF0,index=0x03E) #...
            self.RawInterface6.set(value=0x0C,index=0x03F) #...
            self.RawInterface6.set(value=0x0A,index=0x040) #...
            self.RawInterface6.set(value=0xFE,index=0x041) #...
            self.RawInterface6.set(value=0xF5,index=0x053) #...
            self.RawInterface6.set(value=0x01,index=0x054) #...
            self.RawInterface6.set(value=0xEE,index=0x055) #...
            self.RawInterface6.set(value=0x0E,index=0x056) #...
            self.RawInterface6.set(value=0x0B,index=0x057) #...
            self.RawInterface6.set(value=0xFE,index=0x058) #...
            self.RawInterface6.set(value=0xF4,index=0x06A) #...
            self.RawInterface6.set(value=0x01,index=0x06B) #...
            self.RawInterface6.set(value=0xF0,index=0x06C) #...
            self.RawInterface6.set(value=0x0B,index=0x06D) #...
            self.RawInterface6.set(value=0x09,index=0x06E) #...
            self.RawInterface6.set(value=0xFE,index=0x06F) #...
            self.RawInterface6.set(value=0xF5,index=0x081) #...
            self.RawInterface6.set(value=0x01,index=0x082) #...
            self.RawInterface6.set(value=0xEE,index=0x083) #...
            self.RawInterface6.set(value=0x0D,index=0x084) #...
            self.RawInterface6.set(value=0x0A,index=0x085) #...
            self.RawInterface6.set(value=0xFE,index=0x086) #...
            self.RawInterface6.set(value=0xFD,index=0x098) #...
            self.RawInterface6.set(value=0x00,index=0x099) #...
            self.RawInterface6.set(value=0x00,index=0x09A) #...
            self.RawInterface6.set(value=0x00,index=0x09B) #...
            self.RawInterface6.set(value=0x00,index=0x09C) #...
            self.RawInterface6.set(value=0x00,index=0x09D) #...
            self.RawInterface6.set(value=0xFF,index=0x0AF) #...
            self.RawInterface6.set(value=0x00,index=0x0B0) #...
            self.RawInterface6.set(value=0x01,index=0x0B1) #...
            self.RawInterface6.set(value=0xFF,index=0x0B2) #...
            self.RawInterface6.set(value=0xFF,index=0x0B3) #...
            self.RawInterface6.set(value=0x00,index=0x0B4) #...
            self.RawInterface6.set(value=0xFE,index=0x0C6) #...
            self.RawInterface6.set(value=0x00,index=0x0C7) #...
            self.RawInterface6.set(value=0x00,index=0x0C8) #...
            self.RawInterface6.set(value=0x02,index=0x0C9) #...
            self.RawInterface6.set(value=0x00,index=0x0CA) #...
            self.RawInterface6.set(value=0x00,index=0x0CB) #...
            self.RawInterface6.set(value=0xFF,index=0x0DD) #...
            self.RawInterface6.set(value=0x00,index=0x0DE) #...
            self.RawInterface6.set(value=0x02,index=0x0DF) #...
            self.RawInterface6.set(value=0x00,index=0x0E0) #...
            self.RawInterface6.set(value=0xFE,index=0x0E1) #...
            self.RawInterface6.set(value=0x00,index=0x0E2) #...
            self.RawInterface6.set(value=0x00,index=0x0F4) #...
            self.RawInterface6.set(value=0x00,index=0x0F5) #...
            self.RawInterface6.set(value=0x01,index=0x0FB) #...
            self.RawInterface6.set(value=0x01,index=0x0FC) #...
            self.RawInterface4.set(value=0x00,index=0x003) #chB Non Linearity Trims for Nyq1. Remember the sequence of programming the config files is Powerup_Analog_Config-->IL_Config_Nyqx_chA-->IL_Config_Nyqx_chB-->NL_Config_Nyqx_chA-->NL_Config_Nyqx_chB-->JESD_Config
            self.RawInterface4.set(value=0x20,index=0x004) #...
            self.RawInterface4.set(value=0xF9,index=0x002) #...
            self.RawInterface6.set(value=0xF4,index=0x074) #...
            self.RawInterface6.set(value=0x01,index=0x075) #...
            self.RawInterface6.set(value=0xEF,index=0x076) #...
            self.RawInterface6.set(value=0x0C,index=0x077) #...
            self.RawInterface6.set(value=0x0A,index=0x078) #...
            self.RawInterface6.set(value=0xFE,index=0x079) #...
            self.RawInterface6.set(value=0xF4,index=0x08B) #...
            self.RawInterface6.set(value=0x01,index=0x08C) #...
            self.RawInterface6.set(value=0xEE,index=0x08D) #...
            self.RawInterface6.set(value=0x0D,index=0x08E) #...
            self.RawInterface6.set(value=0x0A,index=0x08F) #...
            self.RawInterface6.set(value=0xFE,index=0x090) #...
            self.RawInterface6.set(value=0xF4,index=0x0A2) #...
            self.RawInterface6.set(value=0x01,index=0x0A3) #...
            self.RawInterface6.set(value=0xEF,index=0x0A4) #...
            self.RawInterface6.set(value=0x0C,index=0x0A5) #...
            self.RawInterface6.set(value=0x0A,index=0x0A6) #...
            self.RawInterface6.set(value=0xFE,index=0x0A7) #...
            self.RawInterface6.set(value=0xF4,index=0x0B9) #...
            self.RawInterface6.set(value=0x01,index=0x0BA) #...
            self.RawInterface6.set(value=0xEF,index=0x0BB) #...
            self.RawInterface6.set(value=0x0D,index=0x0BC) #...
            self.RawInterface6.set(value=0x0A,index=0x0BD) #...
            self.RawInterface6.set(value=0xFE,index=0x0BE) #...
            self.RawInterface6.set(value=0xFF,index=0x0D0) #...
            self.RawInterface6.set(value=0x00,index=0x0D1) #...
            self.RawInterface6.set(value=0xFF,index=0x0D2) #...
            self.RawInterface6.set(value=0x01,index=0x0D3) #...
            self.RawInterface6.set(value=0x00,index=0x0D4) #...
            self.RawInterface6.set(value=0x00,index=0x0D5) #...
            self.RawInterface6.set(value=0xFF,index=0x0E7) #...
            self.RawInterface6.set(value=0x00,index=0x0E8) #...
            self.RawInterface6.set(value=0x01,index=0x0E9) #...
            self.RawInterface6.set(value=0x00,index=0x0EA) #...
            self.RawInterface6.set(value=0x00,index=0x0EB) #...
            self.RawInterface6.set(value=0x00,index=0x0EC) #...
            self.RawInterface6.set(value=0xFE,index=0x0FE) #...
            self.RawInterface6.set(value=0x00,index=0x0FF) #...
            self.RawInterface4.set(value=0xFA,index=0x002) #...
            self.RawInterface6.set(value=0xFF,index=0x000) #...
            self.RawInterface6.set(value=0x02,index=0x001) #...
            self.RawInterface6.set(value=0x01,index=0x002) #...
            self.RawInterface6.set(value=0x00,index=0x003) #...
            self.RawInterface6.set(value=0xFF,index=0x015) #...
            self.RawInterface6.set(value=0x00,index=0x016) #...
            self.RawInterface6.set(value=0x01,index=0x017) #...
            self.RawInterface6.set(value=0x00,index=0x018) #...
            self.RawInterface6.set(value=0xFF,index=0x019) #...
            self.RawInterface6.set(value=0x00,index=0x01A) #...
            self.RawInterface6.set(value=0x00,index=0x02C) #...
            self.RawInterface6.set(value=0x00,index=0x02D) #...
            self.RawInterface6.set(value=0x01,index=0x033) #...
            self.RawInterface6.set(value=0x01,index=0x034) #...
            self.RawInterface4.set(value=0x00,index=0x002) #...
            self.RawInterface4.set(value=0x00,index=0x003) #...
            self.RawInterface4.set(value=0x68,index=0x004) #...
            self.RawInterface6.set(value=0x00,index=0x068) #...
            self.RawInterface0.set(value=0x00,index=0x011) #...
            self.RawInterface0.set(value=0x04,index=0x012) #...
            self.RawInterface0.set(value=0x87,index=0x05c) #...
            self.RawInterface0.set(value=0x00,index=0x012) #...

        @self.command()
        def JESD_DDC_config():
            # JESD DIGITAL PAGE
            channels = self.find(typ=surf.devices.ti.Adc32Rf45Channel)
            for channel in channels:
                channel.SCRAMBLE_EN.set(0x1, write=True)
                channel.node('12BIT_MODE').set(0x0, write=True)       # need to use node to find variables with leading #
                channel.SYNC_REG_EN.set(0x0, write=True)
                channel.SYNC_REG.set(0x0, write=True)
                channel.RAMP_12BIT.set(0x0, write=True)
                channel.JESD_MODE0.set(0x0, write=True)
                channel.JESD_MODE1.set(0x0, write=True)
                channel.JESD_MODE2.set(0x1, write=True)
                channel.LMFC_MASK_RESET.set(0x0, write=True)
                channel.LINK_LAY_RPAT.set(0x0, write=True)
                channel.LINK_LAYER_TESTMODE.set(0x0, write=True)
                channel.node('40X_MODE').set(0x7, write=True)          # need to use node to find variables with leading 3
                channel.PLL_MODE.set(0x2, write=True)
                channel.SEL_EMP_LANE0.set(0x03, write=True)
                channel.SEL_EMP_LANE1.set(0x3F, write=True)  # unused lane
                channel.SEL_EMP_LANE2.set(0x03, write=True)
                channel.SEL_EMP_LANE3.set(0x3F, write=True)  # unused lane
                channel.TX_LINK_DIS.set(0x0, write=True)
                channel.FRAME_ALIGN.set(0x1, write=True)
                channel.LANE_ALIGN.set(0x1, write=True)
                channel.TESTMODE_EN.set(0x0, write=True)
                channel.CTRL_K.set(0x1, write=True)
                channel.FRAMES_PER_MULTIFRAME.set(0x1F, write=True)

                # Decimation filter page
                channel.DDC_EN.set(0x1,write=True)
                channel.DECIM_FACTOR.set(0x0,write=True)
                channel.DUAL_BAND_EN.set(0x0,write=True)
                channel.REAL_OUT_EN.set(0x0,write=True)
                # Write the value that has been loaded via yaml,
                # or write the default value defined in _AdcRf45Channel.py
                channel.DDC0_NCO1_LSB.write()
                channel.DDC0_NCO1_MSB.write()
                channel.DDC0_NCO2_LSB.write()
                channel.DDC0_NCO2_MSB.write()
                channel.DDC0_NCO3_LSB.write()
                channel.DDC0_NCO3_MSB.write()
                channel.NCO_SEL_PIN.set(0x00,write=True)
                channel.NCO_SEL.set(0x00,write=True)
                channel.LMFC_RESET_MODE.set(0x00,write=True)
                channel.DDC0_6DB_GAIN.set(0x01,write=True)
                channel.DDC1_6DB_GAIN.set(0x01,write=True)
                channel.DDC_DET_LAT.set(0x05,write=True)
                channel.WBF_6DB_GAIN.set(0x01,write=True)
                channel.CUSTOM_PATTERN1_LSB.set(0x00,write=True)
                channel.CUSTOM_PATTERN1_MSB.set(0x00,write=True)
                channel.CUSTOM_PATTERN2_LSB.set(0x00,write=True)
                channel.CUSTOM_PATTERN2_MSB.set(0x00,write=True)
                channel.TEST_PATTERN_SEL.set(0x00,write=True)
                channel.TEST_PAT_RES.set(0x00,write=True)
                channel.TP_RES_EN.set(0x00,write=True)

        @self.command(description  = "Digital Reset")
        def DigRst():
            # Wait for 50 ms for the device to estimate the interleaving errors
            time.sleep(0.250) # TODO: Optimize this timeout
            self.CH[0].JesdDigital.set(value=0x00,index=0x000) # clear reset
            self.CH[1].JesdDigital.set(value=0x00,index=0x000) # clear reset
            self.CH[0].JesdDigital.set(value=0x01,index=0x000) # CHA digital reset
            self.CH[1].JesdDigital.set(value=0x01,index=0x000) # CHB digital reset
            self.CH[0].JesdDigital.set(value=0x00,index=0x000) # clear reset
            self.CH[1].JesdDigital.set(value=0x00,index=0x000) # clear reset

            # Wait for 50 ms for the device to estimate the interleaving errors
            time.sleep(0.250) # TODO: Optimize this timeout
            self.CH[0].MainDigital.set(value=0x00,index=0x000) # clear reset
            self.CH[1].MainDigital.set(value=0x00,index=0x000) # clear reset
            self.CH[0].MainDigital.set(value=0x01,index=0x000) # CHA digital reset
            self.CH[1].MainDigital.set(value=0x01,index=0x000) # CHB digital reset
            self.CH[0].MainDigital.set(value=0x00,index=0x000) # clear reset
            self.CH[1].MainDigital.set(value=0x00,index=0x000) # clear reset
