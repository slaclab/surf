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

        super().__init__(
            size        = (0x1 << 19),
            **kwargs)

        ################
        # Base addresses
        ################
        generalAddr     = (0x0 << 14)
        offsetCorrector = (0x1 << 14) # With respect to CH
        # digitalGain     = (0x2 << 14) # With respect to CH
        mainDigital     = (0x3 << 14) # With respect to CH
        jesdDigital     = (0x4 << 14) # With respect to CH
        # decFilter       = (0x5 << 14) # With respect to CH
        # pwrDet          = (0x6 << 14) # With respect to CH
        masterPage      = (0x7 << 14)
        analogPage      = (0x8 << 14)
        chA             = (0x0 << 14)
        chB             = (0x8 << 14)
        rawInterface    = (0x1 << 18)

        #####################
        # Add Device Channels
        #####################
        self.add(surf.devices.ti.Adc32Rf45Channel(name='CH[0]',description='Channel A',offset=(0x0 << 14),expand=False,verify=verify))
        self.add(surf.devices.ti.Adc32Rf45Channel(name='CH[1]',description='Channel B',offset=(0x8 << 14),expand=False,verify=verify))

        ##################
        # General Register
        ##################

        self.add(pr.RemoteCommand(
            name         = "RESET",
            description  = "Send 0x81 value to reset the device",
            offset       =  (generalAddr + (4*0x000)),
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
            offset       =  (0xF << 14),
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
            hidden       =  True,
            overlapEn    =  True,
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
            overlapEn    =  True,
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
            overlapEn    =  True,
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
            overlapEn    =  True,
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
            overlapEn    =  True,
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
            overlapEn    =  True,
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
            overlapEn    =  True,
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
            overlapEn    =  True,
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
            overlapEn    =  True,
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
            overlapEn    =  True,
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
            overlapEn    =  True,
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
            overlapEn    =  True,
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
            overlapEn    =  True,
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
            overlapEn    =  True,
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
            overlapEn    =  True,
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
            overlapEn    =  True,
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
            overlapEn    =  True,
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
            overlapEn    =  True,
        ))


        ##############################
        # Commands
        ##############################
        @self.command(description  = "Device Initiation")
        def Init():
            self.Powerup_AnalogConfig()

            # Wait for 50 ms for the device to estimate the interleaving errors
            time.sleep(0.100) # TODO: Optimize this timeout

            self.IL_Config_Nyq1_ChA()
            self.IL_Config_Nyq1_ChB()

            time.sleep(0.100) # TODO: Optimize this timeout

            self.SetNLTrim()

            time.sleep(0.100) # TODO: Optimize this timeout

            self.JESD_DDC_config()

            time.sleep(0.100) # TODO: Optimize this timeout

            self._rawWrite(offsetCorrector + chA + (4*0x068),0xA2) #... freeze offset estimation
            self._rawWrite(offsetCorrector + chB + (4*0x068),0xA2) #... freeze offset estimation

        @self.command()
        def Powerup_AnalogConfig():
            self._rawWrite(generalAddr + (4*0x0000),0x81) # Global software reset. Remember the sequence of programming the config files is Powerup_Analog_Config-->IL_Config_Nyqx_chA-->IL_Config_Nyqx_chB-->NL_Config_Nyqx_chA-->NL_Config_Nyqx_chB-->JESD_Config
            self._rawWrite(generalAddr + (4*0x0011),0xFF) # Select ADC page.
            self._rawWrite(generalAddr + (4*0x0022),0xC0) # Analog trims start here.
            self._rawWrite(generalAddr + (4*0x0032),0x80) # ...
            self._rawWrite(generalAddr + (4*0x0033),0x08) # ...
            self._rawWrite(generalAddr + (4*0x0042),0x03) # ...
            self._rawWrite(generalAddr + (4*0x0043),0x03) # ...
            self._rawWrite(generalAddr + (4*0x0045),0x58) # ...
            self._rawWrite(generalAddr + (4*0x0046),0xC4) # ...
            self._rawWrite(generalAddr + (4*0x0047),0x01) # ...
            self._rawWrite(generalAddr + (4*0x0053),0x01) # ...
            self._rawWrite(generalAddr + (4*0x0054),0x08) # ...
            self._rawWrite(generalAddr + (4*0x0064),0x05) # ...
            self._rawWrite(generalAddr + (4*0x0072),0x84) # ...
            self._rawWrite(generalAddr + (4*0x008C),0x80) # ...
            self._rawWrite(generalAddr + (4*0x0097),0x80) # ...
            self._rawWrite(generalAddr + (4*0x00F0),0x38) # ...
            self._rawWrite(generalAddr + (4*0x00F1),0xBF) # Analog trims ended here.
            self._rawWrite(generalAddr + (4*0x0011),0x00) # Disable ADC Page
            self._rawWrite(generalAddr + (4*0x0012),0x04) # Select Master Page
            self._rawWrite(generalAddr + (4*0x0025),0x01) # Global Analog Trims start here.
            self._rawWrite(generalAddr + (4*0x0026),0x40) #...
            self._rawWrite(generalAddr + (4*0x0027),0x80) #...
            self._rawWrite(generalAddr + (4*0x0029),0x40) #...
            self._rawWrite(generalAddr + (4*0x002A),0x80) #...
            self._rawWrite(generalAddr + (4*0x002C),0x40) #...
            self._rawWrite(generalAddr + (4*0x002D),0x80) #...
            self._rawWrite(generalAddr + (4*0x002F),0x40) #...
            self._rawWrite(generalAddr + (4*0x0034),0x01) #...
            self._rawWrite(generalAddr + (4*0x003F),0x01) #...
            self._rawWrite(generalAddr + (4*0x0039),0x50) #...
            self._rawWrite(generalAddr + (4*0x003B),0x28) #...
            self._rawWrite(generalAddr + (4*0x0040),0x80) #...
            self._rawWrite(generalAddr + (4*0x0042),0x40) #...
            self._rawWrite(generalAddr + (4*0x0043),0x80) #...
            self._rawWrite(generalAddr + (4*0x0045),0x40) #...
            self._rawWrite(generalAddr + (4*0x0046),0x80) #...
            self._rawWrite(generalAddr + (4*0x0048),0x40) #...
            self._rawWrite(generalAddr + (4*0x0049),0x80) #...
            self._rawWrite(generalAddr + (4*0x004B),0x40) #...
            self._rawWrite(generalAddr + (4*0x0053),0x60) #...
            self._rawWrite(generalAddr + (4*0x0059),0x02) #...
            self._rawWrite(generalAddr + (4*0x005B),0x08) #...
            self._rawWrite(generalAddr + (4*0x005c),0x07) #...
