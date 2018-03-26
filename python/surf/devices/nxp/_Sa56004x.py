#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue _Sa56004x Module
#-----------------------------------------------------------------------------
# File       : _Sa56004x.py
# Created    : 2017-01-17
# Last update: 2017-01-17
#-----------------------------------------------------------------------------
# Description:
# PyRogue _Sa56004x Module
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

class Sa56004x(pr.Device):      
    def __init__(self,       
            name        = "Sa56004x",
            description = "Sa56004x",
            **kwargs):
        super().__init__(name=name, description=description, **kwargs)                                  

        self.add(pr.RemoteVariable(  
            name        = 'LocalTemperatureHighByte',
            description = 'local temperature high byte (LTHB)',
            offset      = (0x00 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RO',
        ))   

        self.add(pr.RemoteVariable(  
            name        = 'RemoteTemperatureHighByte',
            description = 'remote temperature high byte (RTHB)',
            offset      = (0x01 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RO',
        )) 

        self.add(pr.RemoteVariable(  
            name        = 'StatusRegister',
            description = 'status register (SR)',
            offset      = (0x02 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RO',
        )) 

        self.add(pr.RemoteVariable(  
            name        = 'ConfigurationRegisterRead',
            description = 'configuration register read access (CON))',
            offset      = (0x03 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RO',
        ))    

        self.add(pr.RemoteVariable(  
            name        = 'ConfigurationRegisterWrite',
            description = 'configuration register write access (CON))',
            offset      = (0x09 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'WO',
        )) 

        self.add(pr.RemoteVariable(  
            name        = 'ConversionRateRead',
            description = 'conversion rate read access (CR)',
            offset      = (0x04 << 2), 
            bitSize     = 4, 
            bitOffset   = 4, 
            base        = pr.UInt,
            mode        = 'RO',
        ))    

        self.add(pr.RemoteVariable(  
            name        = 'ConversionRateWrite',
            description = 'conversion rate write access (CR)',
            offset      = (0x0A << 2), 
            bitSize     = 4, 
            bitOffset   = 4, 
            base        = pr.UInt,
            mode        = 'WO',
        ))         
        
        self.add(pr.RemoteVariable(  
            name        = 'LocalHighSetpointRead',
            description = 'local high setpoint read access (LHS)',
            offset      = (0x05 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RO',
        ))    

        self.add(pr.RemoteVariable(  
            name        = 'LocalHighSetpointWrite',
            description = 'local high setpoint write access (LHS)',
            offset      = (0x0B << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'WO',
        ))           
        
        self.add(pr.RemoteVariable(  
            name        = 'LocalLowSetpointRead',
            description = 'local low setpoint read access (LLS)',
            offset      = (0x06 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RO',
        ))    

        self.add(pr.RemoteVariable(  
            name        = 'LocalLowSetpointWrite',
            description = 'local low setpoint write access (LLS)',
            offset      = (0x0C << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'WO',
        )) 

        self.add(pr.RemoteVariable(  
            name        = 'RemoteHighSetpointHighByteRead',
            description = 'remote high setpoint high byte read access (RHSHB)',
            offset      = (0x07 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RO',
        ))    

        self.add(pr.RemoteVariable(  
            name        = 'RemoteHighSetpointHighByteWrite',
            description = 'remote high setpoint high byte write access (RHSHB)',
            offset      = (0x0D << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'WO',
        ))  

        self.add(pr.RemoteVariable(  
            name        = 'RemoteHighSetpointLowByteRead',
            description = 'remote high setpoint low byte read access (RLSHB)',
            offset      = (0x08 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RO',
        ))    

        self.add(pr.RemoteVariable(  
            name        = 'RemoteHighSetpointLowByteWrite',
            description = 'remote high setpoint low byte write access (RLSHB)',
            offset      = (0x0E << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'WO',
        )) 
        
        self.add(pr.RemoteCommand(   
            name        = 'OneShot',
            description = 'writing register initiates a one-shot conversion (One Shot)',
            offset      = (0x0F << 2), 
            bitSize      = 1,
            bitOffset    = 0,
            base         = pr.UInt,
            function     = lambda cmd: cmd.set(1),
            hidden       = False,
        ))        
        
        self.add(pr.RemoteVariable(  
            name        = 'RemoteTemperatureLowByte',
            description = 'remote temperature low byte (RTLB)',
            offset      = (0x10 << 2), 
            bitSize     = 6, 
            bitOffset   = 2, 
            base        = pr.UInt,
            mode        = 'RO',
        )) 

        self.add(pr.RemoteVariable(  
            name        = 'RemoteTemperatureOffsetHighByte',
            description = 'remote temperature offset high byte (RTOHB)',
            offset      = (0x11 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(  
            name        = 'RemoteTemperatureOffsetLowByte',
            description = 'remote temperature offset low byte (RTOLB)',
            offset      = (0x12 << 2), 
            bitSize     = 3, 
            bitOffset   = 5, 
            base        = pr.UInt,
            mode        = 'RW',
        ))      

        self.add(pr.RemoteVariable(  
            name        = 'RemoteHighSetpointLowByte',
            description = 'remote high setpoint low byte (RHSLB)',
            offset      = (0x13 << 2), 
            bitSize     = 3, 
            bitOffset   = 5, 
            base        = pr.UInt,
            mode        = 'RW',
        )) 

        self.add(pr.RemoteVariable(  
            name        = 'RemoteLowSetpointLowByte',
            description = 'remote low setpoint low byte (RLSLB)',
            offset      = (0x14 << 2), 
            bitSize     = 3, 
            bitOffset   = 5, 
            base        = pr.UInt,
            mode        = 'RW',
        )) 

        self.add(pr.RemoteVariable(  
            name        = 'RemoteTCritSetpoint',
            description = 'remote T_CRIT setpoint (RCS)',
            offset      = (0x19 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        )) 

        self.add(pr.RemoteVariable(  
            name        = 'LocalTCritSetpoint',
            description = 'local T_CRIT setpoint (LCS)',
            offset      = (0x20 << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RW',
        ))   

        self.add(pr.RemoteVariable(  
            name        = 'TCritHysteresis',
            description = 'T_CRIT hysteresis (TH)',
            offset      = (0x21 << 2), 
            bitSize     = 5, 
            bitOffset   = 3, 
            base        = pr.UInt,
            mode        = 'RW',
        ))  

        self.add(pr.RemoteVariable(  
            name        = 'LocalTemperatureLowByte',
            description = 'local temperature low byte (LTLB))',
            offset      = (0x22 << 2), 
            bitSize     = 6, 
            bitOffset   = 2, 
            base        = pr.UInt,
            mode        = 'RO',
        )) 

        self.add(pr.RemoteVariable(  
            name        = 'AlertMode',
            description = 'Alert mode (AM))',
            offset      = (0xBF << 2), 
            bitSize     = 1, 
            bitOffset   = 7, 
            base        = pr.UInt,
            mode        = 'RW',
        ))         
        
        self.add(pr.RemoteVariable(  
            name        = 'ManufacturerId',
            description = 'read manufacturer’s ID (RMID))',
            offset      = (0xFE << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RO',
        ))   
        
        self.add(pr.RemoteVariable(  
            name        = 'DieRevision',
            description = 'read stepping or die revision (RDR))',
            offset      = (0xFF << 2), 
            bitSize     = 8, 
            bitOffset   = 0, 
            base        = pr.UInt,
            mode        = 'RO',
        ))
        
