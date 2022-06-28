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

class AxiStreamDmaV2Fifo(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.add(pr.RemoteVariable(
            name      ='Version',
            offset    = 0x00,
            bitSize   = 4,
            mode      = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name      ='AXI_BASE_ADDR_G',
            offset    = 0x04,
            bitSize   = 64,
            mode      ='RO',
        ))

        self.add(pr.RemoteVariable(
            name      ='AXI_CACHE_G',
            offset    = 0x0C,
            bitSize   = 4,
            bitOffset = 0,
            mode      ='RO',
            hidden    = True,
        ))

        self.add(pr.RemoteVariable(
            name      ='AXI_BURST_G',
            offset    = 0x0C,
            bitSize   = 2,
            bitOffset = 4,
            mode      ='RO',
            hidden    = True,
        ))

        self.add(pr.RemoteVariable(
            name      ='AXI_LEN_BITS_C',
            offset    = 0x10,
            bitSize   = 8,
            bitOffset = 0,
            mode      = 'RO',
            disp      = '{:d}',
            hidden    = True,
        ))

        self.add(pr.RemoteVariable(
            name      ='AXI_ID_BITS_C',
            offset    = 0x10,
            bitSize   = 8,
            bitOffset = 8,
            mode      = 'RO',
            disp      = '{:d}',
            hidden    = True,
        ))

        self.add(pr.RemoteVariable(
            name      ='AXI_DATA_BYTES_C',
            offset    = 0x10,
            bitSize   = 8,
            bitOffset = 16,
            mode      = 'RO',
            disp      = '{:d}',
            hidden    = True,
        ))

        self.add(pr.RemoteVariable(
            name      ='AXI_ADDR_WIDTH_C',
            offset    = 0x10,
            bitSize   = 8,
            bitOffset = 24,
            mode      = 'RO',
            disp      = '{:d}',
            hidden    = True,
        ))

        self.add(pr.RemoteVariable(
            name      ='AXIS_TDEST_BITS_C',
            offset    = 0x14,
            bitSize   = 8,
            bitOffset = 0,
            mode      = 'RO',
            disp      = '{:d}',
            hidden    = True,
        ))

        self.add(pr.RemoteVariable(
            name      ='AXIS_TID_BITS_C',
            offset    = 0x14,
            bitSize   = 8,
            bitOffset = 8,
            mode      = 'RO',
            disp      = '{:d}',
            hidden    = True,
        ))

        self.add(pr.RemoteVariable(
            name      ='AXIS_TUSER_BITS_C',
            offset    = 0x14,
            bitSize   = 8,
            bitOffset = 16,
            mode      = 'RO',
            disp      = '{:d}',
            hidden    = True,
        ))

        self.add(pr.RemoteVariable(
            name      ='AXIS_TDATA_BYTES_C',
            offset    = 0x14,
            bitSize   = 8,
            bitOffset = 24,
            mode      = 'RO',
            disp      = '{:d}',
            hidden    = True,
        ))

        self.add(pr.RemoteVariable(
            name      ='BUFF_FRAME_WIDTH_G',
            offset    = 0x18,
            bitSize   = 8,
            bitOffset = 0,
            mode      ='RO',
            disp      = '{:d}',
            hidden    = True,
        ))

        self.add(pr.RemoteVariable(
            name      ='AXI_BUFFER_WIDTH_G',
            offset    = 0x18,
            bitSize   = 8,
            bitOffset = 8,
            mode      ='RO',
            disp      = '{:d}',
            hidden    = True,
        ))

        self.add(pr.RemoteVariable(
            name      ='BURST_BYTES_G',
            offset    = 0x18,
            bitSize   = 8,
            bitOffset = 16,
            mode      ='RO',
            disp      = '{:d}',
            hidden    = True,
        ))

        self.add(pr.RemoteVariable(
            name         ='QueueBufferCnt',
            offset       = 0x1C,
            bitSize      = 16,
            bitOffset    = 0,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         ='FreeListBufferCnt',
            offset       = 0x1C,
            bitSize      = 16,
            bitOffset    = 16,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         ='FreeListPauseCnt',
            offset       = 0x20,
            bitSize      = 16,
            bitOffset    = 0,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         ='FreeListPause',
            offset       = 0x20,
            bitSize      = 1,
            bitOffset    = 16,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name      ='FreeListPauseThresh',
            offset    = 0x24,
            bitSize   = 16,
            mode      ='RW',
        ))

        self.add(pr.RemoteCommand(
            name        = 'CntRst',
            description = "Counter Reset",
            offset      = 0xFC,
            bitSize     = 1,
            function    = lambda cmd: cmd.post(1),
        ))

    def hardReset(self):
        self.CntRst()

    def initialize(self):
        self.CntRst()

    def countReset(self):
        self.CntRst()
