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

class TmrInject(pr.Device):
    def __init__(
            self,
            description = 'Xilinx TMR Inject registers (refer to PG268 v1.0, page 50 - 52)',
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
            name         = 'AIR',
            description  = 'Address Inject Register',
            offset       = 0x04,
            bitSize      = 32,
            bitOffset    = 0,
            mode         = 'WO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'IIR',
            description  = 'Instruction Inject Register',
            offset       = 0x08,
            bitSize      = 32,
            bitOffset    = 0,
            mode         = 'WO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'EAIR',
            description  = 'Extended Address Inject Register',
            offset       = 0x10,
            bitSize      = 64,
            bitOffset    = 0,
            mode         = 'WO',
        ))
