#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue AMC Carrier core's Non-volatile memory (100k endurance)
#-----------------------------------------------------------------------------
# File       : Axi24LC64FT.py
# Created    : 2017-04-03
#-----------------------------------------------------------------------------
# Description:
# PyRogue AMC Carrier core's Non-volatile memory (100k endurance)
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

from surf.misc._GenericMemory import *

class Axi24LC64FT(pr.Device):
    def __init__(self,       
            name        = "Axi24LC64FT",
            description = "Axi24LC64FT",
            nelms       =  0x800,
            instantiate =  True,
            **kwargs):
        super().__init__(name=name, description=description, **kwargs) 

        ##############################
        # Variables
        ##############################
        self.add(GenericMemory(
                                offset      = 0x00,
                                nelms       = nelms,
                                instantiate = instantiate,
                              ))