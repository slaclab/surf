#-----------------------------------------------------------------------------
# This file is part of 'SLAC Firmware Standard Library'.
# It is subject to the license terms in the LICENSE.txt file found in the
# top-level directory of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of 'SLAC Firmware Standard Library', including this file,
# may be copied, modified, propagated, or distributed except according to
# the terms contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr

class SugoiAxiL(pr.Device):
    def __init__(self,**kwargs):
        super().__init__(**kwargs)

        statusCntSize = 16

        self.add(pr.RemoteVariable(
            name         = 'DisableClk',
            offset       = 0x00,
            bitSize      = 1,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'DisableTx',
            offset       = 0x04,
            bitSize      = 1,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'TxPolarity',
            offset       = 0x08,
            bitSize      = 1,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'RxPolarity',
            offset       = 0x0C,
            bitSize      = 1,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'BypFirstBerDet',
            description  = 'Set to 0x1 if IDELAY full scale range > 2 Unit Intervals (UI) of serial rate (example: IDELAY range 2.5ns  > 1 ns (1Gb/s) )',
            offset       = 0x10,
            bitSize      = 1,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'EnUsrDlyCfg',
            description  = 'Enable User delay config',
            offset       = 0x14,
            bitSize      = 1,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'UsrDlyCfg',
            offset       = 0x18,
            bitSize      = 9,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LockingCntCfg',
            description  = 'Number of error-free event before state=LOCKED_S',
            offset       = 0x1C,
            bitSize      = 24,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MinEyeWidth',
            description  = 'Sets the minimum eye width required for locking (units of IDELAY step)',
            offset       = 0x20,
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'TimerConfig',
            description  = 'Sets the communication timeout between sending REQ message to receiving ACK message back',
            offset       = 0x24,
            bitSize      = 24,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'GlobalRst',
            description  = 'Software global reset (active HIGH)',
            offset       = 0x28,
            bitSize      = 1,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'TrigOpCode',
            description  = 'Software Trigger OP-code bus',
            offset       = 0x2C,
            bitSize      = 8,
            mode         = 'WO',
        ))

        self.addRemoteVariables(
            name         = 'DropTrigOpCodeCnt',
            description  = 'Increments if unable to transmit the OP-cde control word',
            offset       = 0x80,
            bitSize      = statusCntSize,
            mode         = 'RO',
            number       = 8,
            stride       = 4,
            pollInterval = 1,
        )

        self.add(pr.RemoteVariable(
            name         = 'ErrorDetCnt',
            description  = 'Increment when 8B10B error detected',
            offset       = 0xA0,
            bitSize      = statusCntSize,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'LinkUpCnt',
            description  = 'Increment when link goes up',
            offset       = 0xA4,
            bitSize      = statusCntSize,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'Latency',
            description  = 'Round trip SOF control word latency (units of timingClk cycles)',
            offset       = 0xA8,
            bitSize      = statusCntSize,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'EyeWidth',
            description  = 'Measured eye width after locking completed',
            offset       = 0xAC,
            bitSize      = 9,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'LinkUp',
            description  = 'High when the gearbox alignment is completed',
            offset       = 0xB0,
            bitSize      = 1,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteCommand(
            name         = 'CountReset',
            description  = 'Status counter reset',
            offset       = 0xFC,
            bitSize      = 1,
            function     = pr.BaseCommand.touchOne
        ))

    def countReset(self):
        self.CountReset()
