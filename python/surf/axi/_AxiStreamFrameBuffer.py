#-----------------------------------------------------------------------------
# Title      : PyRogue AXI-Stream Frame Buffer Module
#-----------------------------------------------------------------------------
# Description:
# PyRogue AXI-Stream Frame Buffer Module
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

class AxiStreamFrameBuffer(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.add(pr.RemoteVariable(
            name         = 'RdFinalAddr',
            description  = 'Last occupied address in readable buffer (equals frame length - 1)',
            offset       = 0x0,
            bitSize      = 32,
            bitOffset    = 0,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name        = 'RAM_ADDR_WIDTH_G',
            description = 'Frame Buffer RAM Width configuration',
            offset      = 0x4,
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name         = 'AxisState',
            description  = 'Current state of the AXI-Stream readout FSM',
            offset       = 0x4,
            bitSize      = 2,
            bitOffset    = 8,
            mode         = 'RO',
            pollInterval = 1,
            hidden       = True,
            enum         = {
                0: 'IDLE_S',
                1: 'DONE_S',
                2: 'MOVE_S',
            },
        ))

        self.add(pr.RemoteVariable(
            name        = 'SoftTrig',
            description = 'Software trigger request',
            offset      = 0x8,
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'WO',
        ))
