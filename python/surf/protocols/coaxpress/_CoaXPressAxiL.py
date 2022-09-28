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
        )

        self.addRemoteVariables(
            name         = 'RxDispErrCnt',
            offset       = 0x080,
            bitSize      = statusCountBits,
            mode         = 'RO',
            number       = numLane,
            stride       = 4,
            pollInterval = 1,
        )

        for i in range(numLane):

            self.add(pr.RemoteVariable(
                name         = f'RxClockFreqRaw[{i}]',
                offset       = (0x0C0+4*i),
                bitSize      = 32,
                mode         = 'RO',
                hidden       = True,
                pollInterval = 1,
            ))

            self.add(pr.LinkVariable(
                name         = f'RxClockFrequency[{i}]',
                units        = "MHz",
                mode         = 'RO',
                dependencies = [self.RxClockFreqRaw[i]],
                linkedGet    = lambda: self.RxClockFreqRaw[i].value() * 1.0e-6,
                disp         = '{:0.3f}',
            ))


        self.add(pr.RemoteVariable(
            name         = "TrigRate",
            description  = "Trigger Rate",
            offset       = 0x800,
            mode         = 'RO',
            units        = 'Hz',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'RxLinkUp',
            offset       = 0x804,
            bitSize      = numLane,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TxLinkUp',
            offset       = 0x808,
            bitSize      = 1,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = "TxClockFreqRaw",
            offset       = 0x80C,
            bitSize      = 32,
            mode         = 'RO',
            hidden       = True,
            pollInterval = 1,
        ))

        self.add(pr.LinkVariable(
            name         = "TxClockFrequency",
            units        = "MHz",
            mode         = 'RO',
            dependencies = [self.TxClockFreqRaw],
            linkedGet    = lambda: self.TxClockFreqRaw.value() * 1.0e-6,
            disp         = '{:0.3f}',
        ))


        self.add(pr.RemoteVariable(
            name         = 'TxLinkUpCnt',
            offset       = 0x810,
            bitSize      = statusCountBits,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TrigAckCnt',
            offset       = 0x814,
            bitSize      = statusCountBits,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TxTrigCnt',
            offset       = 0x818,
            bitSize      = statusCountBits,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TxTrigDropCnt',
            offset       = 0x81C,
            bitSize      = statusCountBits,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'RxOverflowCnt',
            offset       = 0x820,
            bitSize      = statusCountBits,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(axi.AxiStreamMonChannel(
            name   = 'DataSteamMon',
            offset = 0x900, # 0x900:0x93F
        ))

        self.add(pr.RemoteVariable(
            name         = 'NUM_LANES_G',
            offset       = 0xFE0,
            bitSize      = 8,
            bitOffset    = 0,
            disp         = '{:d}',
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'STATUS_CNT_WIDTH_G',
            offset       = 0xFE0,
            bitSize      = 8,
            bitOffset    = 8,
            disp         = '{:d}',
            mode         = 'RO',
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
            linkedGet    = lambda: (float(self.TrigPulseWidthRaw.value()+1) * 0.0032),
            linkedSet    = lambda value, write: self.TrigPulseWidthRaw.set(int(value/0.0032)-1),
        ))

        self.add(pr.RemoteCommand(
            name     = 'SoftwareTrig',
            offset   = 0xFF0,
            bitSize  = 1,
            function = lambda cmd: cmd.post(1),
        ))

        self.add(pr.RemoteVariable(
            name         = 'ConfigTimerSize',
            offset       = 0xFF4,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'RxNumberOfLane',
            description  = 'Number of active RX lanes (zero inclusive)',
            offset       = 0xFF8,
            bitSize      = 3,
            bitOffset    = 0,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'TxTrigInv',
            offset       = 0xFF8,
            bitSize      = 1,
            bitOffset    = 24,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'ConfigErrResp',
            offset       = 0xFF8,
            bitSize      = 1,
            bitOffset    = 25,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'ConfigPktTag',
            offset       = 0xFF8,
            bitSize      = 1,
            bitOffset    = 26,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'TxLsRate',
            offset       = 0xFF8,
            bitSize      = 1,
            bitOffset    = 27,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'TxLsLaneEnable',
            offset       = 0xFF8,
            bitSize      = 4,
            bitOffset    = 28,
            mode         = 'RW',
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
