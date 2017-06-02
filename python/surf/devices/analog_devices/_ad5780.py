#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue _ad5780 Module
#-----------------------------------------------------------------------------
# File       : _ad5780.py
# Created    : 2017-01-17
# Last update: 2017-01-17
#-----------------------------------------------------------------------------
# Description:
# PyRogue _ad5780 Module
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

class Ad5780(pr.Device):
    def __init__(self, name="Ad5780", memBase=None, offset=0, hidden=False):
        super(self.__class__, self).__init__(name, "Ad5780 Module",
                                             memBase, offset, hidden)
                                             
        self.add(pr.Variable(name='dacRefreshRate',
                description='DAC Rate (in units of Hz)',
                offset=0x040, bitSize=32, bitOffset=0, base='uint', mode='RO'))

        self.add(pr.Variable(name='dacData',
                description='DAC Data',
                offset=0x0C0, bitSize=18, bitOffset=0, base='hex', mode='RO')) 

        self.add(pr.Variable(name='debugMux',
                description='debugMux',
                offset=0x200, bitSize=1, bitOffset=0, base='bool', mode='RW'))                 

        self.add(pr.Variable(name='debugData',
                description='debugData',
                offset=0x240, bitSize=18, bitOffset=0, base='hex', mode='RW'))                 
                
        self.add(pr.Variable(name='sdoDisable',
                description='sdoDisable',
                offset=0x280, bitSize=1, bitOffset=0, base='bool', mode='RW')) 
                
        self.add(pr.Variable(name='binaryOffset',
                description='binaryOffset',
                offset=0x284, bitSize=1, bitOffset=0, base='bool', mode='RW'))  
                
        self.add(pr.Variable(name='dacTriState',
                description='dacTriState',
                offset=0x288, bitSize=1, bitOffset=0, base='bool', mode='RW')) 
                
        self.add(pr.Variable(name='opGnd',
                description='opGnd',
                offset=0x28C, bitSize=1, bitOffset=0, base='bool', mode='RW'))   
                
        self.add(pr.Variable(name='rbuf',
                description='rbuf',
                offset=0x290, bitSize=1, bitOffset=0, base='bool', mode='RW'))                   
                
        self.add(pr.Variable(name='halfSckPeriod',
                description='halfSckPeriod',
                offset=0x294, bitSize=32, bitOffset=0, base='hex', mode='RW'))                
                
        self.add(pr.Variable(name='hardReset',description='HardReset',
                offset=0x3F8, bitSize=1, bitOffset=0, base='hex', mode='WO', hidden=False)) 
                