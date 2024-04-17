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
            name        = 'SuperFrameByteThreshold',
            description = 'Sets the number of max superframe byte threshold before terminating the superframe.  Set to zero to bypass this feature',
            offset      = 0x00,
            bitSize     = 32,
            mode        = 'RW',
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MaxSubFrames',
            description = 'Sets the number of max subframes before terminating the superframe.  Set to zero to bypass this feature',
            offset      = 0x04,
            bitSize     = 16,
            mode        = 'RW',
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        = 'MaxClkGap',
            description = 'Sets the number of clock cycles between subframes before terminating the superframe.  Set to zero to bypass this feature',
            offset      = 0x08,
            bitSize     = 32,
            mode        = 'RW',
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name         = "Idle",
            description  = "Current state of the batcher if it is IDLE",
            offset       =  0x0C,
            bitSize      =  1,
            mode         = "RO",
            base         = pr.Bool,
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name        = 'Blowoff',
            description = 'Blows off the inbound AXIS stream (for debugging)',
            offset      = 0xF8,
            bitSize     = 1,
            base        = pr.Bool,
            mode        = 'RW',
        ))

        self.add(pr.RemoteCommand(
            name        = 'SoftRst',
            description = 'Used to reset the batcher FSM',
            offset      = 0xFC,
            bitSize     = 1,
            function    = pr.BaseCommand.toggle,
        ))
