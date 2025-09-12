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
        indexList = [
            0x012,
            0x056,
            0x057,
            0x020,
            0x000,
            0x011,
            0x022,
            0x032,
            0x033,
            0x042,
            0x043,
            0x045,
            0x046,
            0x047,
            0x053,
            0x054,
            0x064,
            0x072,
            0x08C,
            0x097,
            0x0F0,
            0x0F1,
            0x025,
            0x026,
            0x027,
            0x029,
            0x02A,
            0x02C,
            0x02D,
            0x02F,
            0x034,
            0x03F,
            0x039,
            0x03B,
            0x040,
            0x048,
            0x049,
            0x04B,
            0x059,
            0x05B,
            0x05C,
            0x083,
        ]
        for index in indexList:
            self.add(pr.RemoteVariable(
                name         = f'GeneralAddr_index_0x{index:03X}',
                offset       = (generalAddr + (4*0x0000) + (4*index)),
                bitSize      = 32,
                mode         = "WO",
                hidden       = True,
                verify       = False,
                overlapEn    = True,
            ))

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
        indexList = [
            0x011,
            0x012,
            0x05c,
        ]
        for index in indexList:
            self.add(pr.RemoteVariable(
                name         = f'RawInterface0_index_0x{index:03X}',
                offset       = (rawInterface + (4*0x0000) + (4*index)),
                bitSize      = 32,
                mode         = "WO",
                hidden       = True,
                verify       = False,
                overlapEn    = True,
            ))


        indexList = [
            0x001,
            0x002,
            0x003,
            0x004,
        ]
        for index in indexList:
            self.add(pr.RemoteVariable(
                name         = f'RawInterface4_index_0x{index:03X}',
                offset       = (rawInterface + (4*0x4000) + (4*index)),
                bitSize      = 32,
                mode         = "WO",
                hidden       = True,
                verify       = False,
                overlapEn    = True,
            ))

        indexList = [
            0x03C,
            0x03D,
            0x03E,
            0x03F,
            0x040,
            0x041,
            0x053,
            0x054,
            0x055,
            0x056,
            0x057,
            0x058,
            0x06A,
            0x06B,
            0x06C,
            0x06D,
            0x06E,
            0x06F,
            0x081,
            0x082,
            0x083,
            0x084,
            0x085,
            0x086,
            0x098,
            0x099,
            0x09A,
            0x09B,
            0x09C,
            0x09D,
            0x0AF,
            0x0B0,
            0x0B1,
            0x0B2,
            0x0B3,
            0x0B4,
            0x0C6,
            0x0C7,
            0x0C8,
            0x0C9,
            0x0CA,
            0x0CB,
            0x0DD,
            0x0DE,
            0x0DF,
            0x0E0,
            0x0E1,
            0x0E2,
            0x0F4,
            0x0F5,
            0x0FB,
            0x0FC,
            0x074,
            0x075,
            0x076,
            0x077,
            0x078,
            0x079,
            0x08B,
            0x08C,
            0x08D,
            0x08E,
            0x08F,
            0x090,
            0x0A2,
            0x0A3,
            0x0A4,
            0x0A5,
            0x0A6,
            0x0A7,
            0x0B9,
            0x0BA,
            0x0BB,
            0x0BC,
            0x0BD,
            0x0BE,
            0x0D0,
            0x0D1,
            0x0D2,
            0x0D3,
            0x0D4,
            0x0D5,
            0x0E7,
            0x0E8,
            0x0E9,
            0x0EA,
            0x0EB,
            0x0EC,
            0x0FE,
            0x0FF,
            0x000,
            0x001,
            0x002,
            0x003,
            0x015,
            0x016,
            0x017,
            0x018,
            0x019,
            0x01A,
            0x02C,
            0x02D,
            0x033,
            0x034,
            0x068,
        ]
        for index in indexList:
            self.add(pr.RemoteVariable(
                name         = f'RawInterface6_index_0x{index:03X}',
                offset       = (rawInterface + (4*0x6000) + (4*index)),
                bitSize      = 32,
                mode         = "WO",
                hidden       = True,
                verify       = False,
                overlapEn    = True,
            ))

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
            self.GeneralAddr_index_0x012.set(value=0x04) # write 4 to address 12 page select
            self.GeneralAddr_index_0x056.set(value=0x00) # sysref dis - check this was written earlier
            self.GeneralAddr_index_0x057.set(value=0x00) # sysref dis - whether it has to be zero
            self.GeneralAddr_index_0x020.set(value=0x00)
            self.CH[0].JesdDigital_index_0x03E.set(value=0x00)
            self.CH[1].JesdDigital_index_0x03E.set(value=0x00)

            self.IL_Config_Nyq1_ChA()
            self.IL_Config_Nyq1_ChB()

            time.sleep(0.250)

            self.SetNLTrim()

            time.sleep(0.250)

            self.JESD_DDC_config()

            time.sleep(0.250)

            self.CH[0].OffsetCorrector_index_0x068.set(value=0xA2) #... freeze offset estimation
            self.CH[1].OffsetCorrector_index_0x068.set(value=0xA2) #... freeze offset estimation

            self.GeneralAddr_index_0x012.set(value=0x04) # write 4 to address 12 page select
            self.GeneralAddr_index_0x056.set(value=0x00) # sysref dis - check this was written earlier
            self.GeneralAddr_index_0x057.set(value=0x00) # sysref dis - whether it has to be zero
            self.GeneralAddr_index_0x020.set(value=0x00)

            self.GeneralAddr_index_0x012.set(value=0x04) # write 4 to address 12 page select
            self.CH[0].JesdDigital_index_0x03E.set(value=0x40,) #... MASK CLKDIV SYSREF
            self.CH[1].JesdDigital_index_0x03E.set(value=0x40) #... MASK CLKDIV SYSREF

            self.CH[0].JesdDigital_index_0x03E.set(value=0x60) #... MASK CLKDIV SYSREF + MASK NCO SYSREF
            self.CH[1].JesdDigital_index_0x03E.set(value=0x60) #... MASK CLKDIV SYSREF + MASK NCO SYSREF

            self.GeneralAddr_index_0x020.set(value=0x10) # PDN_SYSREF = 0x1

        @self.command()
        def Powerup_AnalogConfig():
            self.GeneralAddr_index_0x000.set(value=0x81)
            self.GeneralAddr_index_0x011.set(value=0xFF)
            self.GeneralAddr_index_0x022.set(value=0xC0)
            self.GeneralAddr_index_0x032.set(value=0x80)
            self.GeneralAddr_index_0x033.set(value=0x08)
            self.GeneralAddr_index_0x042.set(value=0x03)
            self.GeneralAddr_index_0x043.set(value=0x03)
            self.GeneralAddr_index_0x045.set(value=0x58)
            self.GeneralAddr_index_0x046.set(value=0xC4)
            self.GeneralAddr_index_0x047.set(value=0x01)
            self.GeneralAddr_index_0x053.set(value=0x01)
            self.GeneralAddr_index_0x054.set(value=0x08)
            self.GeneralAddr_index_0x064.set(value=0x05)
            self.GeneralAddr_index_0x072.set(value=0x84)
            self.GeneralAddr_index_0x08C.set(value=0x80)
            self.GeneralAddr_index_0x097.set(value=0x80)
            self.GeneralAddr_index_0x0F0.set(value=0x38)
            self.GeneralAddr_index_0x0F1.set(value=0xBF)
            self.GeneralAddr_index_0x011.set(value=0x00)
            self.GeneralAddr_index_0x012.set(value=0x04)
            self.GeneralAddr_index_0x025.set(value=0x01)
            self.GeneralAddr_index_0x026.set(value=0x40)
            self.GeneralAddr_index_0x027.set(value=0x80)
            self.GeneralAddr_index_0x029.set(value=0x40)
            self.GeneralAddr_index_0x02A.set(value=0x80)
            self.GeneralAddr_index_0x02C.set(value=0x40)
            self.GeneralAddr_index_0x02D.set(value=0x80)
            self.GeneralAddr_index_0x02F.set(value=0x40)
            self.GeneralAddr_index_0x034.set(value=0x01)
            self.GeneralAddr_index_0x03F.set(value=0x01)
            self.GeneralAddr_index_0x039.set(value=0x50)
            self.GeneralAddr_index_0x03B.set(value=0x28)
            self.GeneralAddr_index_0x040.set(value=0x80)
            self.GeneralAddr_index_0x042.set(value=0x40)
            self.GeneralAddr_index_0x043.set(value=0x80)
            self.GeneralAddr_index_0x045.set(value=0x40)
            self.GeneralAddr_index_0x046.set(value=0x80)
            self.GeneralAddr_index_0x048.set(value=0x40)
            self.GeneralAddr_index_0x049.set(value=0x80)
            self.GeneralAddr_index_0x04B.set(value=0x40)
            self.GeneralAddr_index_0x053.set(value=0x60)
            self.GeneralAddr_index_0x059.set(value=0x02)
            self.GeneralAddr_index_0x05B.set(value=0x08)
            self.GeneralAddr_index_0x05C.set(value=0x07)
            self.GeneralAddr_index_0x057.set(value=0x10)
            self.GeneralAddr_index_0x057.set(value=0x18)
            self.GeneralAddr_index_0x057.set(value=0x10)
            self.GeneralAddr_index_0x057.set(value=0x18)
            self.GeneralAddr_index_0x057.set(value=0x10)
            self.GeneralAddr_index_0x057.set(value=0x00)
            self.GeneralAddr_index_0x056.set(value=0x00)
            self.GeneralAddr_index_0x020.set(value=0x00)
            self.GeneralAddr_index_0x012.set(value=0x00)
            self.GeneralAddr_index_0x011.set(value=0xFF)
            self.GeneralAddr_index_0x083.set(value=0x07)
            self.GeneralAddr_index_0x05C.set(value=0x00)
            self.GeneralAddr_index_0x05C.set(value=0x01)
            self.GeneralAddr_index_0x011.set(value=0x00)

            self.RawInterface4_index_0x001.set(value=0x00)
            self.RawInterface4_index_0x002.set(value=0x00)
            self.RawInterface4_index_0x003.set(value=0x00)
            self.RawInterface4_index_0x004.set(value=0x61)
            self.RawInterface6_index_0x068.set(value=0x22)
            self.RawInterface4_index_0x003.set(value=0x01)
            self.RawInterface6_index_0x068.set(value=0x22)

        @self.command(description = "Set IL ChA")
        def IL_Config_Nyq1_ChA():
            self.CH[0].MainDigital_index_0x044.set(value=0x01)
            self.CH[0].MainDigital_index_0x068.set(value=0x04)
            self.CH[0].MainDigital_index_0x0FF.set(value=0xC0)
            self.CH[0].MainDigital_index_0x0A2.set(value=0x08)
            self.CH[0].MainDigital_index_0x0A9.set(value=0x03)
            self.CH[0].MainDigital_index_0x0AB.set(value=0x77)
            self.CH[0].MainDigital_index_0x0AC.set(value=0x01)
            self.CH[0].MainDigital_index_0x0AD.set(value=0x77)
            self.CH[0].MainDigital_index_0x0AE.set(value=0x01)
            self.CH[0].MainDigital_index_0x096.set(value=0x0F)
            self.CH[0].MainDigital_index_0x097.set(value=0x26)
            self.CH[0].MainDigital_index_0x08F.set(value=0x0C)
            self.CH[0].MainDigital_index_0x08C.set(value=0x08)
            self.CH[0].MainDigital_index_0x080.set(value=0x0F)
            self.CH[0].MainDigital_index_0x081.set(value=0xCB)
            self.CH[0].MainDigital_index_0x07D.set(value=0x03)
            self.CH[0].MainDigital_index_0x056.set(value=0x75)
            self.CH[0].MainDigital_index_0x057.set(value=0x75)
            self.CH[0].MainDigital_index_0x053.set(value=0x00)
            self.CH[0].MainDigital_index_0x04B.set(value=0x03)
            self.CH[0].MainDigital_index_0x049.set(value=0x80)
            self.CH[0].MainDigital_index_0x043.set(value=0x26)
            self.CH[0].MainDigital_index_0x05E.set(value=0x01)
            self.CH[0].MainDigital_index_0x042.set(value=0x38)
            self.CH[0].MainDigital_index_0x05A.set(value=0x04)
            self.CH[0].MainDigital_index_0x071.set(value=0x20)
            self.CH[0].MainDigital_index_0x062.set(value=0x00)
            self.CH[0].MainDigital_index_0x098.set(value=0x00)
            self.CH[0].MainDigital_index_0x099.set(value=0x08)
            self.CH[0].MainDigital_index_0x09C.set(value=0x08)
            self.CH[0].MainDigital_index_0x09D.set(value=0x20)
            self.CH[0].MainDigital_index_0x0BE.set(value=0x03)
            self.CH[0].MainDigital_index_0x069.set(value=0x00)
            self.CH[0].MainDigital_index_0x045.set(value=0x10)
            self.CH[0].MainDigital_index_0x08D.set(value=0x64)
            self.CH[0].MainDigital_index_0x08B.set(value=0x20)
            self.CH[0].MainDigital_index_0x000.set(value=0x00)
            self.CH[0].MainDigital_index_0x000.set(value=0x01)
            self.CH[0].MainDigital_index_0x000.set(value=0x00)

        @self.command()
        def IL_Config_Nyq1_ChB():
            self.CH[1].MainDigital_index_0x049.set(value=0x80)
            self.CH[1].MainDigital_index_0x042.set(value=0x20)
            self.CH[1].MainDigital_index_0x0A2.set(value=0x08)
            self.CH[1].MainDigital_index_0x003.set(value=0x00)
            self.CH[1].MainDigital_index_0x000.set(value=0x00)
            self.CH[1].MainDigital_index_0x000.set(value=0x01)
            self.CH[1].MainDigital_index_0x000.set(value=0x00)

        @self.command(description  = "Set nonlinear trims")
        def SetNLTrim():
            # Nonlinearity trims
            self.RawInterface4_index_0x003.set(value=0x00)
            self.RawInterface4_index_0x004.set(value=0x20)
            self.RawInterface4_index_0x002.set(value=0xF8)
            self.RawInterface6_index_0x03C.set(value=0xF5)
            self.RawInterface6_index_0x03D.set(value=0x01)
            self.RawInterface6_index_0x03E.set(value=0xF0)
            self.RawInterface6_index_0x03F.set(value=0x0C)
            self.RawInterface6_index_0x040.set(value=0x0A)
            self.RawInterface6_index_0x041.set(value=0xFE)
            self.RawInterface6_index_0x053.set(value=0xF5)
            self.RawInterface6_index_0x054.set(value=0x01)
            self.RawInterface6_index_0x055.set(value=0xEE)
            self.RawInterface6_index_0x056.set(value=0x0E)
            self.RawInterface6_index_0x057.set(value=0x0B)
            self.RawInterface6_index_0x058.set(value=0xFE)
            self.RawInterface6_index_0x06A.set(value=0xF4)
            self.RawInterface6_index_0x06B.set(value=0x01)
            self.RawInterface6_index_0x06C.set(value=0xF0)
            self.RawInterface6_index_0x06D.set(value=0x0B)
            self.RawInterface6_index_0x06E.set(value=0x09)
            self.RawInterface6_index_0x06F.set(value=0xFE)
            self.RawInterface6_index_0x081.set(value=0xF5)
            self.RawInterface6_index_0x082.set(value=0x01)
            self.RawInterface6_index_0x083.set(value=0xEE)
            self.RawInterface6_index_0x084.set(value=0x0D)
            self.RawInterface6_index_0x085.set(value=0x0A)
            self.RawInterface6_index_0x086.set(value=0xFE)
            self.RawInterface6_index_0x098.set(value=0xFD)
            self.RawInterface6_index_0x099.set(value=0x00)
            self.RawInterface6_index_0x09A.set(value=0x00)
            self.RawInterface6_index_0x09B.set(value=0x00)
            self.RawInterface6_index_0x09C.set(value=0x00)
            self.RawInterface6_index_0x09D.set(value=0x00)
            self.RawInterface6_index_0x0AF.set(value=0xFF)
            self.RawInterface6_index_0x0B0.set(value=0x00)
            self.RawInterface6_index_0x0B1.set(value=0x01)
            self.RawInterface6_index_0x0B2.set(value=0xFF)
            self.RawInterface6_index_0x0B3.set(value=0xFF)
            self.RawInterface6_index_0x0B4.set(value=0x00)
            self.RawInterface6_index_0x0C6.set(value=0xFE)
            self.RawInterface6_index_0x0C7.set(value=0x00)
            self.RawInterface6_index_0x0C8.set(value=0x00)
            self.RawInterface6_index_0x0C9.set(value=0x02)
            self.RawInterface6_index_0x0CA.set(value=0x00)
            self.RawInterface6_index_0x0CB.set(value=0x00)
            self.RawInterface6_index_0x0DD.set(value=0xFF)
            self.RawInterface6_index_0x0DE.set(value=0x00)
            self.RawInterface6_index_0x0DF.set(value=0x02)
            self.RawInterface6_index_0x0E0.set(value=0x00)
            self.RawInterface6_index_0x0E1.set(value=0xFE)
            self.RawInterface6_index_0x0E2.set(value=0x00)
            self.RawInterface6_index_0x0F4.set(value=0x00)
            self.RawInterface6_index_0x0F5.set(value=0x00)
            self.RawInterface6_index_0x0FB.set(value=0x01)
            self.RawInterface6_index_0x0FC.set(value=0x01)
            self.RawInterface4_index_0x003.set(value=0x00)
            self.RawInterface4_index_0x004.set(value=0x20)
            self.RawInterface4_index_0x002.set(value=0xF9)
            self.RawInterface6_index_0x074.set(value=0xF4)
            self.RawInterface6_index_0x075.set(value=0x01)
            self.RawInterface6_index_0x076.set(value=0xEF)
            self.RawInterface6_index_0x077.set(value=0x0C)
            self.RawInterface6_index_0x078.set(value=0x0A)
            self.RawInterface6_index_0x079.set(value=0xFE)
            self.RawInterface6_index_0x08B.set(value=0xF4)
            self.RawInterface6_index_0x08C.set(value=0x01)
            self.RawInterface6_index_0x08D.set(value=0xEE)
            self.RawInterface6_index_0x08E.set(value=0x0D)
            self.RawInterface6_index_0x08F.set(value=0x0A)
            self.RawInterface6_index_0x090.set(value=0xFE)
            self.RawInterface6_index_0x0A2.set(value=0xF4)
            self.RawInterface6_index_0x0A3.set(value=0x01)
            self.RawInterface6_index_0x0A4.set(value=0xEF)
            self.RawInterface6_index_0x0A5.set(value=0x0C)
            self.RawInterface6_index_0x0A6.set(value=0x0A)
            self.RawInterface6_index_0x0A7.set(value=0xFE)
            self.RawInterface6_index_0x0B9.set(value=0xF4)
            self.RawInterface6_index_0x0BA.set(value=0x01)
            self.RawInterface6_index_0x0BB.set(value=0xEF)
            self.RawInterface6_index_0x0BC.set(value=0x0D)
            self.RawInterface6_index_0x0BD.set(value=0x0A)
            self.RawInterface6_index_0x0BE.set(value=0xFE)
            self.RawInterface6_index_0x0D0.set(value=0xFF)
            self.RawInterface6_index_0x0D1.set(value=0x00)
            self.RawInterface6_index_0x0D2.set(value=0xFF)
            self.RawInterface6_index_0x0D3.set(value=0x01)
            self.RawInterface6_index_0x0D4.set(value=0x00)
            self.RawInterface6_index_0x0D5.set(value=0x00)
            self.RawInterface6_index_0x0E7.set(value=0xFF)
            self.RawInterface6_index_0x0E8.set(value=0x00)
            self.RawInterface6_index_0x0E9.set(value=0x01)
            self.RawInterface6_index_0x0EA.set(value=0x00)
            self.RawInterface6_index_0x0EB.set(value=0x00)
            self.RawInterface6_index_0x0EC.set(value=0x00)
            self.RawInterface6_index_0x0FE.set(value=0xFE)
            self.RawInterface6_index_0x0FF.set(value=0x00)
            self.RawInterface4_index_0x002.set(value=0xFA)
            self.RawInterface6_index_0x000.set(value=0xFF)
            self.RawInterface6_index_0x001.set(value=0x02)
            self.RawInterface6_index_0x002.set(value=0x01)
            self.RawInterface6_index_0x003.set(value=0x00)
            self.RawInterface6_index_0x015.set(value=0xFF)
            self.RawInterface6_index_0x016.set(value=0x00)
            self.RawInterface6_index_0x017.set(value=0x01)
            self.RawInterface6_index_0x018.set(value=0x00)
            self.RawInterface6_index_0x019.set(value=0xFF)
            self.RawInterface6_index_0x01A.set(value=0x00)
            self.RawInterface6_index_0x02C.set(value=0x00)
            self.RawInterface6_index_0x02D.set(value=0x00)
            self.RawInterface6_index_0x033.set(value=0x01)
            self.RawInterface6_index_0x034.set(value=0x01)
            self.RawInterface4_index_0x002.set(value=0x00)
            self.RawInterface4_index_0x003.set(value=0x00)
            self.RawInterface4_index_0x004.set(value=0x68)
            self.RawInterface6_index_0x068.set(value=0x00)
            self.RawInterface0_index_0x011.set(value=0x00)
            self.RawInterface0_index_0x012.set(value=0x04)
            self.RawInterface0_index_0x05C.set(value=0x87)
            self.RawInterface0_index_0x012.set(value=0x00)

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
            self.CH[0].JesdDigital_index_0x000.set(value=0x00)
            self.CH[1].JesdDigital_index_0x000.set(value=0x00)
            self.CH[0].JesdDigital_index_0x000.set(value=0x01)
            self.CH[1].JesdDigital_index_0x000.set(value=0x01)
            self.CH[0].JesdDigital_index_0x000.set(value=0x00)
            self.CH[1].JesdDigital_index_0x000.set(value=0x00)

            # Wait for 50 ms for the device to estimate the interleaving errors
            time.sleep(0.250) # TODO: Optimize this timeout
            self.CH[0].MainDigital_index_0x000.set(value=0x00)
            self.CH[1].MainDigital_index_0x000.set(value=0x00)
            self.CH[0].MainDigital_index_0x000.set(value=0x01)
            self.CH[1].MainDigital_index_0x000.set(value=0x01)
            self.CH[0].MainDigital_index_0x000.set(value=0x00)
            self.CH[1].MainDigital_index_0x000.set(value=0x00)
