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


class CoaXPressOverFiberBridgeAxiL(pr.Device):
    def __init__(self,
                 statusCountBits = 16,
                 **kwargs):
        super().__init__(**kwargs)

        rxErrorCodeEnum = {
            0x0: 'None',
            0x1: 'SeqMismatch',
            0x2: 'IdleError',
            0x3: 'PayloadAbort',
            0x4: 'BadControl',
            0x5: 'Overwrite',
            0x6: 'HkpMalformed',
            0x7: 'HkpBadKCode',
        }

        hkpTypeEnum = {
            0x0: 'None',
            0x1: 'KCode',
            0x2: 'SOP',
            0x3: 'EOP',
            0x4: 'Trigger',
            0x5: 'IoAck',
            0x6: 'Marker',
            0xF: 'Invalid',
        }

        statusBits = [
            ('RxError', 'Bridge RX error pulse'),
            ('RxAbort', 'Bridge RX abort pulse'),
            ('SeqValid', 'Received CXPoF /Q/ sequence ordered set'),
            ('SeqError', 'CXPoF /Q/ sequence mismatch'),
            ('HkpValid', 'Received CXPoF HKP word'),
            ('HkpError', 'Malformed CXPoF HKP word'),
        ]

        for bit, (name, description) in enumerate(statusBits):
            self.add(pr.RemoteVariable(
                name         = f'{name}Sticky',
                description  = f'Sticky status bit: {description}',
                offset       = 0x000,
                bitSize      = 1,
                bitOffset    = bit,
                mode         = 'RO',
                base         = pr.Bool,
                pollInterval = 1,
            ))

        self.add(pr.RemoteVariable(
            name         = 'RxErrorCode',
            description  = 'Last bridge RX error cause code',
            offset       = 0x004,
            bitSize      = 4,
            mode         = 'RO',
            enum         = rxErrorCodeEnum,
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'SeqData',
            description  = 'Last received CXPoF /Q/ sequence value',
            offset       = 0x008,
            bitSize      = 24,
            mode         = 'RO',
            disp         = '0x{:06X}',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'SeqExpected',
            description  = 'Next expected CXPoF /Q/ sequence value',
            offset       = 0x00C,
            bitSize      = 24,
            mode         = 'RO',
            disp         = '0x{:06X}',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'SeqErrorExpected',
            description  = 'Expected CXPoF /Q/ sequence value captured on mismatch',
            offset       = 0x010,
            bitSize      = 24,
            mode         = 'RO',
            disp         = '0x{:06X}',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'HkpData',
            description  = 'Last received CXPoF High-Speed K-Code Payload word',
            offset       = 0x014,
            bitSize      = 32,
            mode         = 'RO',
            disp         = '0x{:08X}',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'HkpWordCount',
            description  = 'Word count of the last received CXPoF HKP word',
            offset       = 0x018,
            bitSize      = 8,
            bitOffset    = 0,
            mode         = 'RO',
            disp         = '{:d}',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'HkpKCodeMask',
            description  = 'Per-byte CXP K-code mask for the last received HKP word',
            offset       = 0x018,
            bitSize      = 4,
            bitOffset    = 8,
            mode         = 'RO',
            disp         = '0x{:X}',
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'HkpKCodeValid',
            description  = 'True when every byte of the last received HKP word is a CXP K-code',
            offset       = 0x018,
            bitSize      = 1,
            bitOffset    = 12,
            mode         = 'RO',
            base         = pr.Bool,
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'HkpType',
            description  = 'Classified type of the last received HKP K-code word',
            offset       = 0x018,
            bitSize      = 4,
            bitOffset    = 16,
            mode         = 'RO',
            enum         = hkpTypeEnum,
            pollInterval = 1,
        ))

        for i, (name, description) in enumerate(statusBits):
            self.add(pr.RemoteVariable(
                name         = f'{name}Cnt',
                description  = f'Counter for {description}',
                offset       = 0x020 + (4*i),
                bitSize      = statusCountBits,
                mode         = 'RO',
                disp         = '{:d}',
                pollInterval = 1,
            ))

        self.add(pr.RemoteCommand(
            name        = 'CountReset',
            description = 'Reset bridge RX sticky status and counters',
            offset      = 0x03C,
            bitSize     = 1,
            function    = pr.BaseCommand.touchOne,
        ))

    def countReset(self):
        self.CountReset()
