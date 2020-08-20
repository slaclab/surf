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

class Pca9506(pr.Device):
    def __init__(self,
            description = "Container for Pca9505/Pca9506",
            pollInterval = 1,
            **kwargs):
        super().__init__(description=description, **kwargs)

        self.addRemoteVariables(
            name         = 'IP',
            description  = 'Input Port registers',
            offset       = (0x00 << 2),
            bitSize      = 8,
            mode         = 'RO',
            number       = 5,
            stride       = 4,
            pollInterval = pollInterval,
        )

        self.addRemoteVariables(
            name         = 'OP',
            description  = 'Output Port registers',
            offset       = (0x08 << 2),
            bitSize      = 8,
            mode         = 'RW',
            number       = 5,
            stride       = 4,
        )

        self.addRemoteVariables(
            name         = 'PI',
            description  = 'Polarity Inversion registers',
            offset       = (0x10 << 2),
            bitSize      = 8,
            mode         = 'RW',
            number       = 5,
            stride       = 4,
        )

        self.addRemoteVariables(
            name         = 'IOC',
            description  = 'I/O Configuration registers',
            offset       = (0x18 << 2),
            bitSize      = 8,
            mode         = 'RW',
            number       = 5,
            stride       = 4,
        )

        self.addRemoteVariables(
            name         = 'MSK',
            description  = 'Mask Interrupt register',
            offset       = (0x20 << 2),
            bitSize      = 8,
            mode         = 'RW',
            number       = 5,
            stride       = 4,
        )
