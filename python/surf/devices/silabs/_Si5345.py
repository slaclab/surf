#-----------------------------------------------------------------------------
# This file is part of 'SLAC Firmware Standard Library'.
# It is subject to the license terms in the LICENSE.txt file found in the
# top-level directory of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of 'SLAC Firmware Standard Library', including this file,
# may be copied, modified, propagated, or distributed except according to
# the terms contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import surf.devices.silabs as silabs

class Si5345(silabs.Si5345Lite):
    def __init__(
            self,
            simpleDisplay = True,
            advanceUser   = False,
            **kwargs):
        super().__init__(simpleDisplay=simpleDisplay,advanceUser=advanceUser,liteVersion=False,**kwargs)
