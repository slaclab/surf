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

class Sc18Is602(pr.Device):
    def __init__(self,**kwargs):
        super().__init__(**kwargs)

        self.add(pr.RemoteVariable(
            name        = 'ORDER',
            description = 'When logic 0, the MSB of the data word is transmitted first. If logic 1, the LSB of the data word is transmitted first.',
            offset      = (0xF0 << 2),
            bitSize     = 1,
            bitOffset   = 5,
            mode        = 'WO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'CPOL',
            description = 'CPOL determines the polarity of the clock. The polarities can be converted with a simple inverter.',
            offset      = (0xF0 << 2),
            bitSize     = 1,
            bitOffset   = 3,
            mode        = 'WO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'CPHA',
            description = 'CPHA determines the timing (i.e. phase) of the data bits relative to the clock pulses. Conversion between these two forms is non-trivial.',
            offset      = (0xF0 << 2),
            bitSize     = 1,
            bitOffset   = 2,
            mode        = 'WO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'SpiClockRate',
            description = 'Sets the SPI clock rate',
            offset      = (0xF0 << 2),
            bitSize     = 2,
            bitOffset   = 0,
            mode        = 'WO',
            enum      = {
                0: "1843kHz",
                1: "461kHz",
                2: "115kHz",
                3: "58kHz",
            },
        ))
