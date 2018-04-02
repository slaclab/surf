#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue _Tcn75a Module
#-----------------------------------------------------------------------------
# File       : _Tcn75a.py
# Created    : 2017-01-17
# Last update: 2017-01-17
#-----------------------------------------------------------------------------
# Description:
# PyRogue _Tcn75a Module
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

class Tcn75a(pr.Device):      
    def __init__(self,       
            name        = "Tcn75a",
            description = "Tcn75a",
            **kwargs):
        super().__init__(name=name, description=description, **kwargs)                                  

        self.add(pr.RemoteVariable(  
            name        = 'AmbientTemperature',
            description = 'Ambient Temperature Register (TA)',
            offset      = (0x00 << 2), 
            bitSize     = 16, 
            bitOffset   = 0, 
            base        = pr.Int,
            mode        = 'RO',
        ))  

        self.add(pr.RemoteVariable(  
            name        = 'Configuration',
            description = 'Sensor Configuration Register (CONFIG)',
            offset      = (0x01 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))         
        
        self.add(pr.RemoteVariable(  
            name        = 'TemperatureHysteresis',
            description = 'Temperature Hysteresis Register (THYST)',
            offset      = (0x02 << 2), 
            bitSize     = 16, 
            bitOffset   = 0, 
            base        = pr.Int,
            mode        = 'RW',
        )) 

        self.add(pr.RemoteVariable(  
            name        = 'TemperatureLimitSet',
            description = 'Temperature Limit-Set Register (TSET)',
            offset      = (0x03 << 2), 
            bitSize     = 16, 
            bitOffset   = 0, 
            base        = pr.Int,
            mode        = 'RW',
        ))         
        