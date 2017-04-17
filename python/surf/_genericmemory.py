#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue _genericmemory Module
#-----------------------------------------------------------------------------
# File       : _genericmemory.py
# Created    : 2016-12-06
# Last update: 2016-12-06
#-----------------------------------------------------------------------------
# Description:
# PyRogue _genericmemory Module
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

class GenericMemory(pr.Device):
    def __init__(self, name="Mem", 
        elements=1, bitSize=32, bitOffset=0, base='hex', mode='RW',
        memBase=None, offset=0, hidden=False):
        super(self.__class__, self).__init__(name, "genericmemory module",
                                             memBase, offset, hidden)
        digits = len(str(abs(elements-1)))        
        for i in range(elements):
            self.add(pr.Variable(name='Mem_%.*i'%(digits, i), description='Mem_%.*i'%(digits, i),
                offset=(i*0x4), bitSize=bitSize, bitOffset=bitOffset, base=base, mode=mode))
