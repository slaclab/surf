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

class DdrSpd(pr.Device):
    def __init__(   self, 
            name        = "DdrSpd", 
            description = "Lookup tool at www.micron.com/spd", 
            nelms       =  0x100, 
            instantiate =  True,
            **kwargs):
        super().__init__(name=name, description=description, **kwargs)         

        ##############################
        # Variables
        ##############################
        if (instantiate):
            pr.MemoryDevice(
                name        = "Mem",
                description = "Memory Array",        
                size        = (4*nelms),
                # nelms     = nelms,
                # mode      = "RO",
                wordBitSize = 8,
                # bitSize   = 8,
            )        
