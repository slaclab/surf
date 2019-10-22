#!/usr/bin/env python
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

import surf.protocols.i2c  as i2c

class EM22xx(i2c.PMBus):
    def __init__(   self,       
            name        = 'EM22xx',
            description = 'EM22xx Container',
            **kwargs):
        super().__init__(name=name, description=description, **kwargs) 

        self.add(pr.LinkVariable(
            name         = 'VIN', 
            mode         = 'RO', 
            units        = 'V',
            disp         = '{:1.3f}',
            linkedGet    = i2c.getPMbusLinearDataFormat,
            dependencies = [self.READ_VIN],
        ))
        
        self.add(pr.LinkVariable(
            name         = 'VOUT', 
            mode         = 'RO', 
            units        = 'V',
            disp         = '{:1.3f}',
            linkedGet    = i2c.getPMbusLinearDataFormat,
            dependencies = [self.READ_VOUT],
        ))        
        
        self.add(pr.LinkVariable(
            name         = 'IOUT', 
            mode         = 'RO', 
            units        = 'A',
            disp         = '{:1.3f}',
            linkedGet    = i2c.getPMbusLinearDataFormat,
            dependencies = [self.READ_IOUT],
        ))   
        
        self.add(pr.LinkVariable(
            name         = 'TEMPERATURE[1]', 
            mode         = 'RO', 
            units        = 'degC',
            disp         = '{:1.3f}',
            linkedGet    = i2c.getPMbusLinearDataFormat,
            dependencies = [self.READ_TEMPERATURE_1],
        ))   
        
        self.add(pr.LinkVariable(
            name         = 'TEMPERATURE[2]', 
            mode         = 'RO', 
            units        = 'degC',
            disp         = '{:1.3f}',
            linkedGet    = i2c.getPMbusLinearDataFormat,
            dependencies = [self.READ_TEMPERATURE_2],
        )) 
        
        self.add(pr.LinkVariable(
            name         = 'DUTY_CYCLE', 
            mode         = 'RO', 
            units        = 'kHz',
            disp         = '{:1.3f}',
            linkedGet    = i2c.getPMbusLinearDataFormat,
            dependencies = [self.READ_DUTY_CYCLE],
        )) 

        self.add(pr.LinkVariable(
            name         = 'FREQUENCY', 
            mode         = 'RO', 
            units        = 'kHz',
            disp         = '{:1.3f}',
            linkedGet    = i2c.getPMbusLinearDataFormat,
            dependencies = [self.READ_FREQUENCY],
        ))         
        
        self.add(pr.LinkVariable(
            name         = 'POUT', 
            mode         = 'RO', 
            units        = 'W',
            disp         = '{:1.3f}',
            linkedGet    = i2c.getPMbusLinearDataFormat,
            dependencies = [self.READ_POUT],
        ))   
