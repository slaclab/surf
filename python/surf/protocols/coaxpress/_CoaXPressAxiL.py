#-----------------------------------------------------------------------------
# This file is part of 'SLAC Firmware Standard Library'.
# It is subject to the license terms in the LICENSE.txt file found in the
# top-level directory of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of 'SLAC Firmware Standard Library', including this file,
# may be copied, modified, propagated, or distributed except according to
# the terms contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue  as pr
import surf.axi as axi

class CoaXPressAxiL(pr.Device):
    def __init__(   self,
            numLane         = 1,
            statusCountBits = 12,
            **kwargs):
        super().__init__(**kwargs)

        self.addRemoteVariables(
            name         = 'RxLinkUpCnt',
            offset       = 0x000,
            bitSize      = statusCountBits,
            mode         = 'RO',
            number       = numLane,
            stride       = 4,
            pollInterval = 1,
        )

        self.addRemoteVariables(
            name         = 'RxDecErrCnt',
            offset       = 0x040,
            bitSize      = statusCountBits,
            mode         = 'RO',
            number       = numLane,
            stride       = 4,
            pollInterval = 1,
            hidden       = True,
        )

        self.addRemoteVariables(
            name         = 'RxDispErrCnt',
            offset       = 0x080,
            bitSize      = statusCountBits,
            mode         = 'RO',
            number       = numLane,
            stride       = 4,
            pollInterval = 1,
            hidden       = True,
        )

        for i in range(numLane):

            self.add(pr.RemoteVariable(
                name         = f'RxClockFreqRaw[{i}]',
                description  = f'Raw RX clock frequency counter for lane {i}',
                offset       = (0x0C0+4*i),
                bitSize      = 32,
                mode         = 'RO',
                hidden       = True,
                pollInterval = 1,
            ))

            self.add(pr.LinkVariable(
                name         = f'RxClockFrequency[{i}]',
                description  = f'RX clock frequency for lane {i}',
                units        = "MHz",
                mode         = 'RO',
                dependencies = [self.RxClockFreqRaw[i]],
                linkedGet    = lambda read, x=self.RxClockFreqRaw[i]: x.get(read=read) * 1.0e-6,
                disp         = '{:0.3f}',
                hidden       = True,
            ))


        self.add(pr.RemoteVariable(
            name         = "TrigRate",
            description  = "Trigger Rate",
            offset       = 0x800,
            mode         = 'RO',
            units        = 'Hz',
            disp         = '{:d}',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'RxLinkUp',
            description  = 'RX link up status bitmask (one bit per lane)',
            offset       = 0x804,
            bitSize      = numLane,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TxLinkUp',
            description  = 'TX link up status',
            offset       = 0x808,
            bitSize      = 1,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "TxClockFreqRaw",
            description  = "Raw TX clock frequency counter",
            offset       = 0x80C,
            bitSize      = 32,
            mode         = 'RO',
            hidden       = True,
            pollInterval = 1,
        ))

        self.add(pr.LinkVariable(
            name         = "TxClockFrequency",
            description  = "TX clock frequency",
            units        = "MHz",
            mode         = 'RO',
            dependencies = [self.TxClockFreqRaw],
            linkedGet    = lambda read: self.TxClockFreqRaw.get(read=read) * 1.0e-6,
            disp         = '{:0.3f}',
            hidden       = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TxLinkUpCnt',
            description  = 'TX link up event counter',
            offset       = 0x810,
            bitSize      = statusCountBits,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TrigAckCnt',
            description  = 'Trigger acknowledgment counter',
            offset       = 0x814,
            bitSize      = statusCountBits,
            mode         = 'RO',
            pollInterval = 1,
            hidden       = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TxTrigCnt',
            description  = 'Transmitted trigger packet counter',
            offset       = 0x818,
            bitSize      = statusCountBits,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TxTrigDropCnt',
            description  = 'Dropped trigger packet counter',
            offset       = 0x81C,
            bitSize      = statusCountBits,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'RxOverflowCnt',
            description  = 'RX FIFO overflow counter',
            offset       = 0x820,
            bitSize      = statusCountBits,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'RxFsmErrorCnt',
            description  = 'RX FSM error counter',
            offset       = 0x824,
            bitSize      = statusCountBits,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(axi.AxiStreamMonChannel(
            name   = 'DataSteamMon',
            offset = 0x900, # 0x900:0x93F
            expand = True,
        ))

        self.add(pr.RemoteVariable(
            name         = "GtRstAll",
            description  = "Used to reset the GTs",
            offset       = 0xFDC,
            bitSize      = 1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = 'NUM_LANES_G',
            description  = 'Generic: number of CoaXPress lanes',
            offset       = 0xFE0,
            bitSize      = 8,
            bitOffset    = 0,
            disp         = '{:d}',
            mode         = 'RO',
            hidden       = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'STATUS_CNT_WIDTH_G',
            description  = 'Generic: status counter bit width',
            offset       = 0xFE0,
            bitSize      = 8,
            bitOffset    = 8,
            disp         = '{:d}',
            mode         = 'RO',
            hidden       = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'RX_FSM_CNT_WIDTH_G',
            description  = 'Generic: RX FSM counter bit width',
            offset       = 0xFE0,
            bitSize      = 8,
            bitOffset    = 16,
            disp         = '{:d}',
            mode         = 'RO',
            hidden       = True,
        ))

        self.add(pr.RemoteCommand(
            name        = 'RxFsmRst',
            description = 'Reset the RX lane FSM and flush elastic buffers',
            offset      = 0xFE8,
            bitSize     = 1,
            function    = lambda cmd: cmd.post(1),
        ))

        self.add(pr.RemoteVariable(
            name         = "TrigPulseWidthRaw",
            description  = "Sets the CXP trigger pulse width",
            offset       = 0xFEC,
            bitSize      = 32,
            mode         = "RW",
            units        = '1/312.5MHz',
            hidden       = True,
        ))

        self.add(pr.LinkVariable(
            name         = 'TrigPulseWidth',
            description  = 'Sets the CXP trigger pulse width (in units of microseconds)',
            mode         = 'RW',
            units        = '\u03BCs',
            disp         = '{:0.3f}',
            dependencies = [self.TrigPulseWidthRaw],
            linkedGet    = lambda read: (float(self.TrigPulseWidthRaw.get(read=read)+1) * 0.0032),
            linkedSet    = lambda value, write: self.TrigPulseWidthRaw.set(int(value/0.0032)-1, write=write),
        ))

        self.add(pr.RemoteCommand(
            name        = 'SoftwareTrig',
            description = 'Issue a software-generated CoaXPress trigger',
            offset      = 0xFF0,
            bitSize     = 1,
            function    = lambda cmd: cmd.post(1),
        ))

        self.add(pr.RemoteVariable(
            name         = 'ConfigTimerSize',
            description  = 'Configuration packet inter-frame timer size',
            offset       = 0xFF4,
            mode         = 'RW',
            hidden       = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'RxNumberOfLane',
            description  = 'Number of active RX lanes',
            offset       = 0xFF8,
            bitSize      = 4,
            bitOffset    = 0,
            mode         = 'RW',
            disp         = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name         = 'TxTrigInv',
            description  = 'Invert TX trigger polarity',
            offset       = 0xFF8,
            bitSize      = 1,
            bitOffset    = 24,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'ConfigErrResp',
            description  = 'Enable AXI error response on configuration packet errors',
            offset       = 0xFF8,
            bitSize      = 1,
            bitOffset    = 25,
            mode         = 'RW',
            hidden       = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'ConfigPktTag',
            description  = 'Enable tag insertion in configuration packets',
            offset       = 0xFF8,
            bitSize      = 1,
            bitOffset    = 26,
            mode         = 'RW',
            hidden       = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TxLsRate',
            description  = 'TX low-speed upconnection rate select (0=20.83Mb/s, 1=41.66Mb/s)',
            offset       = 0xFF8,
            bitSize      = 1,
            bitOffset    = 27,
            mode         = 'RW',
            hidden       = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TxLsLaneEnable',
            description  = 'TX low-speed upconnection lane enable bitmask',
            offset       = 0xFF8,
            bitSize      = 4,
            bitOffset    = 28,
            mode         = 'RW',
            hidden       = True,
        ))

        self.add(pr.RemoteCommand(
            name         = 'CountReset',
            description  = 'Status counter reset',
            offset       = 0xFFC,
            bitSize      = 1,
            function     = pr.BaseCommand.touchOne
        ))

    def countReset(self):
        self.CountReset()
