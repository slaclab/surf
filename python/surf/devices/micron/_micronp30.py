#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue _micronp30 Module
#-----------------------------------------------------------------------------
# File       : _micronp30.py
# Created    : 2017-01-17
# Last update: 2017-01-17
#-----------------------------------------------------------------------------
# Description:
# PyRogue _micronp30 Module
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

class MicronP30(pr.Device):
    def __init__(self, name="MicronP30", memBase=None, offset=0, hidden=False):
        super(self.__class__, self).__init__(name, "MicronP30 Module",
                                             memBase, offset, hidden)
                                             
        self.add(pr.Variable(name='dataReg',description='dataReg',
                offset=0x00, bitSize=16, bitOffset=0, base='hex', mode='RW', hidden=True)) 
              
        self.add(pr.Variable(name='addrReg',description='addrReg',
                offset=0x04, bitSize=32, bitOffset=0, base='hex', mode='RW', hidden=True))                 

        self.add(pr.Variable(name='readReg',description='readReg',
                offset=0x08, bitSize=16, bitOffset=0, base='hex', mode='RO', hidden=True))     

        self.add(pr.Variable(name='test',description='test',
                offset=0x0C, bitSize=32, bitOffset=0, base='hex', mode='RW', hidden=False))          
           
                