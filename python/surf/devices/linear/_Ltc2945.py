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

class Ltc2945(pr.Device):      
    def __init__(self,       
            name        = "Ltc2945",
            description = "Ltc2945",
            **kwargs):
        super().__init__(name=name, description=description, **kwargs)                                  

        self.add(pr.RemoteVariable(  
            name        = 'Control',
            description = 'Controls ADC Operation Mode and Test Mode',
            offset      = (0x00 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))  

        self.add(pr.RemoteVariable(  
            name        = 'Alert',
            description = 'Selects Which Faults Generate Alerts',
            offset      = (0x01 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))   

        self.add(pr.RemoteVariable(  
            name        = 'Status',
            description = 'System Status Information',
            offset      = (0x02 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RO',
        ))     

        self.add(pr.RemoteVariable(  
            name        = 'Fault',
            description = 'Fault Log',
            offset      = (0x03 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        )) 

        # self.add(pr.RemoteVariable(  
            # name        = 'FaultCoR',
            # description = 'Same Data as Register D, D Content Cleared on Read',
            # offset      = (0x04 << 2), 
            # bitSize     = 8, 
            # bitOffset   = 0, 
            # base        = pr.UInt,
            # mode        = 'RO',
        # ))         
        
        self.add(pr.RemoteVariable(  
            name        = 'PowerMsb2',
            description = 'Power MSB2 Data',
            offset      = (0x05 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RO',
        ))         
        
        self.add(pr.RemoteVariable(  
            name        = 'PowerMsb1',
            description = 'Power MSB1 Data',
            offset      = (0x06 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RO',
        ))  

        self.add(pr.RemoteVariable(  
            name        = 'PowerLsb',
            description = 'Power LSB Data',
            offset      = (0x07 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RO',
        ))  
        
        self.add(pr.RemoteVariable(  
            name        = 'MaxPowerMsb2',
            description = 'Maximum Power MSB2 Data',
            offset      = (0x08 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))         
        
        self.add(pr.RemoteVariable(  
            name        = 'MaxPowerMsb1',
            description = 'Maximum Power MSB1 Data',
            offset      = (0x09 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))  

        self.add(pr.RemoteVariable(  
            name        = 'MaxPowerLsb',
            description = 'Maximum Power LSB Data',
            offset      = (0x0A << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))          
        
        self.add(pr.RemoteVariable(  
            name        = 'MinPowerMsb2',
            description = 'Minimum Power MSB2 Data',
            offset      = (0x0B << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))         
        
        self.add(pr.RemoteVariable(  
            name        = 'MinPowerMsb1',
            description = 'Minimum Power MSB1 Data',
            offset      = (0x0C << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))  

        self.add(pr.RemoteVariable(  
            name        = 'MinPowerLsb',
            description = 'Minimum Power LSB Data',
            offset      = (0x0D << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))          

        self.add(pr.RemoteVariable(  
            name        = 'MaxPowerThresholdMsb2',
            description = 'Maximum Power Threshold MSB2 to Generate Alert',
            offset      = (0x0E << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))         
        
        self.add(pr.RemoteVariable(  
            name        = 'MaxPowerThresholdMsb1',
            description = 'Maximum Power Threshold MSB1 to Generate Alert',
            offset      = (0x0F << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))  

        self.add(pr.RemoteVariable(  
            name        = 'MaxPowerThresholdLsb',
            description = 'Maximum Power Threshold LSB to Generate Alert',
            offset      = (0x10 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))          
        
        self.add(pr.RemoteVariable(  
            name        = 'MinPowerThresholdMsb2',
            description = 'Minimum Power Threshold MSB2 to Generate Alert',
            offset      = (0x11 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))         
        
        self.add(pr.RemoteVariable(  
            name        = 'MinPowerThresholdMsb1',
            description = 'Minimum Power Threshold MSB1 to Generate Alert',
            offset      = (0x12 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))  

        self.add(pr.RemoteVariable(  
            name        = 'MinPowerThresholdLsb',
            description = 'Minimum Power Threshold LSB to Generate Alert',
            offset      = (0x13 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))  
        
        self.add(pr.RemoteVariable(  
            name        = 'SenseMsb',
            description = 'SENSE MSB Data',
            offset      = (0x14 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RO',
        ))    

        self.add(pr.RemoteVariable(  
            name        = 'SenseLsb',
            description = 'SENSE LSB Data',
            offset      = (0x15 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RO',
        )) 

        self.add(pr.RemoteVariable(  
            name        = 'MaxSenseMsb',
            description = 'Maximum SENSE MSB Data',
            offset      = (0x16 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))    

        self.add(pr.RemoteVariable(  
            name        = 'MaxSenseLsb',
            description = 'Maximum SENSE LSB Data',
            offset      = (0x17 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))  

        self.add(pr.RemoteVariable(  
            name        = 'MinSenseMsb',
            description = 'Minimum SENSE MSB Data',
            offset      = (0x18 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))    

        self.add(pr.RemoteVariable(  
            name        = 'MinSenseLsb',
            description = 'Minimum SENSE LSB Data',
            offset      = (0x19 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))  

        self.add(pr.RemoteVariable(  
            name        = 'MaxSenseThresholdMsb',
            description = 'Maximum SENSE Threshold MSB to Generate Alert',
            offset      = (0x1A << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))    

        self.add(pr.RemoteVariable(  
            name        = 'MaxSenseThresholdLsb',
            description = 'Maximum SENSE Threshold LSB to Generate Alert',
            offset      = (0x1B << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))  

        self.add(pr.RemoteVariable(  
            name        = 'MinSenseThresholdMsb',
            description = 'Minimum SENSE Threshold MSB to Generate Alert',
            offset      = (0x1C << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))    

        self.add(pr.RemoteVariable(  
            name        = 'MinSenseThresholdLsb',
            description = 'Minimum SENSE Threshold LSB to Generate Alert',
            offset      = (0x1D << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))          

        self.add(pr.RemoteVariable(  
            name        = 'VinMsb',
            description = 'ADC VIN MSB Data',
            offset      = (0x1E << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RO',
        ))    

        self.add(pr.RemoteVariable(  
            name        = 'VinLsb',
            description = 'ADC VIN LSB Data',
            offset      = (0x1F << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RO',
        )) 

        self.add(pr.RemoteVariable(  
            name        = 'MaxVinMsb',
            description = 'Maximum ADC VIN MSB Data',
            offset      = (0x20 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))    

        self.add(pr.RemoteVariable(  
            name        = 'MaxVinLsb',
            description = 'Maximum ADC VIN LSB Data',
            offset      = (0x21 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))  

        self.add(pr.RemoteVariable(  
            name        = 'MinVinMsb',
            description = 'Minimum ADC VIN MSB Data',
            offset      = (0x22 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))    

        self.add(pr.RemoteVariable(  
            name        = 'MinVinLsb',
            description = 'Minimum ADC VIN LSB Data',
            offset      = (0x23 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))  

        self.add(pr.RemoteVariable(  
            name        = 'MaxVinThresholdMsb',
            description = 'Maximum ADC VIN Threshold MSB to Generate Alert',
            offset      = (0x24 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))    

        self.add(pr.RemoteVariable(  
            name        = 'MaxVinThresholdLsb',
            description = 'Maximum ADC VIN Threshold LSB Dto Generate Alert',
            offset      = (0x25 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))  

        self.add(pr.RemoteVariable(  
            name        = 'MinVinThresholdMsb',
            description = 'Minimum ADC VIN Threshold MSB to Generate Alert',
            offset      = (0x26 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))    

        self.add(pr.RemoteVariable(  
            name        = 'MinVinThresholdLsb',
            description = 'Minimum ADC VIN Threshold LSB to Generate Alert',
            offset      = (0x27 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))          

        self.add(pr.RemoteVariable(  
            name        = 'AdinMsb',
            description = 'ADIN MSB Data',
            offset      = (0x28 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RO',
        ))    

        self.add(pr.RemoteVariable(  
            name        = 'AdinLsb',
            description = 'ADIN LSB Data',
            offset      = (0x29 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RO',
        )) 

        self.add(pr.RemoteVariable(  
            name        = 'MaxAdinMsb',
            description = 'Maximum ADIN MSB Data',
            offset      = (0x2A << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))    

        self.add(pr.RemoteVariable(  
            name        = 'MaxAdinLsb',
            description = 'Maximum ADIN LSB Data',
            offset      = (0x2B << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))  

        self.add(pr.RemoteVariable(  
            name        = 'MinAdinMsb',
            description = 'Minimum ADIN MSB Data',
            offset      = (0x2C << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))    

        self.add(pr.RemoteVariable(  
            name        = 'MinAdinLsb',
            description = 'Minimum ADIN LSB Data',
            offset      = (0x2D << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))  

        self.add(pr.RemoteVariable(  
            name        = 'MaxAdinThresholdMsb',
            description = 'Maximum ADIN Threshold MSB to Generate Alert',
            offset      = (0x2E << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))    

        self.add(pr.RemoteVariable(  
            name        = 'MaxAdinThresholdLsb',
            description = 'Maximum ADIN Threshold LSB Dto Generate Alert',
            offset      = (0x2F << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))  

        self.add(pr.RemoteVariable(  
            name        = 'MinAdinThresholdMsb',
            description = 'Minimum ADIN Threshold MSB to Generate Alert',
            offset      = (0x30 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))    

        self.add(pr.RemoteVariable(  
            name        = 'MinAdinThresholdLsb',
            description = 'Minimum ADIN Threshold LSB to Generate Alert',
            offset      = (0x31 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))  
        