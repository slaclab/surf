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

class AxiStreamFrameRateLimiter(pr.Device):
    def __init__(self,**kwargs):
        super().__init__(**kwargs)

        self.add(pr.RemoteVariable(
            name         = 'AXIS_CLK_FREQ_G',
            offset       = 0x000,
            bitSize      = 32,
            mode         = 'RO',
            disp         = '{:d}',
            units        = 'Hz',
        ))

        self.add(pr.RemoteVariable(
            name         = 'REFRESH_RATE_G',
            offset       = 0x004,
            bitSize      = 32,
            mode         = 'RO',
            disp         = '{:d}',
            units        = 'Hz',
        ))

        self.add(pr.RemoteVariable(
            name         = 'DEFAULT_MAX_RATE_G',
            offset       = 0x008,
            bitSize      = 32,
            mode         = 'RO',
            disp         = '{:d}',
            units        = 'REFRESH_RATE_G',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MaxFrameRate',
            description  = 'Sets the Frame Rate limit (in units of Units of \'REFRESH_RATE_G\').  Zero value means no limit',
            offset       =  0x100,
            bitSize      =  32,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'BackpressureMode',
            description  = '1: Assert back pressure when rate throttling, 0: Drop frames when rate throttling',
            offset       =  0x104,
            bitSize      =  1,
            mode         = 'RW',
        ))
