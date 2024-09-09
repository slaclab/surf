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

class AxiStreamDmaFifo(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.add(pr.RemoteVariable(
            name      ='Version',
            offset    = 0x00,
            bitSize   = 4,
            bitOffset = 0,
            mode      = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name      ='Online',
            offset    = 0x00,
            bitSize   = 1,
            bitOffset = 4,
            mode      ='RW',
        ))

        self.add(pr.RemoteVariable(
            name      ='DropOnErr',
            offset    = 0x00,
            bitSize   = 1,
            bitOffset = 5,
            mode      ='RW',
        ))

        self.add(pr.RemoteVariable(
            name      ='InsertSof',
            offset    = 0x00,
            bitSize   = 1,
            bitOffset = 6,
            mode      ='RW',
        ))

        self.add(pr.RemoteVariable(
            name      ='START_AFTER_RST_G',
            offset    = 0x00,
            bitSize   = 1,
            bitOffset = 8,
            mode      = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name      ='DROP_ERR_FRAME_G',
            offset    = 0x00,
            bitSize   = 1,
            bitOffset = 9,
            mode      = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name      ='SOF_INSERT_G',
            offset    = 0x00,
            bitSize   = 1,
            bitOffset = 10,
            mode      = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name      ='AXI_CACHE_G',
            offset    = 0x00,
            bitSize   = 4,
            bitOffset = 12,
            mode      = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name      ='SwCache',
            offset    = 0x00,
            bitSize   = 4,
            bitOffset = 16,
            mode      ='RW',
        ))

        self.add(pr.RemoteVariable(
            name      ='AXI_BURST_G',
            offset    = 0x00,
            bitSize   = 2,
            bitOffset = 20,
            mode      = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name      ='MaxSize',
            offset    = 0x04,
            bitSize   = 32,
            bitOffset = 0,
            mode      ='RW',
        ))

        self.add(pr.RemoteVariable(
            name      ='BaseAddr',
            offset    = 0x20,
            bitSize   = 64,
            bitOffset = 0,
            mode      ='RW',
        ))

        self.add(pr.RemoteVariable(
            name      ='AXIS_TDEST_BITS_C',
            offset    = 0xC0,
            bitSize   = 8,
            bitOffset = 0,
            mode      = 'RO',
            disp      = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name      ='AXIS_TID_BITS_C',
            offset    = 0xC0,
            bitSize   = 8,
            bitOffset = 8,
            mode      = 'RO',
            disp      = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name      ='AXIS_TUSER_BITS_C',
            offset    = 0xC0,
            bitSize   = 8,
            bitOffset = 16,
            mode      = 'RO',
            disp      = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name      ='AXIS_TDATA_BYTES_C',
            offset    = 0xC0,
            bitSize   = 8,
            bitOffset = 24,
            mode      = 'RO',
            disp      = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name      ='AXI_LEN_BITS_C',
            offset    = 0xC4,
            bitSize   = 8,
            bitOffset = 0,
            mode      = 'RO',
            disp      = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name      ='AXI_ID_BITS_C',
            offset    = 0xC4,
            bitSize   = 8,
            bitOffset = 8,
            mode      = 'RO',
            disp      = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name      ='AXI_DATA_BYTES_C',
            offset    = 0xC4,
            bitSize   = 8,
            bitOffset = 16,
            mode      = 'RO',
            disp      = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name      ='AXI_ADDR_WIDTH_C',
            offset    = 0xC4,
            bitSize   = 8,
            bitOffset = 24,
            mode      = 'RO',
            disp      = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name      ='MAX_FRAME_WIDTH_G',
            offset    = 0xC8,
            bitSize   = 8,
            bitOffset = 0,
            mode      = 'RO',
            disp      = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name      ='AXI_BUFFER_WIDTH_G',
            offset    = 0xC8,
            bitSize   = 8,
            bitOffset = 8,
            mode      = 'RO',
            disp      = '{:d}',
        ))

        self.add(pr.LinkVariable(
            name         = 'NUM_BUFFERS',
            description  = 'Number of buffers',
            mode         = 'RO',
            disp         = '0x{:0x}',
            dependencies = [self.AXI_BUFFER_WIDTH_G,self.MAX_FRAME_WIDTH_G],
            linkedGet    = lambda read: 2**( int(self.AXI_BUFFER_WIDTH_G.get(read=read)) - int(self.MAX_FRAME_WIDTH_G.get(read=read)) )
        ))

        self.add(pr.RemoteVariable(
            name         ='FrameCnt',
            offset       = 0x40,
            bitSize      = 32,
            bitOffset    = 0,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         ='FrameCntMax',
            offset       = 0x84,
            bitSize      = 32,
            bitOffset    = 0,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         ='ErrorCnt',
            offset       = 0x80,
            bitSize      = 32,
            bitOffset    = 0,
            mode         = 'RO',
            pollInterval = 1,
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
