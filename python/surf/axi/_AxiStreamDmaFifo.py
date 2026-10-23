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
            name        ='Version',
            description = 'DMA FIFO IP core version number',
            offset      = 0x00,
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        ='Online',
            description = 'Enable DMA engine operation',
            offset      = 0x00,
            bitSize     = 1,
            bitOffset   = 4,
            mode        ='RW',
        ))

        self.add(pr.RemoteVariable(
            name        ='DropOnErr',
            description = 'Drop frames with errors instead of passing them',
            offset      = 0x00,
            bitSize     = 1,
            bitOffset   = 5,
            mode        ='RW',
        ))

        self.add(pr.RemoteVariable(
            name        ='InsertSof',
            description = 'Insert start-of-frame marker into outgoing data stream',
            offset      = 0x00,
            bitSize     = 1,
            bitOffset   = 6,
            mode        ='RW',
        ))

        self.add(pr.RemoteVariable(
            name        ='START_AFTER_RST_G',
            description = 'Generic: automatically come online after reset',
            offset      = 0x00,
            bitSize     = 1,
            bitOffset   = 8,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        ='DROP_ERR_FRAME_G',
            description = 'Generic: drop errored frames at firmware level',
            offset      = 0x00,
            bitSize     = 1,
            bitOffset   = 9,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        ='SOF_INSERT_G',
            description = 'Generic: SOF insertion enabled in firmware build',
            offset      = 0x00,
            bitSize     = 1,
            bitOffset   = 10,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        ='AXI_CACHE_G',
            description = 'Generic: AXI cache attribute value used in firmware build',
            offset      = 0x00,
            bitSize     = 4,
            bitOffset   = 12,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        ='SwCache',
            description = 'Software-configurable AXI cache attribute for DMA transactions',
            offset      = 0x00,
            bitSize     = 4,
            bitOffset   = 16,
            mode        ='RW',
        ))

        self.add(pr.RemoteVariable(
            name        ='AXI_BURST_G',
            description = 'Generic: AXI burst type used in firmware build',
            offset      = 0x00,
            bitSize     = 2,
            bitOffset   = 20,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        ='MaxSize',
            description = 'Maximum DMA transfer size in bytes',
            offset      = 0x04,
            bitSize     = 32,
            bitOffset   = 0,
            mode        ='RW',
        ))

        self.add(pr.RemoteVariable(
            name        ='BaseAddr',
            description = 'Base memory address for the DMA FIFO buffer',
            offset      = 0x20,
            bitSize     = 64,
            bitOffset   = 0,
            mode        ='RW',
        ))

        self.add(pr.RemoteVariable(
            name        ='AXIS_TDEST_BITS_C',
            description = 'Number of AXI-Stream TDEST bits in firmware build',
            offset      = 0xC0,
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        ='AXIS_TID_BITS_C',
            description = 'Number of AXI-Stream TID bits in firmware build',
            offset      = 0xC0,
            bitSize     = 8,
            bitOffset   = 8,
            mode        = 'RO',
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        ='AXIS_TUSER_BITS_C',
            description = 'Number of AXI-Stream TUSER bits in firmware build',
            offset      = 0xC0,
            bitSize     = 8,
            bitOffset   = 16,
            mode        = 'RO',
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        ='AXIS_TDATA_BYTES_C',
            description = 'Number of AXI-Stream TDATA bytes in firmware build',
            offset      = 0xC0,
            bitSize     = 8,
            bitOffset   = 24,
            mode        = 'RO',
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        ='AXI_LEN_BITS_C',
            description = 'Number of AXI burst length bits in firmware build',
            offset      = 0xC4,
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        ='AXI_ID_BITS_C',
            description = 'Number of AXI ID bits in firmware build',
            offset      = 0xC4,
            bitSize     = 8,
            bitOffset   = 8,
            mode        = 'RO',
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        ='AXI_DATA_BYTES_C',
            description = 'Number of AXI data bytes per beat in firmware build',
            offset      = 0xC4,
            bitSize     = 8,
            bitOffset   = 16,
            mode        = 'RO',
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        ='AXI_ADDR_WIDTH_C',
            description = 'AXI address bus width in bits',
            offset      = 0xC4,
            bitSize     = 8,
            bitOffset   = 24,
            mode        = 'RO',
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        ='MAX_FRAME_WIDTH_G',
            description = 'Generic: log2 of maximum frame size in bytes',
            offset      = 0xC8,
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        ='AXI_BUFFER_WIDTH_G',
            description = 'Generic: log2 of total AXI buffer size in bytes',
            offset      = 0xC8,
            bitSize     = 8,
            bitOffset   = 8,
            mode        = 'RO',
            disp        = '{:d}',
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
            description  = 'Number of frames transferred by the DMA engine',
            offset       = 0x40,
            bitSize      = 32,
            bitOffset    = 0,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         ='FrameCntMax',
            description  = 'Maximum number of in-flight frames observed',
            offset       = 0x84,
            bitSize      = 32,
            bitOffset    = 0,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         ='ErrorCnt',
            description  = 'Number of DMA frame errors detected',
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
