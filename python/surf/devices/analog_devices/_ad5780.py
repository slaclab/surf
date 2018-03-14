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
    def __init__(self,       
            name        = "Ad5780",
            description = "Ad5780",
            **kwargs):
        super().__init__(name=name, description=description, **kwargs)
                                             
        self.add(pr.RemoteVariable(
            name        = 'dacRefreshRate',
            description = 'DAC Rate (in units of Hz)',
            offset      = 0x040,
            bitSize     = 32,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'dacData',
            description = 'DAC Data',
            offset      = 0x0C0,
            bitSize     = 18,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RO',
        )) 

        self.add(pr.RemoteVariable(
            name        = 'debugMux',
            description = 'debugMux',
            offset      = 0x200,
            bitSize     = 1,
            bitOffset   = 0,
            base        = pr.Bool,
            mode        = 'RW',
        ))
        
        self.add(pr.RemoteVariable(
            name        = 'debugData',
            description = 'debugData',
            offset      = 0x240,
            bitSize     = 18,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))                 
                
        self.add(pr.RemoteVariable(
            name        = 'sdoDisable',
            description = 'sdoDisable',
            offset      = 0x280,
            bitSize     = 1,
            bitOffset   = 0,
            base        = pr.Bool,
            mode        = 'RW',
        )) 
                
        self.add(pr.RemoteVariable(
            name        = 'binaryOffset',
            description = 'binaryOffset',
            offset      = 0x284,
            bitSize     = 1,
            bitOffset   = 0,
            base        = pr.Bool,
            mode        = 'RW',
        ))  
                
        self.add(pr.RemoteVariable(
            name        = 'dacTriState',
            description = 'dacTriState',
            offset      = 0x288,
            bitSize     = 1,
            bitOffset   = 0,
            base        = pr.Bool,
            mode        = 'RW',
        )) 
                
        self.add(pr.RemoteVariable(
            name        = 'opGnd',
            description = 'opGnd',
            offset      = 0x28C,
            bitSize     = 1,
            bitOffset   = 0,
            base        = pr.Bool,
            mode        = 'RW',
        ))   
                
        self.add(pr.RemoteVariable(
            name        = 'rbuf',
            description = 'rbuf',
            offset      = 0x290,
            bitSize     = 1,
            bitOffset   = 0,
            base        = pr.Bool,
            mode        = 'RW',
        ))                   
                
        self.add(pr.RemoteVariable(
            name        = 'halfSckPeriod',
            description = 'halfSckPeriod',
            offset      = 0x294,
            bitSize     = 32,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'RW',
        ))                
                
        self.add(pr.RemoteVariable(
            name        = 'hrdRst',
            description = 'hrdRst',
            offset      = 0x3F8,
            bitSize     = 1,
            bitOffset   = 0,
            base        = pr.UInt,
            mode        = 'WO',
            hidden      = False,
        )) 
        
    def hardReset(self):
        self.hrdRst.set(1)
        