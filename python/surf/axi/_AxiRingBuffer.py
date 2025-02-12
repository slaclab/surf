#-----------------------------------------------------------------------------
# Title      : PyRogue AXI-Lite Ring Buffer Module
#-----------------------------------------------------------------------------
# Description:
# PyRogue AXI-Lite Ring Buffer Module
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

class AxiRingBuffer(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.add(pr.RemoteVariable(
            name         = 'AXI_BASE_ADDR_G',
            description  = 'AXI_BASE_ADDR_G generic',
            offset       = 0x00,
            bitSize      = 64,
            bitOffset    = 0,
            mode         = 'RO',
            units        = 'Bytes',
        ))

        self.add(pr.RemoteVariable(
            name         = 'DATA_BYTES_G',
            description  = 'DATA_BYTES_G generic',
            offset       = 0x08,
            bitSize      = 8,
            bitOffset    = 0,
            mode         = 'RO',
            units        = 'Bytes',
            disp         = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name         = 'BURST_BYTES_G',
            description  = 'BURST_BYTES_G generic',
            offset       = 0x08,
            bitSize      = 16,
            bitOffset    = 8,
            units        = 'Bytes',
            disp         = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name         = 'RING_BUFF_ADDR_WIDTH_G',
            description  = 'RING_BUFF_ADDR_WIDTH_G generic',
            offset       = 0x08,
            bitSize      = 8,
            bitOffset    = 24,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'DATA_BITSIZE_C',
            description  = 'DATA_BITSIZE_C constant',
            offset       = 0x0C,
            bitSize      = 8,
            bitOffset    = 0,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'BURST_BITSIZE_C',
            description  = 'BURST_BITSIZE_C constant',
            offset       = 0x0C,
            bitSize      = 8,
            bitOffset    = 8,
            mode         = 'RO',
            disp         = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MEM_BITSIZE_C',
            description  = 'MEM_BITSIZE_C constant',
            offset       = 0x0C,
            bitSize      = 8,
            bitOffset    = 16,
            mode         = 'RO',
            disp         = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name         = 'ReadoutCnt',
            description  = 'current value of the readouts',
            offset       = 0x10,
            bitSize      = 32,
            bitOffset    = 0,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'DropTrigCnt',
            description  = 'Increments anytime a trigger is dropped',
            offset       = 0x14,
            bitSize      = 8,
            bitOffset    = 0,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'WrErrCnt',
            description  = 'Increments anytime a write error happens due to back pressure',
            offset       = 0x18,
            bitSize      = 8,
            bitOffset    = 0,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'EnableMode',
            description  = 'Sets whether the ring buffer is enabled or not',
            offset       = 0x80,
            bitSize      = 1,
            bitOffset    = 0,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'ContinuousMode',
            description  = 'Sets local triggering into continuous trigger mode',
            offset       = 0x84,
            bitSize      = 1,
            bitOffset    = 0,
            mode         = 'RW',
        ))

        self.add(pr.RemoteCommand(
            name         = 'SoftTrig',
            description  = 'Software trigging ring buffer',
            offset       = 0xF8,
            bitSize      = 1,
            bitOffset    = 0,
            function     = lambda cmd: cmd.post(1),
        ))

        self.add(pr.RemoteCommand(
            name         = 'CntRst',
            description  = 'Reset the status counters',
            offset       = 0xFC,
            bitSize      = 1,
            bitOffset    = 0,
            function     = lambda cmd: cmd.post(1),
        ))
