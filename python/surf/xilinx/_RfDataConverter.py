#-----------------------------------------------------------------------------
# Title      : Xilinx RFSoC data converter module
#-----------------------------------------------------------------------------
# Description:
# Xilinx RFSoC data converter module
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
import surf.xilinx

class RfDataConverter(pr.Device):
    def __init__(
            self,
            gen3 = True, # True if using RFSoC GEN3 Hardware
            **kwargs):
        super().__init__(**kwargs)

        ##############################
        # Variables
        ##############################
        self.add(pr.RemoteVariable(
            name         = "ipVersionMajor",
            description  = "IP version major",
            offset       =  0x0000,
            bitSize      =  8,
            bitOffset    =  24,
            mode         = "RO",
            #overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = "ipVersionMinor",
            description  = "IP version minor",
            offset       =  0x0000,
            bitSize      =  8,
            bitOffset    =  16,
            mode         = "RO",
            #overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = "ipVersionRevision",
            description  = "IP version revision",
            offset       =  0x0000,
            bitSize      =  8,
            bitOffset    =  8,
            mode         = "RO",
            #overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = "Reset",
            description  = "Reset all tiles, autoclear",
            offset       =  0x0004,
            bitSize      =  1,
            bitOffset    =  0,
            mode         = "WO",
            #overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = "InterruptStatus",
            description  = "Interrupt status register",
            offset       =  0x0100,
            bitSize      =  8,
            bitOffset    =  0,
            mode         = "RO",
            hidden       = True,
            #overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = "axiTimeoutInterrupt",
            description  = "Interrupt status register",
            offset       =  0x0100,
            bitSize      =  1,
            bitOffset    =  31,
            mode         = "RO",
            hidden       = True,
            #overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = "InterruptEnable",
            description  = "Interrupt enable register",
            offset       =  0x0104,
            bitSize      =  8,
            bitOffset    =  0,
            mode         = "RW",
            hidden       = True,
            #overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = "axiTimeoutInterruptEnable",
            description  = "Interrupt status register",
            offset       =  0x0104,
            bitSize      =  1,
            bitOffset    =  31,
            mode         = "RW",
            hidden       = True,
            #overlapEn    = True,
        ))

        for i in range(4):
            self.add(surf.xilinx.RfTile(
                name    = f'dacTile[{i}]',
                isAdc   = False,
                gen3    = gen3,
                offset  = 0x04000 + 0x4000*i,
                expand  = False,
            ))

        for i in range(4):
            self.add(surf.xilinx.RfTile(
                name    = f'adcTile[{i}]',
                isAdc   = True,
                gen3    = gen3,
                offset  = 0x14000 + 0x4000*i,
                expand  = False,
            ))

        # self.add(pr.RemoteVariable(
            # name         = "RawData",
            # description  = "",
            # offset       = 0,
            # bitSize      = 32 * 0x10000,
            # bitOffset    = 0,
            # numValues    = 0x10000,
            # valueBits    = 32,
            # valueStride  = 32,
            # updateNotify = True,
            # bulkOpEn     = False, # FALSE for large variables
            # #overlapEn    = True,
            # verify       = False,
            # hidden       = True,
            # base         = pr.UInt,
            # mode         = "RW",
        # ))
