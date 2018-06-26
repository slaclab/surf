#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue AXI-Lite System Managment for Xilinx Ultra Scale (Refer to PG185 and UG580)
#-----------------------------------------------------------------------------
# File       : AxiSysMonUltraScale.py
# Created    : 2017-04-12
#-----------------------------------------------------------------------------
# Description:
# PyRogue AXI-Lite System Managment for Xilinx Ultra Scale (Refer to PG185 and UG580)
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

class AxiSysMonUltraScale(pr.Device):
    def __init__(   self,       
            name        = "AxiSysMonUltraScale",
            description = "AXI-Lite System Managment for Xilinx Ultra Scale (Refer to PG185 and UG580)",
            **kwargs):
        super().__init__(name=name, description=description, **kwargs) 

        def addPair(name,offset,bitSize,units,bitOffset,description,function,pollInterval = 0,):
            self.add(pr.RemoteVariable(  
                name         = (name+"Raw"), 
                offset       = offset, 
                bitSize      = bitSize, 
                bitOffset    = bitOffset,
                base         = pr.UInt, 
                mode         = 'RO', 
                description  = description,
                pollInterval = pollInterval,
                hidden       = True,
            ))
            self.add(pr.LinkVariable(
                name         = name, 
                mode         = 'RO', 
                units        = units,
                linkedGet    = function,
                disp         = '{:1.3f}',
                dependencies = [self.variables[name+"Raw"]],
            ))
        
        ##############################
        # Variables
        ##############################

        self.add(pr.RemoteVariable(    
            name         = "SR",
            description  = "Status Register",
            offset       =  0x04,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
            hidden       =  True,
        ))

        self.add(pr.RemoteVariable(    
            name         = "AOSR",
            description  = "Alarm Output Status Register",
            offset       =  0x08,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
            hidden       =  True,
        ))

        self.add(pr.RemoteVariable(    
            name         = "CONVSTR",
            description  = "CONVST Register",
            offset       =  0x0C,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "WO",
            hidden       =  True,
        ))

        self.add(pr.RemoteVariable(    
            name         = "SYSMONRR",
            description  = "SYSMON Hard Macro Reset Register",
            offset       =  0x10,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "WO",
            hidden       =  True,
        ))

        self.add(pr.RemoteVariable(    
            name         = "GIER",
            description  = "Global Interrupt Enable Register",
            offset       =  0x5C,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
            hidden       =  True,
        ))

        self.add(pr.RemoteVariable(    
            name         = "IPISR",
            description  = "IP Interrupt Status Register",
            offset       =  0x60,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
            hidden       =  True,
        ))

        self.add(pr.RemoteVariable(    
            name         = "IPIER",
            description  = "IP Interrupt Enable Register",
            offset       =  0x68,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
            hidden       =  True,
        ))

        ###############################################
        
        addPair(
            name         = 'Temperature',
            offset       = 0x400, 
            bitSize      = 12, 
            bitOffset    = 4, 
            units        = "degC", 
            function     = self.convTemp,
            pollInterval = 5,
            description  = "Temperature's ADC value",
        )        
        
        addPair(
            name         = 'VccInt',
            offset       = 0x404, 
            bitSize      = 12, 
            bitOffset    = 4, 
            units        = "V", 
            function     = self.convCoreVoltage,
            pollInterval = 5,
            description  = "VCCINT's ADC value",
        )        

        addPair(
            name         = 'VccAux', 
            offset       = 0x408, 
            bitSize      = 12, 
            bitOffset    = 4, 
            units        = "V", 
            function     = self.convCoreVoltage,
            pollInterval = 5,
            description  = "VCCAUX's ADC value",
        )    

        addPair(
            name         = 'VpVn', 
            offset       = 0x40C, 
            bitSize      = 12, 
            bitOffset    = 4, 
            units        = "V", 
            function     = self.convCoreVoltage,
            pollInterval = 5,
            description  = "VP/VN's ADC value",
        )           
        
        addPair(
            name         = 'Vrefp', 
            offset       = 0x410, 
            bitSize      = 12, 
            bitOffset    = 4, 
            units        = "V", 
            function     = self.convCoreVoltage,
            pollInterval = 5,
            description  = "VREFP's ADC value",
        )     

        addPair(
            name         = 'Vrefn', 
            offset       = 0x414, 
            bitSize      = 12, 
            bitOffset    = 4, 
            units        = "V", 
            function     = self.convCoreVoltage,
            pollInterval = 5,
            description  = "VREFN's ADC value",
        )             
        
        addPair(
            name        = 'VccBram', 
            offset      = 0x418, 
            bitSize     = 12, 
            bitOffset   = 4, 
            units       = "V", 
            function    = self.convCoreVoltage,
            pollInterval = 5,
            description  = "VBRAM's ADC value",
        )

        addPair(
            name        = 'SupplyOffset', 
            offset      = 0x420, 
            bitSize     = 12, 
            bitOffset   = 4, 
            units       = "V", 
            function    = self.convCoreVoltage,
            pollInterval = 5,
            description  = "Supply Offset",
        )     

        addPair(
            name        = 'AdcOffset', 
            offset      = 0x424, 
            bitSize     = 12, 
            bitOffset   = 4, 
            units       = "V", 
            function    = self.convCoreVoltage,
            pollInterval = 5,
            description  = "ADC Offset",
        )     

        addPair(
            name        = 'GainError', 
            offset      = 0x428, 
            bitSize     = 12, 
            bitOffset   = 4, 
            units       = "", 
            function    = self.convCoreVoltage,
            pollInterval = 5,
            description  = "Gain Offset",
        )             
        
        addPair(
            name         = 'VauxpVauxn', 
            offset       = 0x440, 
            bitSize      = 12, 
            bitOffset    = 4, 
            units        = "V", 
            function     = self.convAuxVoltage,
            pollInterval = 5,
            description  = "VAUXP_VAUXN's ADC values",
        )             
        
        addPair(
            name         = 'MaxTemperature',
            offset       = 0x480, 
            bitSize      = 12, 
            bitOffset    = 4, 
            units        = "degC", 
            function     = self.convTemp,
            pollInterval = 5,
            description  = "maximum temperature measurement",
        )    

        addPair(
            name         = 'MaxVccInt', 
            offset       = 0x484, 
            bitSize      = 12, 
            bitOffset    = 4, 
            units        = "V", 
            function     = self.convCoreVoltage,
            pollInterval = 5,
            description  = "maximum VCCINT measurement",
        )  
        
        addPair(
            name         = 'MaxVccAux', 
            offset       = 0x488, 
            bitSize      = 12, 
            bitOffset    = 4, 
            units        = "V", 
            function     = self.convCoreVoltage,
            pollInterval = 5,
            description  = "maximum VCCAUX measurement",
        )          

        addPair(
            name         = 'MaxVccBram', 
            offset       = 0x48C, 
            bitSize      = 12, 
            bitOffset    = 4, 
            units        = "V", 
            function     = self.convCoreVoltage,
            pollInterval = 5,
            description  = "maximum VBRAM measurement",
        )     
        
        addPair(
            name         = 'MinTemperature',
            offset       = 0x490, 
            bitSize      = 12, 
            bitOffset    = 4, 
            units        = "degC", 
            function     = self.convTemp,
            pollInterval = 5,
            description  = "minimum temperature measurement",
        )            
        
        addPair(
            name         = 'MinVccInt', 
            offset       = 0x494, 
            bitSize      = 12, 
            bitOffset    = 4, 
            units        = "V", 
            function     = self.convCoreVoltage,
            pollInterval = 5,
            description  = "minimum VCCINT measurement",
        )  
        
        addPair(
            name         = 'MinVccAux', 
            offset       = 0x498, 
            bitSize      = 12, 
            bitOffset    = 4, 
            units        = "V", 
            function     = self.convCoreVoltage,
            pollInterval = 5,
            description  = "minimum VCCAUX measurement",
        )          

        addPair(
            name         = 'MinVccBram', 
            offset       = 0x49C, 
            bitSize      = 12, 
            bitOffset    = 4, 
            units        = "V", 
            function     = self.convCoreVoltage,
            pollInterval = 5,
            description  = "minimum VBRAM measurement",
        )             

        self.add(pr.RemoteVariable(    
            name         = "I2cAddress",
            description  = "I2C Address",
            offset       =  0x4E0,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
            hidden       =  True,
        ))

        self.add(pr.RemoteVariable(    
            name         = "FlagRegister",
            description  = "Flag Register",
            offset       =  0x4FC,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
            hidden       =  True,
        ))

        self.addRemoteVariables( 
            name         = "Configuration",
            description  = "Configuration Registers",
            offset       =  0x500,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
            number       =  4,
            stride       =  4,
            hidden       =  True,
        )

        self.add(pr.RemoteVariable(    
            name         = "SequenceReg8",
            description  = "Sequence Register 8",
            offset       =  0x518,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
            hidden       =  True,
        ))

        self.add(pr.RemoteVariable(    
            name         = "SequenceReg9",
            description  = "Sequence Register 9",
            offset       =  0x51C,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
            hidden       =  True,
        ))

        self.addRemoteVariables( 
            name         = "SequenceReg_7_0",
            description  = "Sequence Register [7:0]",
            offset       =  0x520,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
            number       =  8,
            stride       =  4,
            hidden       =  True,
        )

        self.addRemoteVariables( 
            name         = "AlarmThresholdReg_8_0",
            description  = "Alarm Threshold Register [8:0]",
            offset       =  0x540,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
            number       =  9,
            stride       =  4,
            hidden       =  True,
        )

        self.add(pr.RemoteVariable(    
            name         = "AlarmThresholdReg12",
            description  = "Alarm Threshold Register 12",
            offset       =  0x570,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
            hidden       =  True,
        ))

        self.addRemoteVariables( 
            name         = "AlarmThresholdReg_25_16",
            description  = "Alarm Threshold Register [25:16]",
            offset       =  0x580,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
            number       =  8,
            stride       =  4,
            hidden       =  True,
        )

        self.addRemoteVariables( 
            name         = "Vuser",
            description  = "VUSER[4:0] supply monitor measurement",
            offset       =  0x600,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
            number       =  4,
            stride       =  4,
            hidden       =  True,
        )

        self.addRemoteVariables( 
            name         = "MaxVuser",
            description  = "Maximum VUSER[4:0] supply monitor measurement",
            offset       =  0x680,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
            number       =  4,
            stride       =  4,
            hidden       =  True,
        )

        self.addRemoteVariables( 
            name         = "MinVuser",
            description  = "Minimum VUSER[4:0] supply monitor measurement",
            offset       =  0x6A0,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
            number       =  4,
            stride       =  4,
            hidden       =  True,
        )
        
        # Default to simple view
        self.simpleView()
        

    @staticmethod
    def convTemp(dev, var):
        value   = var.dependencies[0].get(read=False)
        fpValue = value*(501.3743/4096.0)
        fpValue -= 273.6777
        return (fpValue)

    @staticmethod
    def convCoreVoltage(var):
        value   = var.dependencies[0].value()
        fpValue = value*(732.0E-6)
        return fpValue

    @staticmethod
    def convAuxVoltage(var):
        return var.dependencies[0].value() * 244e-6
        
    def simpleView(self):
        # Hide all the variable
        self.hideVariables(hidden=True)
        # Then unhide the most interesting ones
        vars = ["Temperature", "VccInt", "VccAux", "VccBram"]
        self.hideVariables(hidden=False, variables=vars)
               
        
