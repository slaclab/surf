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
        super().__init__(**kwargs)

        ##############################
        # Devices
        ##############################
        self.add(silabs.Si5345Page1(offset=(0x100<<2),simpleDisplay=simpleDisplay,expand=False,hidden=advanceUser))
        self.add(silabs.Si5345Page2(offset=(0x200<<2),simpleDisplay=simpleDisplay,expand=False,hidden=advanceUser))
        self.add(silabs.Si5345Page3(offset=(0x300<<2),simpleDisplay=simpleDisplay,expand=False,hidden=advanceUser))
        self.add(silabs.Si5345Page4(offset=(0x400<<2),simpleDisplay=simpleDisplay,expand=False,hidden=advanceUser))
        self.add(silabs.Si5345Page5(offset=(0x500<<2),simpleDisplay=simpleDisplay,expand=False,hidden=advanceUser))
        self.add(silabs.Si5345Page9(offset=(0x900<<2),simpleDisplay=simpleDisplay,expand=False,hidden=advanceUser))
        self.add(silabs.Si5345PageA(offset=(0xA00<<2),simpleDisplay=simpleDisplay,expand=False,hidden=advanceUser))
        self.add(silabs.Si5345PageB(offset=(0xB00<<2),simpleDisplay=simpleDisplay,expand=False,hidden=advanceUser))
