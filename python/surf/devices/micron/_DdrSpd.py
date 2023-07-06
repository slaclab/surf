#-----------------------------------------------------------------------------
# Title      : PyRogue Lookup tool at www.micron.com/spd
#-----------------------------------------------------------------------------
# Description:
# PyRogue Lookup tool at www.micron.com/spd
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

class DdrSpd(pr.Device):
    def __init__(   self,
            description = "Lookup tool at www.micron.com/spd",
            nelms       = 0x100,
            instantiate = True,
            hidden      = True,
            **kwargs):
        super().__init__(description=description, hidden=hidden, **kwargs)

        if (instantiate):
            self.add(pr.RemoteVariable(
                name        = "Mem",
                description = "Memory Array",
                size        = (4*nelms),
                numValues   = nelms,
                valueBits   = 32,
                valueStride = 32,
                bitSize     = 32 * nelms,
                # mode      = "RO",
            ))

