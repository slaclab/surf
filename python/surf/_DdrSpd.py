#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Lookup tool at www.micron.com/spd
#-----------------------------------------------------------------------------
# File       : DdrSpd.py
# Created    : 2017-04-03
#-----------------------------------------------------------------------------
# Description:
# PyRogue Lookup tool at www.micron.com/spd
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

from surf._GenericMemory import *

class DdrSpd(pr.Device):
    def __init__(   self, 
                    name="DdrSpd", 
                    description="Lookup tool at www.micron.com/spd", 
                    memBase=None, 
                    offset=0x0, 
                    hidden=False, 
                    nelms = 0x100, 
                    instantiate=True):
        super(self.__class__, self).__init__(name, description, memBase, offset, hidden)

        ##############################
        # Variables
        ##############################
        if (instantiate):
            digits = len(str(abs(nelms-1))) 
            for i in range(nelms): 
                self.add(GenericMemory(
                                        name         = "GenericMemory_%.*i" % (digits, i), 
                                        description  = "Generic Memory Array: Element %.*i" % (digits, i),
                                        offset       =  i * 0x04,
                                        bitSize      =  8,
                                        mode         = "RO"
                                    ))