#            self._rawWrite(generalAddr + (4*0x0057),0x10) # Register control for SYSREF --these lines are added in revision SBAA226C.
#            self._rawWrite(generalAddr + (4*0x0057),0x18) # Pulse SYSREF, pull high --these lines are added in revision SBAA226C.
#            self._rawWrite(generalAddr + (4*0x0057),0x10) # Pulse SYSREF, pull back low --these lines are added in revision SBAA226C.
#            self._rawWrite(generalAddr + (4*0x0057),0x18) # Pulse SYSREF, pull high --these lines are added in revision SBAA226C.
#            self._rawWrite(generalAddr + (4*0x0057),0x10) # Pulse SYSREF, pull back low --these lines are added in revision SBAA226C.
            self._rawWrite(generalAddr + (4*0x0057),0x00) # Give SYSREF control back to device pin --these lines are added in revision SBAA226C.
            self._rawWrite(generalAddr + (4*0x0012),0x00) # Master page disabled
            self._rawWrite(generalAddr + (4*0x0011),0xFF) # Select ADC Page
            self._rawWrite(generalAddr + (4*0x0083),0x07) # Additioanal Analog trims
            self._rawWrite(generalAddr + (4*0x005C),0x00) #...
            self._rawWrite(generalAddr + (4*0x005C),0x01) #...
            self._rawWrite(generalAddr + (4*0x0011),0x00) #Disable ADC Page. Power up Analog writes end here. Program appropriate -->IL_Config_Nyqx_chA-->IL_Config_Nyqx_chB-->NL_Config_Nyqx_chA-->NL_Config_Nyqx_chB-->JESD_Config

            self._rawWrite(rawInterface + (4*0x4001),0x00) #DC corrector Bandwidth settings
            self._rawWrite(rawInterface + (4*0x4002),0x00) #...
            self._rawWrite(rawInterface + (4*0x4003),0x00) #...
            self._rawWrite(rawInterface + (4*0x4004),0x61) #...
            self._rawWrite(rawInterface + (4*0x6068),0x22) #...
            self._rawWrite(rawInterface + (4*0x4003),0x01) #...
            self._rawWrite(rawInterface + (4*0x6068),0x22) #...

            self.SYSREF_DEL_EN.set(self.SYSREF_DEL_EN.value(), write=True)
            self.SYSREF_DEL_HI.set(self.SYSREF_DEL_HI.value(), write=True)
            self.SYSREF_DEL_LO.set(self.SYSREF_DEL_LO.value(), write=True)

            self.SYNCB_POL.set(self.SYNCB_POL.value(), write=True)
            self.JESD_OUTPUT_SWING.set(self.JESD_OUTPUT_SWING.value(), write=True)



        @self.command(description = "Set IL ChA")
        def IL_Config_Nyq1_ChA():
            self._rawWrite(mainDigital + chA + (4*0x044),0x01) # Program global settings for Interleaving Corrector
            self._rawWrite(mainDigital + chA + (4*0x068),0x04) #
            self._rawWrite(mainDigital + chA + (4*0x0FF),0xC0) #...
            self._rawWrite(mainDigital + chA + (4*0x0A2),0x08) # Progam nyquist zone 1 for chA, nyquist zone = 1 : 0x08, nyquist zone = 2 : 0x09, nyquist zone = 3 : 0x0A
            self._rawWrite(mainDigital + chA + (4*0x0A9),0x03) #...
            self._rawWrite(mainDigital + chA + (4*0x0AB),0x77) #...
            self._rawWrite(mainDigital + chA + (4*0x0AC),0x01) #...
            self._rawWrite(mainDigital + chA + (4*0x0AD),0x77) #...
            self._rawWrite(mainDigital + chA + (4*0x0AE),0x01) #...
            self._rawWrite(mainDigital + chA + (4*0x096),0x0F) #...
            self._rawWrite(mainDigital + chA + (4*0x097),0x26) #...
            self._rawWrite(mainDigital + chA + (4*0x08F),0x0C) #...
            self._rawWrite(mainDigital + chA + (4*0x08C),0x08) #...
            self._rawWrite(mainDigital + chA + (4*0x080),0x0F) #...
            self._rawWrite(mainDigital + chA + (4*0x081),0xCB) #...
            self._rawWrite(mainDigital + chA + (4*0x07D),0x03) #...
            self._rawWrite(mainDigital + chA + (4*0x056),0x75) #...
            self._rawWrite(mainDigital + chA + (4*0x057),0x75) #...
            self._rawWrite(mainDigital + chA + (4*0x053),0x00) #...
            self._rawWrite(mainDigital + chA + (4*0x04B),0x03) #...
            self._rawWrite(mainDigital + chA + (4*0x049),0x80) #...
            self._rawWrite(mainDigital + chA + (4*0x043),0x26) #...
            self._rawWrite(mainDigital + chA + (4*0x05E),0x01) #...
            self._rawWrite(mainDigital + chA + (4*0x042),0x38) #...
            self._rawWrite(mainDigital + chA + (4*0x05A),0x04) #...
            self._rawWrite(mainDigital + chA + (4*0x071),0x20) #...
            self._rawWrite(mainDigital + chA + (4*0x062),0x00) #...
            self._rawWrite(mainDigital + chA + (4*0x098),0x00) #...
            self._rawWrite(mainDigital + chA + (4*0x099),0x08) #...
            self._rawWrite(mainDigital + chA + (4*0x09C),0x08) #...
            self._rawWrite(mainDigital + chA + (4*0x09D),0x20) #...
            self._rawWrite(mainDigital + chA + (4*0x0BE),0x03) #...
            self._rawWrite(mainDigital + chA + (4*0x069),0x00) #...
            self._rawWrite(mainDigital + chA + (4*0x045),0x10) #...
            self._rawWrite(mainDigital + chA + (4*0x08D),0x64) #...
            self._rawWrite(mainDigital + chA + (4*0x08B),0x20) #...
            self._rawWrite(mainDigital + chA + (4*0x000),0x00) # Dig Core reset
            self._rawWrite(mainDigital + chA + (4*0x000),0x01) #...
            self._rawWrite(mainDigital + chA + (4*0x000),0x00) #...

        @self.command()
        def IL_Config_Nyq1_ChB():
            self._rawWrite(mainDigital + chB + (4*0x049),0x80) # Special setting for chB
            self._rawWrite(mainDigital + chB + (4*0x042),0x20) # Special setting for chB
            self._rawWrite(mainDigital + chB + (4*0x0A2),0x08) # Progam nyquist zone 1 for chB, nyquist zone = 1 : 0x08, nyquist zone = 2 : 0x09, nyquist zone = 3 : 0x0A
            self._rawWrite(mainDigital + chB + (4*0x003),0x00) # Main digital page selected for chA
            self._rawWrite(mainDigital + chB + (4*0x000),0x00) #...
            self._rawWrite(mainDigital + chB + (4*0x000),0x01) #...
            self._rawWrite(mainDigital + chB + (4*0x000),0x00) #...

        @self.command(description  = "Set nonlinear trims")
        def SetNLTrim():
            # Nonlinearity trims
            self._rawWrite(rawInterface + (4*0x4003),0x00) #chA Non Linearity Trims for Nyq1. Remember the sequence of programming the config files is Powerup_Analog_Config-->IL_Config_Nyqx_chA-->IL_Config_Nyqx_chB-->NL_Config_Nyqx_chA-->NL_Config_Nyqx_chB-->JESD_Config
            self._rawWrite(rawInterface + (4*0x4004),0x20) #...
            self._rawWrite(rawInterface + (4*0x4002),0xF8) #...
            self._rawWrite(rawInterface + (4*0x603C),0xF5) #...
            self._rawWrite(rawInterface + (4*0x603D),0x01) #...
            self._rawWrite(rawInterface + (4*0x603E),0xF0) #...
            self._rawWrite(rawInterface + (4*0x603F),0x0C) #...
            self._rawWrite(rawInterface + (4*0x6040),0x0A) #...
            self._rawWrite(rawInterface + (4*0x6041),0xFE) #...
            self._rawWrite(rawInterface + (4*0x6053),0xF5) #...
            self._rawWrite(rawInterface + (4*0x6054),0x01) #...
            self._rawWrite(rawInterface + (4*0x6055),0xEE) #...
            self._rawWrite(rawInterface + (4*0x6056),0x0E) #...
            self._rawWrite(rawInterface + (4*0x6057),0x0B) #...
            self._rawWrite(rawInterface + (4*0x6058),0xFE) #...
            self._rawWrite(rawInterface + (4*0x606A),0xF4) #...
            self._rawWrite(rawInterface + (4*0x606B),0x01) #...
            self._rawWrite(rawInterface + (4*0x606C),0xF0) #...
            self._rawWrite(rawInterface + (4*0x606D),0x0B) #...
            self._rawWrite(rawInterface + (4*0x606E),0x09) #...
            self._rawWrite(rawInterface + (4*0x606F),0xFE) #...
            self._rawWrite(rawInterface + (4*0x6081),0xF5) #...
            self._rawWrite(rawInterface + (4*0x6082),0x01) #...
            self._rawWrite(rawInterface + (4*0x6083),0xEE) #...
            self._rawWrite(rawInterface + (4*0x6084),0x0D) #...
            self._rawWrite(rawInterface + (4*0x6085),0x0A) #...
            self._rawWrite(rawInterface + (4*0x6086),0xFE) #...
            self._rawWrite(rawInterface + (4*0x6098),0xFD) #...
            self._rawWrite(rawInterface + (4*0x6099),0x00) #...
            self._rawWrite(rawInterface + (4*0x609A),0x00) #...
            self._rawWrite(rawInterface + (4*0x609B),0x00) #...
            self._rawWrite(rawInterface + (4*0x609C),0x00) #...
            self._rawWrite(rawInterface + (4*0x609D),0x00) #...
            self._rawWrite(rawInterface + (4*0x60AF),0xFF) #...
            self._rawWrite(rawInterface + (4*0x60B0),0x00) #...
            self._rawWrite(rawInterface + (4*0x60B1),0x01) #...
            self._rawWrite(rawInterface + (4*0x60B2),0xFF) #...
            self._rawWrite(rawInterface + (4*0x60B3),0xFF) #...
            self._rawWrite(rawInterface + (4*0x60B4),0x00) #...
            self._rawWrite(rawInterface + (4*0x60C6),0xFE) #...
            self._rawWrite(rawInterface + (4*0x60C7),0x00) #...
            self._rawWrite(rawInterface + (4*0x60C8),0x00) #...
            self._rawWrite(rawInterface + (4*0x60C9),0x02) #...
            self._rawWrite(rawInterface + (4*0x60CA),0x00) #...
            self._rawWrite(rawInterface + (4*0x60CB),0x00) #...
            self._rawWrite(rawInterface + (4*0x60DD),0xFF) #...
            self._rawWrite(rawInterface + (4*0x60DE),0x00) #...
            self._rawWrite(rawInterface + (4*0x60DF),0x02) #...
            self._rawWrite(rawInterface + (4*0x60E0),0x00) #...
            self._rawWrite(rawInterface + (4*0x60E1),0xFE) #...
            self._rawWrite(rawInterface + (4*0x60E2),0x00) #...
            self._rawWrite(rawInterface + (4*0x60F4),0x00) #...
            self._rawWrite(rawInterface + (4*0x60F5),0x00) #...
            self._rawWrite(rawInterface + (4*0x60FB),0x01) #...
            self._rawWrite(rawInterface + (4*0x60FC),0x01) #...

            self._rawWrite(rawInterface + (4*0x4003),0x00) #chB Non Linearity Trims for Nyq1. Remember the sequence of programming the config files is Powerup_Analog_Config-->IL_Config_Nyqx_chA-->IL_Config_Nyqx_chB-->NL_Config_Nyqx_chA-->NL_Config_Nyqx_chB-->JESD_Config
            self._rawWrite(rawInterface + (4*0x4004),0x20) #...
            self._rawWrite(rawInterface + (4*0x4002),0xF9) #...
            self._rawWrite(rawInterface + (4*0x6074),0xF4) #...
            self._rawWrite(rawInterface + (4*0x6075),0x01) #...
            self._rawWrite(rawInterface + (4*0x6076),0xEF) #...
            self._rawWrite(rawInterface + (4*0x6077),0x0C) #...
            self._rawWrite(rawInterface + (4*0x6078),0x0A) #...
            self._rawWrite(rawInterface + (4*0x6079),0xFE) #...
            self._rawWrite(rawInterface + (4*0x608B),0xF4) #...
            self._rawWrite(rawInterface + (4*0x608C),0x01) #...
            self._rawWrite(rawInterface + (4*0x608D),0xEE) #...
            self._rawWrite(rawInterface + (4*0x608E),0x0D) #...
            self._rawWrite(rawInterface + (4*0x608F),0x0A) #...
            self._rawWrite(rawInterface + (4*0x6090),0xFE) #...
            self._rawWrite(rawInterface + (4*0x60A2),0xF4) #...
            self._rawWrite(rawInterface + (4*0x60A3),0x01) #...
            self._rawWrite(rawInterface + (4*0x60A4),0xEF) #...
            self._rawWrite(rawInterface + (4*0x60A5),0x0C) #...
            self._rawWrite(rawInterface + (4*0x60A6),0x0A) #...
            self._rawWrite(rawInterface + (4*0x60A7),0xFE) #...
            self._rawWrite(rawInterface + (4*0x60B9),0xF4) #...
            self._rawWrite(rawInterface + (4*0x60BA),0x01) #...
            self._rawWrite(rawInterface + (4*0x60BB),0xEF) #...
            self._rawWrite(rawInterface + (4*0x60BC),0x0D) #...
            self._rawWrite(rawInterface + (4*0x60BD),0x0A) #...
            self._rawWrite(rawInterface + (4*0x60BE),0xFE) #...
            self._rawWrite(rawInterface + (4*0x60D0),0xFF) #...
            self._rawWrite(rawInterface + (4*0x60D1),0x00) #...
            self._rawWrite(rawInterface + (4*0x60D2),0xFF) #...
            self._rawWrite(rawInterface + (4*0x60D3),0x01) #...
            self._rawWrite(rawInterface + (4*0x60D4),0x00) #...
            self._rawWrite(rawInterface + (4*0x60D5),0x00) #...
            self._rawWrite(rawInterface + (4*0x60E7),0xFF) #...
            self._rawWrite(rawInterface + (4*0x60E8),0x00) #...
            self._rawWrite(rawInterface + (4*0x60E9),0x01) #...
            self._rawWrite(rawInterface + (4*0x60EA),0x00) #...
            self._rawWrite(rawInterface + (4*0x60EB),0x00) #...
            self._rawWrite(rawInterface + (4*0x60EC),0x00) #...
            self._rawWrite(rawInterface + (4*0x60FE),0xFE) #...
            self._rawWrite(rawInterface + (4*0x60FF),0x00) #...
            self._rawWrite(rawInterface + (4*0x4002),0xFA) #...
            self._rawWrite(rawInterface + (4*0x6000),0xFF) #...
            self._rawWrite(rawInterface + (4*0x6001),0x02) #...
            self._rawWrite(rawInterface + (4*0x6002),0x01) #...
            self._rawWrite(rawInterface + (4*0x6003),0x00) #...
            self._rawWrite(rawInterface + (4*0x6015),0xFF) #...
            self._rawWrite(rawInterface + (4*0x6016),0x00) #...
            self._rawWrite(rawInterface + (4*0x6017),0x01) #...
            self._rawWrite(rawInterface + (4*0x6018),0x00) #...
            self._rawWrite(rawInterface + (4*0x6019),0xFF) #...
            self._rawWrite(rawInterface + (4*0x601A),0x00) #...
            self._rawWrite(rawInterface + (4*0x602C),0x00) #...
            self._rawWrite(rawInterface + (4*0x602D),0x00) #...
            self._rawWrite(rawInterface + (4*0x6033),0x01) #...
            self._rawWrite(rawInterface + (4*0x6034),0x01) #...
            self._rawWrite(rawInterface + (4*0x4002),0x00) #...
            self._rawWrite(rawInterface + (4*0x4003),0x00) #...
            self._rawWrite(rawInterface + (4*0x4004),0x68) #...
            self._rawWrite(rawInterface + (4*0x6068),0x00) #...
            self._rawWrite(rawInterface + (4*0x0011),0x00) #...
            self._rawWrite(rawInterface + (4*0x0012),0x04) #...
            self._rawWrite(rawInterface + (4*0x005c),0x87) #...
            self._rawWrite(rawInterface + (4*0x0012),0x00) #...

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
                channel.DDC0_NCO1_LSB.set(0x00,write=True)
                channel.DDC0_NCO1_MSB.set(0x4e,write=True)
                channel.DDC0_NCO2_LSB.set(0x00,write=True)
                channel.DDC0_NCO2_MSB.set(0x00,write=True)
                channel.DDC0_NCO3_LSB.set(0x00,write=True)
                channel.DDC0_NCO3_MSB.set(0x00,write=True)
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

