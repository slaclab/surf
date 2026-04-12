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

class AxiStreamDmaV2Desc(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)


        self.add(pr.RemoteVariable(
            name        = 'HwEnable',
            description = 'Hardware DMA enable status flag',
            mode        = 'RO',
            offset      = 0x0,
            bitOffset   = 0,
            bitSize     = 1,
        ))

        self.add(pr.RemoteVariable(
            name        = 'Version',
            description = 'DMA V2 descriptor IP core version number',
            mode        = 'RO',
            offset      = 0x0,
            bitOffset   = 24,
            bitSize     = 8,
        ))

        self.add(pr.RemoteVariable(
            name        = 'IntEnable',
            description = 'Interrupt enable flag for DMA completion events',
            mode        = 'RO',
            offset      = 0x4,
            bitOffset   = 0,
            bitSize     = 1,
        ))

        self.add(pr.RemoteVariable(
            name        = 'ContEn',
            description = 'Continuous mode enable: allow frames larger than one buffer to span multiple descriptors',
            mode        = 'RO',
            offset      = 0x8,
            bitOffset   = 0,
            bitSize     = 1,
        ))

        self.add(pr.RemoteVariable(
            name        = 'DropEn',
            description = 'Drop enable: discard incoming frame data without writing to memory',
            mode        = 'RO',
            offset      = 0xC,
            bitOffset   = 0,
            bitSize     = 1,
        ))

        self.add(pr.RemoteVariable(
            name        = 'WrBaseAddr',
            description = 'Base address of the write descriptor ring in memory',
            mode        = 'RO',
            offset      = 0x10,
            bitOffset   = 0,
            bitSize     = 64,
        ))

        self.add(pr.RemoteVariable(
            name        = 'RdBaseAddr',
            description = 'Base address of the read descriptor ring in memory',
            mode        = 'RO',
            offset      = 0x14,
            bitOffset   = 0,
            bitSize     = 64,
        ))

        self.add(pr.RemoteVariable(
            name        = 'FifoReset',
            description = 'Reset the internal descriptor FIFO',
            mode        = 'RO',
            offset      = 0x20,
            bitOffset   = 0,
            bitSize     = 1,
        ))
        self.add(pr.RemoteVariable(
            name        = 'BufBaseAddr',
            description = 'Base address of the DMA data buffer pool',
            mode        = 'RO',
            offset      = 0x24,
            bitOffset   = 0,
            bitSize     = 32,
        ))

        self.add(pr.RemoteVariable(
            name        = 'MaxSize',
            description = 'Maximum DMA buffer size in bytes',
            mode        = 'RO',
            offset      = 0x28,
            bitOffset   = 0,
            bitSize     = 24,
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        = 'Online',
            description = 'DMA engine online status',
            mode        = 'RO',
            offset      = 0x2C,
            bitOffset   = 0,
            bitSize     = 1,
        ))

        self.add(pr.RemoteVariable(
            name        = 'Acknowledge',
            description = 'DMA descriptor acknowledge flag',
            mode        = 'RO',
            offset      = 0x30,
            bitOffset   = 0,
            bitSize     = 1,
        ))

        self.add(pr.RemoteVariable(
            name        = 'ChanCount',
            description = 'Number of DMA channels supported by this instance',
            mode        = 'RO',
            offset      = 0x34,
            bitOffset   = 0,
            bitSize     = 8,
        ))

        self.add(pr.RemoteVariable(
            name        = 'DescAwidth',
            description = 'Address width of the descriptor ring memory',
            mode        = 'RO',
            offset      = 0x38,
            bitOffset   = 0,
            bitSize     = 8,
        ))

        self.add(pr.RemoteVariable(
            name        = 'DescCache',
            description = 'AXI cache attribute for descriptor read/write transactions',
            mode        = 'RO',
            offset      = 0x3C,
            bitOffset   = 0,
            bitSize     = 4,
        ))
        self.add(pr.RemoteVariable(
            name        = 'BuffCache',
            description = 'AXI cache attribute for data buffer read/write transactions',
            mode        = 'RO',
            offset      = 0x3C,
            bitOffset   = 8,
            bitSize     = 4,
        ))

        self.add(pr.RemoteVariable(
            name        = 'FifoDin',
            description = 'Data input value written to the descriptor FIFO',
            mode        = 'RO',
            offset      = 0x40,
            bitOffset   = 0,
            bitSize     = 32,
        ))

        self.add(pr.RemoteVariable(
            name        = 'IntAckCount',
            description = 'Number of interrupt acknowledgements issued',
            mode        = 'RO',
            offset      = 0x4C,
            bitOffset   = 0,
            bitSize     = 16,
        ))

        self.add(pr.RemoteVariable(
            name        = 'IntEnableDup',
            description = 'Duplicate interrupt enable status bit',
            mode        = 'RO',
            offset      = 0x4C,
            bitOffset   = 17,
            bitSize     = 1,
        ))

        self.add(pr.RemoteVariable(
            name        = 'IntReqCount',
            description = 'Number of interrupt requests generated by the DMA engine',
            mode        = 'RO',
            offset      = 0x50,
            bitOffset   = 0,
            bitSize     = 32,
        ))

        self.add(pr.RemoteVariable(
            name        = 'WrIndex',
            description = 'Current write descriptor ring index',
            mode        = 'RO',
            offset      = 0x54,
            bitOffset   = 0,
            bitSize     = 32,
        ))
        self.add(pr.RemoteVariable(
            name        = 'RdIndex',
            description = 'Current read descriptor ring index',
            mode        = 'RO',
            offset      = 0x58,
            bitOffset   = 0,
            bitSize     = 32,
        ))

        self.add(pr.RemoteVariable(
            name        = 'WrReqMissed',
            description = 'Number of write requests missed due to full descriptor ring',
            mode        = 'RO',
            offset      = 0x5C,
            bitOffset   = 0,
            bitSize     = 32,
        ))
