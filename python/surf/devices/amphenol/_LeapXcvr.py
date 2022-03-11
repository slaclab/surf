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

import surf.devices.amphenol as amphenol

class LeapXcvr(pr.Device):
    def __init__(self, writeEn=False, **kwargs):
        super().__init__(**kwargs)

        self.add(pr.LocalVariable(
            name         = "WriteEn",
            mode         = "RO",
            value        = writeEn,
        ))

        self.add(pr.RemoteVariable(
            name        = 'HardwareReset',
            offset      = 0x000,
            bitSize     = 1,
            mode        = 'RW',
        ))

        self.add(amphenol.LeapXcvrLowerPage(
            name    = 'RxLower',
            isTx    = False,
            writeEn = writeEn,
            offset  = 0x000,
        ))

        self.add(amphenol.LeapXcvrUpperRxPage01(
            name    = 'RxUpperPage01',
            offset  = 0x400,
        ))

        self.add(amphenol.LeapXcvrLowerPage(
            name    = 'TxLower',
            isTx    = True,
            writeEn = writeEn,
            offset  = 0x800,
        ))

        self.add(amphenol.LeapXcvrUpperPage00(
            name    = 'TxRxUpperPage00',
            offset  = 0x800,
        ))