#            self._rawWrite(jesdDigital + chB + (4*0x002),0x01) # enable 20x mode
#            self._rawWrite(jesdDigital + chA + (4*0x002),0x01) # enable 20x mode
#            self._rawWrite(jesdDigital + chB + (4*0x037),0x02) # PLL DIV mode to 10 0x00
#            self._rawWrite(jesdDigital + chA + (4*0x037),0x02)
#            self._rawWrite(jesdDigital + chB + (4*0x001),0x80) # set CTRL K
#            self._rawWrite(jesdDigital + chA + (4*0x001),0x80)
#            self._rawWrite(jesdDigital + chB + (4*0x007),0x1F) # set K to 16
#            self._rawWrite(jesdDigital + chA + (4*0x007),0x1F)
#
#            self._rawWrite(decFilter + chA + (4*0x00),0x01) # DDC enable CHA
#            self._rawWrite(decFilter + chA + (4*0x01),0x00) # DDC by 4 CHA
#            self._rawWrite(decFilter + chA + (4*0x02),0x00) # Dual DDC disable CHA
#            self._rawWrite(decFilter + chA + (4*0x05),0x00) # Complex output enable
#            self._rawWrite(decFilter + chA + (4*0x07),0x00) # LSB NCO1 at 800 Mhz CHA
#            self._rawWrite(decFilter + chA + (4*0x08),0x4e) # MSB NCO1 at 800 Mhz
#            self._rawWrite(decFilter + chA + (4*0x09),0x00) # LSB NCO2 0Mhz
#            self._rawWrite(decFilter + chA + (4*0x0A),0x00) # MSB NCO2
#            self._rawWrite(decFilter + chA + (4*0x0B),0x00) # LSB NCO3 0Mhz
#            self._rawWrite(decFilter + chA + (4*0x0C),0x2A) # MSB NCO3
#            self._rawWrite(decFilter + chA + (4*0x0D),0x44) # DDC1 LSB NCO 800Mhz
#            self._rawWrite(decFilter + chA + (4*0x0E),0x44) # DDC1 MSB NCO
#            self._rawWrite(decFilter + chA + (4*0x1f),0x01) # 6dB HBW DDC0
#            self._rawWrite(decFilter + chA + (4*0x14),0x01) # 6dB DDC0
#            self._rawWrite(decFilter + chA + (4*0x16),0x01) # 6dB DDC1
#
#            self._rawWrite(decFilter + chB + (4*0x00),0x01) # DDC enable CHB
#            self._rawWrite(decFilter + chB + (4*0x01),0x00) # DDC by 4 CHB
#            self._rawWrite(decFilter + chB + (4*0x02),0x00) # Dual DDC disable CHB
#            self._rawWrite(decFilter + chB + (4*0x05),0x00) # Complex output enable
#            self._rawWrite(decFilter + chB + (4*0x07),0x00) # LSB NCO1 at 800 Mhz CHB
#            self._rawWrite(decFilter + chB + (4*0x08),0x4e) # MSB NCO1 at 800 Mhz
#            self._rawWrite(decFilter + chB + (4*0x09),0x00) # LSB NCO2 0Mhz
#            self._rawWrite(decFilter + chB + (4*0x0A),0x00) # MSB NCO2
#            self._rawWrite(decFilter + chB + (4*0x0B),0x00) # LSB NCO3 0Mhz
#            self._rawWrite(decFilter + chB + (4*0x0C),0x2A) # MSB NCO3
#            self._rawWrite(decFilter + chB + (4*0x0D),0x44) # DDC1 LSB NCO 800Mhz
#            self._rawWrite(decFilter + chB + (4*0x0E),0x44) # DDC1 MSB NCO
#            self._rawWrite(decFilter + chB + (4*0x14),0x01) # 6dB DDC0
#            self._rawWrite(decFilter + chB + (4*0x16),0x01) # 6dB DDC1
#
#            self._rawWrite(decFilter + chB + (4*0x1f),0x01) # 6dB HBW DDC0

            self._rawWrite(generalAddr + (4*0x0012),0x04) # write 4 to address 12 page select
            self._rawWrite(generalAddr + (4*0x0056),0x00) # sysref dis - check this was written earlier
            self._rawWrite(generalAddr + (4*0x0057),0x00) # sysref dis - whether it has to be zero
