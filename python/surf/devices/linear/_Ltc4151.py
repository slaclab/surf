#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue _Ltc2945 Module
#-----------------------------------------------------------------------------
# File       : _Ltc2945.py
# Created    : 2017-01-17
# Last update: 2017-01-17
#-----------------------------------------------------------------------------
# Description:
# PyRogue _Ltc2945 Module
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

class Ltc4151(pr.Device):      
    def __init__(self,       
            name         = "Ltc4151",
            description  = "Container for Ltc4151",
            pollInterval = 1,
            senseRes     = 20.E-3, # Units of Ohms
            **kwargs):
        super().__init__(name=name, description=description, **kwargs)                                  

        self.senseRes = senseRes
        
        self.add(pr.RemoteVariable(  
            name         = 'SenseMsb',
            description  = 'Sense MSB Data',
            offset       = (0x0 << 2), 
            bitSize      = 8, 
            bitOffset    = 0, 
            base         = pr.UInt,
            mode         = 'RO',
            pollInterval = pollInterval,
            hidden       = True,
        ))  

        self.add(pr.RemoteVariable(  
            name         = 'SenseLsb',
            description  = 'Sense LSB Data',
            offset       = (0x1 << 2), 
            bitSize      = 4, 
            bitOffset    = 4, 
            base         = pr.UInt,
            mode         = 'RO',
            pollInterval = pollInterval,
            hidden       = True,
        )) 
        
        self.add(pr.LinkVariable(
            name         = 'Iin', 
            description  = 'Current Measurment',
            mode         = 'RO', 
            units        = 'A',
            disp         = '{:1.3f}',
            dependencies = [self.SenseMsb,self.SenseLsb],
            linkedGet    = lambda: (int(self.SenseMsb.value()<<4)|int(self.SenseLsb.value()&0xF))*20.0E-6/self.senseRes
        ))             

        self.add(pr.RemoteVariable(  
            name         = 'VinMsb',
            description  = 'Vin MSB Data',
            offset       = (0x2 << 2), 
            bitSize      = 8, 
            bitOffset    = 0, 
            base         = pr.UInt,
            mode         = 'RO',
            pollInterval = pollInterval,
            hidden       = True,
        ))  

        self.add(pr.RemoteVariable(  
            name         = 'VinLsb',
            description  = 'Vin LSB Data',
            offset       = (0x3 << 2), 
            bitSize      = 4, 
            bitOffset    = 4, 
            base         = pr.UInt,
            mode         = 'RO',
            pollInterval = pollInterval,
            hidden       = True, 
        ))  
        
        self.add(pr.LinkVariable(
            name         = 'Vin', 
            description  = 'Voltage Measurment',
            mode         = 'RO', 
            units        = 'V',
            disp         = '{:1.3f}',
            dependencies = [self.VinMsb,self.VinLsb],
            linkedGet    = lambda: (int(self.VinMsb.value()<<4)|int(self.VinLsb.value()&0xF))*25.0E-3
        ))           
        
        self.add(pr.LinkVariable(
            name         = 'Pin', 
            description  = 'Power Measurment',
            mode         = 'RO', 
            units        = 'W',
            disp         = '{:1.3f}',
            dependencies = [self.Vin,self.Iin],
            linkedGet    = lambda: (self.Vin.value())*(self.Iin.value())
        ))        

        self.add(pr.RemoteVariable(  
            name         = 'AdinMsb',
            description  = 'Adin MSB Data',
            offset       = (0x4 << 2), 
            bitSize      = 8, 
            bitOffset    = 0, 
            base         = pr.UInt,
            mode         = 'RO',
            pollInterval = pollInterval,
            hidden       = True,
        ))  

        self.add(pr.RemoteVariable(  
            name         = 'AdinLsb',
            description  = 'Adin LSB Data',
            offset       = (0x5 << 2), 
            bitSize      = 4, 
            bitOffset    = 4, 
            base         = pr.UInt,
            mode         = 'RO',
            pollInterval = pollInterval,
            hidden       = True,
        ))          
        
        self.add(pr.LinkVariable(
            name         = 'ADC Input', 
            description  = 'ADC Voltage Measurment',
            mode         = 'RO', 
            units        = 'V',
            disp         = '{:1.3f}',
            dependencies = [self.AdinMsb,self.AdinLsb],
            linkedGet    = lambda: (int(self.AdinMsb.value()<<4)|int(self.AdinLsb.value()&0xF))*500.0E-6
        ))           
        
        self.add(pr.RemoteVariable(  
            name        = 'Control',
            description = 'Controls ADC Operation Mode and Test Mode',
            offset      = (0x06 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))
        