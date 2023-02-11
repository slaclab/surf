#-----------------------------------------------------------------------------
# This file is part of 'SLAC Firmware Standard Library'.
# It is subject to the license terms in the LICENSE.txt file found in the
# top-level directory of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of 'SLAC Firmware Standard Library', including this file,
# may be copied, modified, propagated, or distributed except according to
# the terms contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr

class SugoiAxiLitePixelMatrixConfig(pr.Device):
    def __init__(self,
            colWidth   = None,
            rowWidth   = None,
            dataWidth  = None,
            timerWidth = None,
            **kwargs):
        super().__init__(**kwargs)

        self.add(pr.RemoteVariable(
            name      = 'Version',
            offset    = 0x0,
            bitSize   = 0,
            bitOffset = 0,
            mode      = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name      = 'COL_GRAY_CODE_G',
            offset    = 0x0,
            bitSize   = 1,
            bitOffset = 4,
            mode      = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name      = 'ROW_GRAY_CODE_G',
            offset    = 0x0,
            bitSize   = 1,
            bitOffset = 5,
            mode      = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name      = 'COL_WIDTH_G',
            offset    = 0x0,
            bitSize   = 4,
            bitOffset = 8,
            mode      = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name      = 'ROW_WIDTH_G',
            offset    = 0x0,
            bitSize   = 4,
            bitOffset = 12,
            mode      = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name      = 'DATA_WIDTH_G',
            offset    = 0x0,
            bitSize   = 4,
            bitOffset = 16,
            mode      = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name      = 'TIMER_WIDTH_G',
            offset    = 0x0,
            bitSize   = 8,
            bitOffset = 24,
            mode      = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name      = 'RdData',
            offset    = 0x4,
            bitSize   = dataWidth,
            bitOffset = 0,
            mode      = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name      = 'ColAddr',
            offset    = 0x8,
            bitSize   = colWidth,
            bitOffset = 0,
            mode      = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name      = 'RowAddr',
            offset    = 0x8,
            bitSize   = rowWidth,
            bitOffset = 10,
            mode      = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name      = 'WrData',
            offset    = 0x8,
            bitSize   = dataWidth,
            bitOffset = 20,
            mode      = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name      = 'WrCmd',
            offset    = 0x8,
            bitSize   = 1,
            bitOffset = 31,
            mode      = 'WO',
        ))

        self.add(pr.RemoteVariable(
            name      = 'TimerSize',
            offset    = 0xC,
            bitSize   = timerWidth,
            bitOffset = 0,
            mode      = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name      = 'AllCol',
            offset    = 0xC,
            bitSize   = 1,
            bitOffset = 16,
            mode      = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name      = 'AllCol',
            offset    = 0xC,
            bitSize   = 1,
            bitOffset = 17,
            mode      = 'RW',
        ))