#            self._rawWrite(generalAddr + (4*0x0020),0x00)
#            self._rawWrite(generalAddr + (4*0x0020),0x10) # Pdn sysref
#            self.PDN_SYSREF.set(0x1) # Do this in AppTop after JESD link is established

        @self.command(description  = "Digital Reset")
        def DigRst():
            # Wait for 50 ms for the device to estimate the interleaving errors
            time.sleep(0.100) # TODO: Optimize this timeout
            self._rawWrite(jesdDigital + chA + (4*0x000),0x00) # clear reset
            self._rawWrite(jesdDigital + chB + (4*0x000),0x00) # clear reset
            self._rawWrite(jesdDigital + chA + (4*0x000),0x01) # CHA digital reset
            self._rawWrite(jesdDigital + chB + (4*0x000),0x01) # CHB digital reset
            self._rawWrite(jesdDigital + chA + (4*0x000),0x00) # clear reset
            self._rawWrite(jesdDigital + chB + (4*0x000),0x00) # clear reset

            # Wait for 50 ms for the device to estimate the interleaving errors
            time.sleep(0.100) # TODO: Optimize this timeout
            self._rawWrite(mainDigital + chA + (4*0x000),0x00) # clear reset
            self._rawWrite(mainDigital + chB + (4*0x000),0x00) # clear reset
            self._rawWrite(mainDigital + chA + (4*0x000),0x01) # CHA digital reset
            self._rawWrite(mainDigital + chB + (4*0x000),0x01) # CHB digital reset
            self._rawWrite(mainDigital + chA + (4*0x000),0x00) # clear reset
            self._rawWrite(mainDigital + chB + (4*0x000),0x00) # clear reset

            time.sleep(0.100) # TODO: Optimize this timeout
