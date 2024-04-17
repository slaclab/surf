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

class TmrManager(pr.Device):
    def __init__(
            self,
            description = 'Xilinx TMR Manager registers (refer to PG268 v1.0, page 43 - 50)',
            **kwargs):
        super().__init__(description=description, **kwargs)

        self.add(pr.RemoteVariable(
            name         = 'CR',
            description  = 'Control Register',
            offset       = 0x00,
            bitSize      = 20,
            bitOffset    = 0,
            mode         = 'WO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'FFR',
            description  = 'First Failing Register',
            offset       = 0x04,
            bitSize      = 22,
            bitOffset    = 0,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'CMR0',
            description  = 'Comparison Mask Register 0',
            offset       = 0x08,
            bitSize      = 32,
            bitOffset    = 0,
            mode         = 'WO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'CMR1',
            description  = 'Comparison Mask Register 1',
            offset       = 0x0C,
            bitSize      = 32,
            bitOffset    = 0,
            mode         = 'WO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'BDIR',
            description  = 'Break Delay Initialization Register',
            offset       = 0x10,
            bitSize      = 32,
            bitOffset    = 0,
            mode         = 'WO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'SEMSR',
            description  = 'SEM Status Register',
            offset       = 0x14,
            bitSize      = 11,
            bitOffset    = 0,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'SEMSSR',
            description  = 'SEM Sticky Status Register',
            offset       = 0x18,
            bitSize      = 11,
            bitOffset    = 0,
            mode         = 'RW',
            verify       = False, # Cleared by writing 1 to the bit.
        ))

        self.add(pr.RemoteVariable(
            name         = 'SEMIMR',
            description  = 'SEM Interrupt Mask Register',
            offset       = 0x1C,
            bitSize      = 11,
            bitOffset    = 0,
            mode         = 'WO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'WR',
            description  = 'Watchdog Register',
            offset       = 0x20,
            bitSize      = 32,
            bitOffset    = 0,
            mode         = 'WO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'RFSR',
            description  = 'Reset Failing State Register',
            offset       = 0x24,
            bitSize      = 32,
            bitOffset    = 0,
            mode         = 'WO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'CSCR',
            description  = 'Comparator Status Clear Register',
            offset       = 0x28,
            bitSize      = 32,
            bitOffset    = 0,
            mode         = 'WO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'CFIR',
            description  = 'Comparator Fault Inject Register',
            offset       = 0x2C,
            bitSize      = 4,
            bitOffset    = 0,
            mode         = 'WO',
        ))
