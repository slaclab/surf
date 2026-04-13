#-----------------------------------------------------------------------------
# Description:
# PyRogue Gtpe2Common
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

class Gtpe2Common(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        ##############################
        # Variables
        ##############################

        self.add(pr.RemoteVariable(
            name         = "PLL0_CFG_WRD0",
            description  = "PLL0 configuration register word 0",
            offset       =  (0x0002<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PLL0_CFG_WRD1",
            description  = "PLL0 configuration register word 1",
            offset       =  (0x0003<<2),
            bitSize      =  11,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PLL0_REFCLK_DIV",
            description  = "PLL0 reference clock input divider",
            offset       =  (0x0004<<2),
            bitSize      =  5,
            bitOffset    =  9,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PLL0_FBDIV_45",
            description  = "PLL0 feedback divider 4/5 selection",
            offset       =  (0x0004<<2),
            bitSize      =  1,
            bitOffset    =  7,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PLL0_FBDIV",
            description  = "PLL0 feedback divider value",
            offset       =  (0x0004<<2),
            bitSize      =  6,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PLL0_LOCK_CFG",
            description  = "PLL0 lock detection configuration",
            offset       =  (0x0005<<2),
            bitSize      =  9,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PLL0_INIT_CFG_WRD0",
            description  = "PLL0 initialization configuration word 0",
            offset       =  (0x0006<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PLL0_INIT_CFG_WRD1",
            description  = "PLL0 initialization configuration word 1",
            offset       =  (0x0007<<2),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RSVD_ATTR0",
            description  = "Reserved common block attribute 0",
            offset       =  (0x000A<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PLL1_DMON_CFG",
            description  = "PLL1 digital monitor configuration",
            offset       =  (0x000F<<2),
            bitSize      =  1,
            bitOffset    =  1,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PLL0_DMON_CFG",
            description  = "PLL0 digital monitor configuration",
            offset       =  (0x000F<<2),
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "COMMON_CFG_WRD0",
            description  = "Common block configuration word 0",
            offset       =  (0x0011<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "COMMON_CFG_WRD1",
            description  = "Common block configuration word 1",
            offset       =  (0x0012<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PLL_CLKOUT_CFG",
            description  = "PLL clock output configuration register",
            offset       =  (0x0013<<2),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "BIAS_CFG_WRD0",
            description  = "Common block bias configuration word 0",
            offset       =  (0x0019<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "BIAS_CFG_WRD1",
            description  = "Common block bias configuration word 1",
            offset       =  (0x001A<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "BIAS_CFG_WRD2",
            description  = "Common block bias configuration word 2",
            offset       =  (0x001B<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "BIAS_CFG_WRD3",
            description  = "Common block bias configuration word 3",
            offset       =  (0x001C<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RSVD_ATTR1",
            description  = "Reserved common block attribute 1",
            offset       =  (0x0024<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PLL1_INIT_CFG_WRD0",
            description  = "PLL1 initialization configuration word 0",
            offset       =  (0x0028<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PLL1_INIT_CFG_WRD1",
            description  = "PLL1 initialization configuration word 1",
            offset       =  (0x0029<<2),
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PLL1_LOCK_CFG",
            description  = "PLL1 lock detection configuration",
            offset       =  (0x002A<<2),
            bitSize      =  9,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PLL1_REFCLK_DIV",
            description  = "PLL1 reference clock input divider",
            offset       =  (0x002B<<2),
            bitSize      =  5,
            bitOffset    =  9,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PLL1_FBDIV_45",
            description  = "PLL1 feedback divider 4/5 selection",
            offset       =  (0x002B<<2),
            bitSize      =  1,
            bitOffset    =  7,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PLL1_FBDIV",
            description  = "PLL1 feedback divider value",
            offset       =  (0x002B<<2),
            bitSize      =  6,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PLL1_CFG_WRD0",
            description  = "PLL1 configuration register word 0",
            offset       =  (0x002C<<2),
            bitSize      =  16,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PLL1_CFG_WRD1",
            description  = "PLL1 configuration register word 1",
            offset       =  (0x002D<<2),
            bitSize      =  11,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))
