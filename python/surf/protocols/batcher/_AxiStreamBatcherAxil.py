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

class AxiStreamBatcherAxil(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.add(pr.RemoteVariable(
            name = 'SuperFrameByteThreshold',
            offset = 0x00,
            bitOffset = 0,
            bitSize = 32,
            mode = 'RW',
            base = pr.UInt,
            disp = '{:d}'))

        self.add(pr.RemoteVariable(
            name = 'MaxSubFrames',
            offset = 0x04,
            bitOffset = 0,
            bitSize = 16,
            mode = 'RW',
            base = pr.UInt,
            disp = '{:d}'))

        self.add(pr.RemoteVariable(
            name = 'MaxClkGap',
            offset = 0x08,
            bitOffset = 0,
            bitSize = 32,
            mode = 'RW',
            base = pr.UInt,
            disp = '{:d}'))
