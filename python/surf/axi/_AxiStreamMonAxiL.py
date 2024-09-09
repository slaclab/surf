#-----------------------------------------------------------------------------
# Title      : PyRogue AXI-Lite Version Module
#-----------------------------------------------------------------------------
# Description:
# PyRogue AXI-Lite Version Module
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

class AxiStreamMonChannel(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        def addPair(name, offset, bitSize, units, bitOffset, description, function, pollInterval=0):
            self.add(pr.RemoteVariable(
                name         = ("Raw"+name),
                offset       = offset,
                bitSize      = bitSize,
                bitOffset    = bitOffset,
                base         = pr.UInt,
                mode         = 'RO',
                description  = description,
                pollInterval = pollInterval,
                hidden       = True,
            ))
            self.add(pr.LinkVariable(
                name         = name,
                mode         = 'RO',
                units        = units,
                linkedGet    = function,
                disp         = '{:1.1f}',
                dependencies = [self.variables["Raw"+name]],
            ))

        self.add(pr.RemoteVariable(
            name         = 'FrameCnt',
            description  = 'Increments every time a tValid + tLast + tReady detected',
            offset       = 0x04,
            bitSize      = 64,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'FrameRate',
            description  = "Current Frame Rate",
            offset       = 0x0C,
            bitSize      = 32,
            bitOffset    = 0,
            mode         = "RO",
            base         = pr.Int,
            units        = 'Hz',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'FrameRateMax',
            description  = "Max Frame Rate",
            offset       = 0x10,
            bitSize      = 32,
            bitOffset    = 0,
            mode         = "RO",
            base         = pr.Int,
            units        = 'Hz',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'FrameRateMin',
            description  = "Min Frame Rate",
            offset       = 0x14,
            bitSize      = 32,
            bitOffset    = 0,
            mode         = "RO",
            base         = pr.Int,
            units        = 'Hz',
            pollInterval = 1,
        ))

        addPair(
            name         = 'Bandwidth',
            description  = "Current Bandwidth",
            offset       = 0x18,
            bitSize      = 64,
            bitOffset    = 0,
            function     = self.convMbps,
            units        = 'Mbps',
            pollInterval = 1,
        )

        addPair(
            name         = 'BandwidthMax',
            description  = "Max Bandwidth",
            offset       = 0x20,
            bitSize      = 64,
            bitOffset    = 0,
            function     = self.convMbps,
            units        = 'Mbps',
            pollInterval = 1,
        )

        addPair(
            name         = 'BandwidthMin',
            description  = "Min Bandwidth",
            offset       = 0x28,
            bitSize      = 64,
            bitOffset    = 0,
            function     = self.convMbps,
            units        = 'Mbps',
            pollInterval = 1,
        )

        self.add(pr.RemoteVariable(
            name         = 'FrameSize',
            description  = 'Current Frame Size. Note: Only valid for non-interleaved AXI stream frames',
            offset       = 0x30,
            bitSize      = 32,
            bitOffset    = 0,
            mode         = 'RO',
            base         = pr.Int,
            units        = 'Byte',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'FrameSizeMax',
            description  = 'Max Frame Size. Note: Only valid for non-interleaved AXI stream frames',
            offset       = 0x34,
            bitSize      = 32,
            bitOffset    = 0,
            mode         = 'RO',
            base         = pr.Int,
            units        = 'Byte',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'FrameSizeMin',
            description  = 'Min Frame Size. Note: Only valid for non-interleaved AXI stream frames',
            offset       = 0x38,
            bitSize      = 32,
            bitOffset    = 0,
            mode         = 'RO',
            base         = pr.Int,
            units        = 'Byte',
            pollInterval = 1,
        ))

    @staticmethod
    def convMbps(var, read):
        return var.dependencies[0].get(read=read) * 8e-6

class AxiStreamMonAxiL(pr.Device):
    def __init__(self, numberLanes=1, hideConfig=True, chName=None, **kwargs):
        super().__init__(**kwargs)

        self.add(pr.RemoteCommand(
            name         = 'CntRst',
            description  = "Counter Reset",
            offset       = 0x0,
            bitSize      = 1,
            function     = lambda cmd: cmd.post(1),
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'AXIS_CONFIG_G_TDATA_BYTES_C',
            offset       = 0x0,
            bitSize      = 8,
            bitOffset    = 24,
            mode         = 'RO',
            disp         = '{:d}',
            overlapEn    = True,
            hidden       = hideConfig,
        ))

        self.add(pr.RemoteVariable(
            name         = 'AXIS_CONFIG_G_TDEST_BITS_C',
            offset       = 0x0,
            bitSize      = 4,
            bitOffset    = 20,
            mode         = 'RO',
            disp         = '{:d}',
            overlapEn    = True,
            hidden       = hideConfig,
        ))

        self.add(pr.RemoteVariable(
            name         = 'AXIS_CONFIG_G_TUSER_BITS_C',
            offset       = 0x0,
            bitSize      = 4,
            bitOffset    = 16,
            mode         = 'RO',
            disp         = '{:d}',
            overlapEn    = True,
            hidden       = hideConfig,
        ))

        self.add(pr.RemoteVariable(
            name         = 'AXIS_CONFIG_G_TID_BITS_C',
            offset       = 0x0,
            bitSize      = 4,
            bitOffset    = 12,
            mode         = 'RO',
            overlapEn    = True,
            hidden       = hideConfig,
        ))

        self.add(pr.RemoteVariable(
            name         = 'AXIS_CONFIG_G_TKEEP_MODE_C',
            offset       = 0x0,
            bitSize      = 4,
            bitOffset    = 8,
            mode         = 'RO',
            enum        = {
                0x0: 'TKEEP_NORMAL_C',
                0x1: 'TKEEP_COMP_C',
                0x2: 'TKEEP_FIXED_C',
                0x3: 'TKEEP_COUNT_C',
                0xF: 'UNDEFINED',
            },
            overlapEn    = True,
            hidden       = hideConfig,
        ))

        self.add(pr.RemoteVariable(
            name         = 'AXIS_CONFIG_G_TUSER_MODE_C',
            offset       = 0x0,
            bitSize      = 4,
            bitOffset    = 4,
            mode         = 'RO',
            enum        = {
                0x0: 'TUSER_NORMAL_C',
                0x1: 'TUSER_FIRST_LAST_C',
                0x2: 'TUSER_LAST_C',
                0x3: 'TUSER_NONE_C',
                0xF: 'UNDEFINED',
            },
            overlapEn    = True,
            hidden       = hideConfig,
        ))

        self.add(pr.RemoteVariable(
            name         = 'AXIS_CONFIG_G_TSTRB_EN_C',
            offset       = 0x0,
            bitSize      = 1,
            bitOffset    = 1,
            mode         = 'RO',
            base         = pr.Bool,
            overlapEn    = True,
            hidden       = hideConfig,
        ))

        self.add(pr.RemoteVariable(
            name         = 'COMMON_CLK_G',
            offset       = 0x0,
            bitSize      = 1,
            bitOffset    = 0,
            mode         = 'RO',
            base         = pr.Bool,
            overlapEn    = True,
            hidden       = hideConfig,
        ))

        if chName is None:
            self.chName = [f'Ch[{i}]' for i in range(numberLanes)]
        else:
            self.chName = chName

        for i in range(numberLanes):
            self.add(AxiStreamMonChannel(
                name        = self.chName[i],
                offset      = (i*0x40),
                expand      = True,
            ))

    def hardReset(self):
        self.CntRst()

    def initialize(self):
        self.CntRst()

    def countReset(self):
        self.CntRst()

class AxiStreamMonitoring(AxiStreamMonAxiL):
    def __init__(self, numberLanes=1, **kwargs):

        super().__init__(
            numberLanes = numberLanes,
            **kwargs)

        print( f'{self.path}: AxiStreamMonitoring device is now deprecated. Please use AxiStreamMonAxiL instead' )
