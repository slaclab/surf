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

class SspDecoder(pr.Device):
    def __init__(self, numberLanes=1, **kwargs):
        super().__init__(**kwargs)

        self.addRemoteVariables(
            name         = 'LockedCnt',
            offset       = 0*(numberLanes<<2),
            bitSize      = 16,
            mode         = 'RO',
            number       = numberLanes,
            stride       = 4,
            pollInterval = 1,
        )

        self.addRemoteVariables(
            name         = 'BitSlipCnt',
            offset       = 1*(numberLanes<<2),
            bitSize      = 16,
            mode         = 'RO',
            number       = numberLanes,
            stride       = 4,
            pollInterval = 1,
        )

        self.addRemoteVariables(
            name         = 'ErrorDetCnt',
            offset       = 2*(numberLanes<<2),
            bitSize      = 16,
            mode         = 'RO',
            number       = numberLanes,
            stride       = 4,
            pollInterval = 1,
        )

        self.add(pr.RemoteVariable(
            name         = 'Locked',
            offset       = 0x400,
            bitSize      = 2,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.addRemoteVariables(
            name         = 'DlyConfig',
            offset       = 0x600,
            bitSize      = 9,
            mode         = 'RO',
            number       = numberLanes,
            stride       = 4,
            pollInterval = 1,
        )

        self.add(pr.RemoteVariable(
            name         = 'DATA_WIDTH_G',
            offset       = 0x7FC,
            bitSize      = 8,
            bitOffset    = 0,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'NUM_LANE_G',
            offset       = 0x7FC,
            bitSize      = 8,
            bitOffset    = 8,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'EnUsrDlyCfg',
            description  = 'Enable User delay config',
            offset       = 0x800,
            bitSize      = 1,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'UsrDlyCfg',
            description  = 'User delay config',
            offset       = 0x804,
            bitSize      = 9,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MinEyeWidth',
            description  = 'Sets the minimum eye width required for locking (units of IDELAY step)',
            offset       = 0x808,
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LockingCntCfg',
            description  = 'Number of error-free event before state=LOCKED_S',
            offset       = 0x80C,
            bitSize      = 24,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'BypFirstBerDet',
            description  = 'Set to 0x1 if IDELAY full scale range > 2 Unit Intervals (UI) of serial rate (example: IDELAY range 2.5ns  > 1 ns (1Gb/s) )',
            offset       = 0x810,
            bitSize      = 1,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'Polarity',
            description  = '1: Invert diff pair, 0: Non-inverted diff pair',
            offset       = 0x814,
            bitSize      = numberLanes,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'RollOverEn',
            description  = 'Rollover enable for status counters',
            offset       = 0xFF8,
            bitSize      = 7,
            mode         = 'RW',
        ))

        self.add(pr.RemoteCommand(
            name         = 'CntRst',
            description  = 'Status counter reset',
            offset       = 0xFFC,
            bitSize      = 1,
            function     = lambda cmd: cmd.post(1),
            hidden       = False,
        ))

    def hardReset(self):
        self.CntRst()

    def softReset(self):
        self.CntRst()

    def countReset(self):
        self.CntRst()
