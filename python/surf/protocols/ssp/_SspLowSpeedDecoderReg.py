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

class SspLowSpeedDecoderReg(pr.Device):
    def __init__(self, numberLanes=1, **kwargs):
        super().__init__(**kwargs)

        self.addRemoteVariables(
            name         = 'LockedCnt',
            description  = 'status count that increases per locked detection event',
            offset       = 0*(numberLanes<<2),
            bitSize      = 16,
            mode         = 'RO',
            number       = numberLanes,
            stride       = 4,
            pollInterval = 1,
        )

        self.addRemoteVariables(
            name         = 'BitSlipCnt',
            description  = 'status count that increases per bitslip detection event',
            offset       = 1*(numberLanes<<2),
            bitSize      = 16,
            mode         = 'RO',
            number       = numberLanes,
            stride       = 4,
            pollInterval = 1,
        )

        self.addRemoteVariables(
            name         = 'ErrorDetCnt',
            description  = 'status count that increases per error detection event',
            offset       = 2*(numberLanes<<2),
            bitSize      = 16,
            mode         = 'RO',
            number       = numberLanes,
            stride       = 4,
            pollInterval = 1,
        )

        self.addRemoteVariables(
            name         = 'EyeWidth',
            description  = 'Measured eye width after locking completed',
            offset       = 0x200,
            bitSize      = 9,
            mode         = 'RO',
            number       = numberLanes,
            stride       = 4,
            pollInterval = 1,
        )

        self.add(pr.RemoteVariable(
            name         = 'Locked',
            description  = 'auto aligner locked status',
            offset       = 0x400,
            bitSize      = numberLanes,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.addRemoteVariables(
            name         = 'UsrDlyCfg',
            description  = 'manual user delay value when EnUsrDlyCfg = 0x1',
            offset       = 0x500,
            bitSize      = 9,
            mode         = 'RW',
            number       = numberLanes,
            stride       = 4,
        )

        self.addRemoteVariables(
            name         = 'DlyConfig',
            description  = 'Current IDELAY value',
            offset       = 0x600,
            bitSize      = 9,
            mode         = 'RO',
            number       = numberLanes,
            stride       = 4,
            pollInterval = 1,
        )

        self.add(pr.RemoteVariable(
            name         = 'DATA_WIDTH_G',
            description  = 'DATA_WIDTH_G VHDL genenic value',
            offset       = 0x7FC,
            bitSize      = 8,
            bitOffset    = 0,
            mode         = 'RO',
            disp         = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name         = 'NUM_LANE_G',
            description  = 'NUM_LANE_G VHDL genenic value',
            offset       = 0x7FC,
            bitSize      = 8,
            bitOffset    = 8,
            mode         = 'RO',
            disp         = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name         = 'EnUsrDlyCfg',
            description  = 'Enables User delay config (UsrDlyCfg)',
            offset       = 0x800,
            bitSize      = 1,
            mode         = 'RW',
        ))

#####################################
# Changed from "common" to 1 per lane
#####################################
#        self.add(pr.RemoteVariable(
#            name         = 'UsrDlyCfg',
#            description  = 'User delay config',
#            offset       = 0x804,
#            bitSize      = 9,
#            mode         = 'RW',
#        ))

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
            name         = 'GearboxSlaveBitOrder',
            description  = '1: reverse gearbox input bit ordering, 0: normal bit ordering',
            offset       = 0x818,
            bitSize      = 1,
            bitOffset    = 0,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'GearboxMasterBitOrder',
            description  = '1: reverse gearbox output bit ordering, 0: normal',
            offset       = 0x818,
            bitSize      = 1,
            bitOffset    = 1,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MaskOffCodeErr',
            description  = '1: Mask off codeErr (debug only) , 0: normal operation',
            offset       = 0x81C,
            bitSize      = 1,
            bitOffset    = 0,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MaskOffDispErr',
            description  = '1: Mask off dsispErr (debug only) , 0: normal operation',
            offset       = 0x81C,
            bitSize      = 1,
            bitOffset    = 1,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MaskOffOutOfSync',
            description  = '1: Mask off OutOfSync (debug only) , 0: normal operation',
            offset       = 0x81C,
            bitSize      = 1,
            bitOffset    = 2,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'IdleCode',
            description  = 'IDLE code detected (1 bit per lane)',
            offset       = 0x900,
            bitSize      = numberLanes,
            mode         = 'RO',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'LockOnIdleOnly',
            description  = '1: requires only IDLE code during the lock up procedure then any any code link is locked , 0: any code for locking',
            offset       = 0x904,
            bitSize      = 1,
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
