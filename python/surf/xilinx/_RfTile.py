#-----------------------------------------------------------------------------
# Title      : Xilinx RFSoC RF data converter tile
#-----------------------------------------------------------------------------
# Description:
# Xilinx RFSoC RF data converter tile
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

class RfTile(pr.Device):
    def __init__(
            self,
            description = "RFSoC data converter tile registers",
            **kwargs):
        super().__init__(description=description, **kwargs)

        ##############################
        # Variables
        ##############################
        self.add(pr.RemoteVariable(
            name         = "RestartSM",
            description  = "Write 1 to start power-on state machine.  Auto-clear.  SM stops at stages programmed in RestartState",
            offset       =  0x0004,
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RestartStateEnd",
            description  = "End state for power-on sequence",
            offset       =  0x0008,
            bitSize      =  8,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RestartStateStart",
            description  = "Start state for power-on sequence",
            offset       =  0x0008,
            bitSize      =  8,
            bitOffset    =  8,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "CurrentState",
            description  = "Current state register",
            offset       =  0x000C,
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "ResetCount",
            description  = "reset count register",
            offset       =  0x0038,
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "InterruptStatus",
            description  = "interrupt status register",
            offset       =  0x0200,
            bitSize      =  4,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "InterruptEnable",
            description  = "interrupt status register",
            offset       =  0x0204,
            bitSize      =  4,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        for i in range(4):
            self.add(pr.RemoteVariable(
                name         = f'InterruptCh[{i}]',
                description  = f'Converter {i} interrupt enable',
                offset       =  0x0208 + 8*i,
                bitSize      =  32,
                base         = pr.UInt,
                mode         = "RW",
            ))

            self.add(pr.RemoteVariable(
                name         = f'InterruptEnableCh[{i}]',
                description  = f'Converter {i} interrupt register',
                offset       =  0x020C + 8*i,
                bitSize      =  32,
                base         = pr.UInt,
                mode         = "RW",
            ))

        self.add(pr.RemoteVariable(
            name         = "clockPresent",
            description  = "tile common status register",
            offset       =  0x0228,
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "supplyStable",
            description  = "tile common status register",
            offset       =  0x0228,
            bitSize      =  1,
            bitOffset    =  1,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "poweredUp",
            description  = "tile common status register",
            offset       =  0x0228,
            bitSize      =  1,
            bitOffset    =  2,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "pllLocked",
            description  = "tile common status register",
            offset       =  0x0228,
            bitSize      =  1,
            bitOffset    =  3,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "fifoDisable",
            description  = "tile disable register",
            offset       =  0x0230,
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))
