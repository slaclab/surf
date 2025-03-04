##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

import pyrogue as pr

class Sy89297(pr.Device):
    def __init__( self, **kwargs):
        super().__init__(**kwargs)

        self.add(pr.RemoteVariable(
            name         = 'DelayA',
            description  = 'Delay Channel A',
            offset       = 0x0,
            bitSize      = 10,
            mode         = 'RW',
            units        = '5ps/step',
        ))

        self.add(pr.RemoteVariable(
            name         = 'DelayB',
            description  = 'Delay Channel B',
            offset       = 0x4,
            bitSize      = 10,
            mode         = 'RW',
            units        = '5ps/step',
        ))

        self.add(pr.RemoteVariable(
            name         = 'SckHalfPeriod',
            offset       = 0xC,
            bitSize      = 8,
            mode         = 'RW',
            hidden       = True,
        ))

    def setDelay(self, delayA=None, delayB=None):
        if delayA is not None:
            if self.DelayB.value() != delayA:
                self.DelayA.set(delayA)

        if delayB is not None:
            if self.DelayB.value() != delayB:
                self.DelayB.set(delayB)
