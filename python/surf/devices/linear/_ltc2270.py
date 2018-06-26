#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue _ltc2270 Module
#-----------------------------------------------------------------------------
# File       : _ltc2270.py
# Created    : 2017-01-17
# Last update: 2017-01-17
#-----------------------------------------------------------------------------
# Description:
# PyRogue _ltc2270 Module
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

class Ltc2270(pr.Device):      
    def __init__(self,       
            name        = "Ltc2270",
            description = "Ltc2270",
            **kwargs):
        super().__init__(name=name, description=description, **kwargs)                                  

        self.add(pr.RemoteVariable(  
            name        = 'DacReset',
            description = 'DacReset',
            offset      = 0x000, 
            bitSize     = 1, 
            bitOffset   = 7, 
            base        = pr.Bool,
            mode        = 'RW',
        )) 
              
        self.add(pr.RemoteVariable(  
            name        = 'PwrDwn',
            description = 'PwrDwn',
            offset      = 0x004, 
            bitSize     = 2, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        )) 

        self.add(pr.RemoteVariable(  
            name        = 'ClkInv',
            description = 'ClkInv',
            offset      = 0x008, 
            bitSize     = 1, 
            bitOffset   = 3, 
            base        = pr.Bool,
            mode        = 'RW',
        ))                 
                
        self.add(pr.RemoteVariable(  
            name        = 'ClkPhase',
            description = 'ClkPhase',
            offset      = 0x008, 
            bitSize     = 2, 
            bitOffset   = 1, 
            base        = pr.UInt,
            mode        = 'RW',
        )) 

        self.add(pr.RemoteVariable(  
            name        = 'Dcs',
            description = 'Dcs',
            offset      = 0x008,
            bitSize     = 1, 
            bitOffset   = 0, 
            base        = pr.Bool,
            mode        = 'RW',
        ))
                
        self.add(pr.RemoteVariable(  
            name        = 'ILvds',
            description = 'ILvds',
            offset      = 0x00C, 
            bitSize     = 3, 
            bitOffset   = 4, 
            base        = pr.UInt,
            mode        = 'RW',
        ))                

        self.add(pr.RemoteVariable(  
            name        = 'TermOn',
            description = 'TermOn',
            offset      = 0x00C, 
            bitSize     = 1, 
            bitOffset   = 3, 
            base        = pr.Bool,
            mode        = 'RW',
        ))  

        self.add(pr.RemoteVariable(  
            name        = 'OutOff',
            description = 'OutOff',
            offset      = 0x00C, 
            bitSize     = 1, 
            bitOffset   = 2, 
            base        = pr.Bool,
            mode        = 'RW',
        )) 

        self.add(pr.RemoteVariable(  
            name        = 'OutMode',
            description = 'OutMode',
            offset      = 0x00C, 
            bitSize     = 2, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))  

        self.add(pr.RemoteVariable(  
            name        = 'OutTest',
            description = 'OutTest',
            offset      = 0x010, 
            bitSize     = 3, 
            bitOffset   = 3, 
            base        = pr.UInt,
            mode        = 'RW',
        ))                  

        self.add(pr.RemoteVariable(  
            name        = 'Abp',
            description = 'Abp',
            offset      = 0x010, 
            bitSize     = 1, 
            bitOffset   = 2, 
            base        = pr.Bool,
            mode        = 'RW',
        ))  

        self.add(pr.RemoteVariable(  
            name        = 'Rand',
            description = 'Rand',
            offset      = 0x010, 
            bitSize     = 1, 
            bitOffset   = 1, 
            base        = pr.Bool,
            mode        = 'RW',
        ))   

        self.add(pr.RemoteVariable(  
            name        = 'TwoComp',
            description = 'TwoComp',
            offset      = 0x010, 
            bitSize     = 1, 
            bitOffset   = 0, 
            base        = pr.Bool,
            mode        = 'RW',
        ))   
                
        for i in range(2):
            for j in range(8):
                self.add(pr.RemoteVariable(  
                    name        = ('adcData[%01i][%01i]' % (i,j)), 
                    offset      = ((0x60 + (8*i)+j)*4), 
                    description = '',
                    bitSize     = 16,
                    bitOffset   = 0, 
                    base        = pr.UInt,
                    mode        = 'RO',
                ))                  
                
        self.add(pr.RemoteVariable(  
            name        = 'delayRdy',
            description = 'delayOut.rdy',
            offset      = 0x1FC, 
            bitSize     = 1, 
            bitOffset   = 0, 
            base        = pr.Bool,
            mode        = 'RO',
        ))                 
                
        for i in range(2):
            for j in range(8):
                self.add(pr.RemoteVariable(  
                    name        = ('delayData[%01i][%01i]' % (i,j)), 
                    offset      = ((0x80 + (8*i)+j)*4), 
                    description = '',
                    bitSize     = 5, 
                    bitOffset   = 0, 
                    base        = pr.UInt,
                    mode        = 'RW',
                ))                          
                        