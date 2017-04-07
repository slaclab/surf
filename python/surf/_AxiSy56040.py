#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue AXI-Lite Microchip SY56040 and Microchip SY58040
#-----------------------------------------------------------------------------
# File       : AxiSy56040.py
# Created    : 2017-04-04
#-----------------------------------------------------------------------------
# Description:
# PyRogue AXI-Lite Microchip SY56040 and Microchip SY58040
#-----------------------------------------------------------------------------
# This file is part of the rogue software platform. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the rogue software platform, including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr

class AxiSy56040(pr.Device):
    def __init__(self, name="AxiSy56040", description="AXI-Lite Microchip SY56040 and Microchip SY58040", memBase=None, offset=0x0, hidden=False):
        super(self.__class__, self).__init__(name, description, memBase, offset, hidden)

        ##############################
        # Variables
        ##############################

        for i in range(4):
            self.add(pr.Variable(   name         = "OutputConfig_%i" % (i),
                                    description  = "Output Configuration Register Array %i" % (i),
                                    offset       =  0x00 + (i * 0x04),
                                    bitSize      =  2,
                                    bitOffset    =  0x00,
                                    base         = "hex",
                                    mode         = "RW",
                                ))

