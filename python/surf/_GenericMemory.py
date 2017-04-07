#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Generic Memory Module
#-----------------------------------------------------------------------------
# File       : GenericMemory.py
# Created    : 2017-04-04
#-----------------------------------------------------------------------------
# Description:
# PyRogue Generic Memory Module
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

class GenericMemory(pr.Device):
    def __init__(   self, 
                    name        = "GenericMemory", 
                    description = "Generic Memory Module", 
                    memBase     =  None, 
                    offset      =  0x0, 
                    hidden      =  False, 
                    nelms       =  1, 
                    bitSize     =  32, 
                    bitOffset   =  0, 
                    base        = "hex", 
                    mode        = "RW", 
                    instantiate =  True):
        super(self.__class__, self).__init__(name, description, memBase, offset, hidden)

        ##############################
        # Variables
        ##############################
        
        if (instantiate):
            digits = len(str(abs(nelms-1))) 
            for i in range(nelms):
                self.add(pr.Variable(   name         = "Mem_%.*i" % (digits, i),
                                        description  = "Memory Array: Element %.*i" % (digits, i),
                                        offset       =  i * 0x04,
                                        bitSize      =  bitSize,
                                        bitOffset    =  bitOffset,
                                        base         =  base,
                                        mode         =  mode,
                                    ))