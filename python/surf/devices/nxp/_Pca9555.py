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

class Pca9555(pr.Device):
    def __init__(self,
            description = "Container for Pca9555",
            pollInterval = 1,
            **kwargs):
        super().__init__(description=description, **kwargs)

        self.addRemoteVariables(
            name         = 'IP',
            description  = 'Input Port registers',
            offset       = (0x0 << 2),
            bitSize      = 8,
            mode         = 'RO',
            number       = 2,
            stride       = 4,
            pollInterval = pollInterval,
        )

        self.addRemoteVariables(
            name         = 'OP',
            description  = 'Output Port registers',
            offset       = (0x2 << 2),
            bitSize      = 8,
            mode         = 'RW',
            number       = 2,
            stride       = 4,
        )

        self.addRemoteVariables(
            name         = 'PI',
            description  = 'Polarity Inversion registers',
            offset       = (0x4 << 2),
            bitSize      = 8,
            mode         = 'RW',
            number       = 2,
            stride       = 4,
        )

        self.addRemoteVariables(
            name         = 'IOC',
            description  = 'I/O Configuration registers',
            offset       = (0x6 << 2),
            bitSize      = 8,
            mode         = 'RW',
            number       = 2,
            stride       = 4,
        )
