#-----------------------------------------------------------------------------
# Description:
# PyRogue Ads54J60 Module
#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr
import time
import surf.devices.ti

class Ads54J60(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        ################
        # Base addresses
        ################
        generalAddr = (0x0 << 14)
        mainDigital = (0x1 << 14) # With respect to CH
        # jesdDigital = (0x2 << 14) # With respect to CH
        # jesdAnalog  = (0x3 << 14) # With respect to CH
        masterPage  = (0x7 << 14)
        analogPage  = (0x8 << 14)
        unusedPages = (0xE << 14)
        chA         = (0x0 << 14)
        chB         = (0x8 << 14)

        #####################
        # Add Device Channels
        #####################
        self.add(surf.devices.ti.Ads54J60Channel(name='CH[0]',description='Channel A',offset=chA,expand=False))
        self.add(surf.devices.ti.Ads54J60Channel(name='CH[1]',description='Channel B',offset=chB,expand=False))

        ##################
        # General Register
        ##################

        self.add(pr.RemoteCommand(
            name         = "RESET",
            description  = "Send 0x81 value to reset the device",
            offset       = (generalAddr + (4*0x000)),
            bitSize      = 8,
            bitOffset    = 0,
            base         = pr.UInt,
            # mode         = "WO",
            hidden       = True,
            function     = pr.BaseCommand.createTouch(0x81)
        ))

        self.add(pr.RemoteVariable(
            name         = "HW_RST",
            description  = "Hardware Reset",
            offset       = (0xF << 14),
            bitSize      = 1,
            bitOffset    = 0,
            base         = pr.UInt,
            mode         = "RW",
            hidden       = True,
        ))

        #############
        # Master Page
        #############

        self.add(pr.RemoteVariable(
            name         = "PDN_ADC_CHA_0",
            description  = "",
            offset       = (masterPage + (4*0x20)),
            bitSize      = 4,
            bitOffset    = 4,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PDN_ADC_CHB_0",
            description  = "",
            offset       = (masterPage + (4*0x20)),
            bitSize      = 4,
            bitOffset    = 0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PDN_BUFFER_CHB_0",
            description  = "",
            offset       = (masterPage + (4*0x21)),
            bitSize      = 2,
            bitOffset    = 6,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PDN_BUFFER_CHA_0",
            description  = "",
            offset       = (masterPage + (4*0x21)),
            bitSize      = 2,
            bitOffset    = 4,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PDN_ADC_CHA_1",
            description  = "",
            offset       = (masterPage + (4*0x23)),
            bitSize      = 4,
            bitOffset    = 4,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PDN_ADC_CHB_1",
            description  = "",
            offset       = (masterPage + (4*0x23)),
            bitSize      = 4,
            bitOffset    = 0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PDN_BUFFER_CHB_1",
            description  = "",
            offset       = (masterPage + (4*0x24)),
            bitSize      = 2,
            bitOffset    = 6,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PDN_BUFFER_CHA_1",
            description  = "",
            offset       = (masterPage + (4*0x24)),
            bitSize      = 2,
            bitOffset    = 4,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "GLOBAL_PDN",
            description  = "",
            offset       = (masterPage + (4*0x26)),
            bitSize      = 1,
            bitOffset    = 7,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "OVERRIDE_PDN_PIN",
            description  = "",
            offset       = (masterPage + (4*0x26)),
            bitSize      = 1,
            bitOffset    = 6,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PDN_MASK_SEL",
            description  = "",
            offset       = (masterPage + (4*0x26)),
            bitSize      = 1,
            bitOffset    = 5,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "EN_INPUT_DC_COUPLING",
            description  = "",
            offset       = (masterPage + (4*0x4F)),
            bitSize      = 1,
            bitOffset    = 0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "MASK_SYSREF",
            description  = "",
            offset       = (masterPage + (4*0x53)),
            bitSize      = 1,
            bitOffset    = 6,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "EN_SYSREF_DC_COUPLING",
            description  = "",
            offset       = (masterPage + (4*0x53)),
            bitSize      = 1,
            bitOffset    = 1,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "SET_SYSREF",
            description  = "",
            offset       = (masterPage + (4*0x53)),
            bitSize      = 1,
            bitOffset    = 0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "ENABLE_MANUAL_SYSREF",
            description  = "",
            offset       = (masterPage + (4*0x54)),
            bitSize      = 1,
            bitOffset    = 7,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PDN_MASK",
            description  = "",
            offset       = (masterPage + (4*0x55)),
            bitSize      = 1,
            bitOffset    = 4,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "FOVR_CHB",
            description  = "",
            offset       = (masterPage + (4*0x59)),
            bitSize      = 1,
            bitOffset    = 7,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "AlwaysWrite0x1_A",
            description  = "Always set this bit to 1",
            offset       = (masterPage + (4*0x59)),
            bitSize      = 1,
            bitOffset    = 5,
            base         = pr.UInt,
            mode         = "WO",
            value        = 0x1,
            hidden       = True,
            verify       = False,
        ))


        #############
        # Analog Page
        #############

        self.add(pr.RemoteVariable(
            name         = "FOVR_THRESHOLD_PROG",
            description  = "",
            offset       = (analogPage + (4*0x5F)),
            bitSize      = 8,
            bitOffset    = 0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        ##############################
        # Main Digital
        ##############################

        self.add(pr.RemoteVariable(
            name         = "DigitalResetChA",
            description  = "",
            offset       = mainDigital + chA + (4*0x000),
            bitSize      = 32,
            bitOffset    = 0,
            updateNotify = False,
            bulkOpEn     = False,
            verify       = False,
            hidden       = True,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "DigitalResetChB",
            description  = "",
            offset       = mainDigital + chB + (4*0x000),
            bitSize      = 32,
            bitOffset    = 0,
            updateNotify = False,
            bulkOpEn     = False,
            verify       = False,
            hidden       = True,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PllResetChA",
            description  = "",
            offset       = mainDigital + chA + (4*0x017),
            bitSize      = 32,
            bitOffset    = 0,
            updateNotify = False,
            bulkOpEn     = False,
            verify       = False,
            hidden       = True,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PllResetChB",
            description  = "",
            offset       = mainDigital + chB + (4*0x017),
            bitSize      = 32,
            bitOffset    = 0,
            updateNotify = False,
            bulkOpEn     = False,
            verify       = False,
            hidden       = True,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "DigResetAllChA",
            description  = "",
            offset       = mainDigital + chA + (4*0x0F7),
            bitSize      = 32,
            bitOffset    = 0,
            updateNotify = False,
            bulkOpEn     = False,
            verify       = False,
            hidden       = True,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "DigResetAllChB",
            description  = "",
            offset       = mainDigital + chB + (4*0x0F7),
            bitSize      = 32,
            bitOffset    = 0,
            updateNotify = False,
            bulkOpEn     = False,
            verify       = False,
            hidden       = True,
            base         = pr.UInt,
            mode         = "RW",
        ))

        ##############################
        # Unused Pages
        ##############################

        self.add(pr.RemoteVariable(
            name         = "UnusedPages",
            description  = "",
            offset       = unusedPages,
            bitSize      = 32,
            bitOffset    = 0,
            updateNotify = False,
            bulkOpEn     = False,
            verify       = False,
            hidden       = True,
            base         = pr.UInt,
            mode         = "RW",
        ))

        ##############################
        # Commands
        ##############################

        @self.command(name= "DigRst", description  = "Digital Reset")
        def DigRst():
            self.DigitalResetChA.set(0x00)  # CHA: clear reset
            self.DigitalResetChB.set(0x00)  # CHB: clear reset
            self.DigitalResetChA.set(0x01)  # CHA: PULSE RESET
            self.DigitalResetChB.set(0x01)  # CHB: PULSE RESET
            self.DigitalResetChA.set(0x00)  # CHA: clear reset
            self.DigitalResetChB.set(0x00)  # CHB: clear reset

        @self.command(name= "PllRst", description  = "PLL Reset")
        def PllRst():
            self.PllResetChA.set(0x00)  # CHA: PLL clear
            self.PllResetChB.set(0x00)  # CHB: PLL clear
            self.PllResetChA.set(0x40)  # CHA: PLL reset
            self.PllResetChB.set(0x40)  # CHB: PLL reset
            self.PllResetChA.set(0x00)  # CHA: PLL clear
            self.PllResetChB.set(0x00)  # CHB: PLL clear

        @self.command(name= "Init", description  = "Device Initiation")
        def Init():
            self.HW_RST.set(0x1)
            self.HW_RST.set(0x0)
            time.sleep(0.001)
            self.RESET()

            self.UnusedPages.set(0x00)      # Clear any unwanted content from the unused pages of the JESD bank.

            self.DigResetAllChA.set(0x01)   # Use the DIG RESET register bit to reset all pages in the JESD bank (self-clearing bit)
            self.DigResetAllChB.set(0x01)   # Use the DIG RESET register bit to reset all pages in the JESD bank (self-clearing bit)

            self.DigitalResetChA.set(0x01)  # CHA: PULSE RESET
            self.DigitalResetChB.set(0x01)  # CHB: PULSE RESET
            self.DigitalResetChA.set(0x00)  # CHA: clear reset
            self.DigitalResetChB.set(0x00)  # CHB: clear reset

            self.AlwaysWrite0x1_A.set(0x20) # Set the ALWAYS WRITE 1 bit

            self.PllRst()
