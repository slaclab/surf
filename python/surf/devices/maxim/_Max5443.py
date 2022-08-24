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

class Max5443(pr.Device):
    def __init__(self, numChip=1, **kwargs):
        super().__init__(**kwargs)

        for i in range(numChip):
            self.add(pr.RemoteVariable(
                name    = f'Dac[{i}]',
                offset  = i*0x4,
                bitSize = 16,
                mode    = 'RW',
            ))

            self.add(pr.LinkVariable(
                name         = f'VDac[{i}]',
                linkedGet    = self.convtFloat,
                dependencies = [self.Dac[i]],
            ))

    @staticmethod
    def convtFloat(dev, var):
        value   = var.dependencies[0].get(read=False)
        fpValue = value*(3.0/65536.0)
        return '%0.3f'%(fpValue)
