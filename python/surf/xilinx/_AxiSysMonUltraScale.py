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
        memBase     =  None,
        offset      =  0x00,
        hidden      =  False,
        expand      =  True,
    ):
        super().__init__(
            name        = name,
            description = description,
            memBase     = memBase,
            offset      = offset,
            hidden      = hidden,
            expand      = expand,
        )

        ##############################
        # Variables
        ##############################

        self.addVariable(   
            name         = "SR",
            description  = "Status Register",
            offset       =  0x04,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
            hidden       =  True,
        )

        self.addVariable(   
            name         = "AOSR",
            description  = "Alarm Output Status Register",
            offset       =  0x08,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
            hidden       =  True,
        )

        self.addVariable(   
            name         = "CONVSTR",
            description  = "CONVST Register",
            offset       =  0x0C,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "WO",
            hidden       =  True,
        )

        self.addVariable(   
            name         = "SYSMONRR",
            description  = "SYSMON Hard Macro Reset Register",
            offset       =  0x10,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "WO",
            hidden       =  True,
        )

        self.addVariable(   
            name         = "GIER",
            description  = "Global Interrupt Enable Register",
            offset       =  0x5C,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
            hidden       =  True,
        )

        self.addVariable(   
            name         = "IPISR",
            description  = "IP Interrupt Status Register",
            offset       =  0x60,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
            hidden       =  True,
        )

        self.addVariable(   
            name         = "IPIER",
            description  = "IP Interrupt Enable Register",
            offset       =  0x68,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
            hidden       =  True,
        )

        self.addVariable(   
            name         = "Temperature",
            description  = "Temperature's ADC value",
            offset       =  0x400,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
        )

        self.addVariable(   
            name         = "VCCINT",
            description  = "VCCINT's ADC value",
            offset       =  0x404,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
        )

        self.addVariable(   
            name         = "VCCAUX",
            description  = "VCCAUX's ADC value",
            offset       =  0x408,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
        )

        self.addVariable(   
            name         = "VP_VN",
            description  = "VP/VN's ADC value",
            offset       =  0x40C,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
            hidden       =  True,
        )

        self.addVariable(   
            name         = "VREFP",
            description  = "VREFP's ADC value",
            offset       =  0x410,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
            hidden       =  True,
        )

        self.addVariable(   
            name         = "VREFN",
            description  = "VREFN's ADC value",
            offset       =  0x414,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
            hidden       =  True,
        )

        self.addVariable(   
            name         = "VBRAM",
            description  = "VBRAM's ADC value",
            offset       =  0x418,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
        )

        self.addVariable(   
            name         = "SupplyOffset",
            description  = "Supply Offset",
            offset       =  0x420,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
            hidden       =  True,
        )

        self.addVariable(   
            name         = "ADCOffset",
            description  = "ADC Offset",
            offset       =  0x424,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
            hidden       =  True,
        )

        self.addVariable(   
            name         = "GainError",
            description  = "Gain Error",
            offset       =  0x428,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
            hidden       =  True,
        )

        self.addVariables(  
            name         = "VAUXP_VAUXN",
            description  = "VAUXP_VAUXN's ADC values",
            offset       =  0x440,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
            number       =  16,
            stride       =  4,
            hidden       =  True,
        )

        self.addVariable(   
            name         = "MaxTemp",
            description  = "maximum temperature measurement",
            offset       =  0x480,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
        )

        self.addVariable(   
            name         = "MaxVCCINT",
            description  = "maximum VCCINT measurement",
            offset       =  0x484,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
        )

        self.addVariable(   
            name         = "MaxVCCAUX",
            description  = "maximum VCCAUX measurement",
            offset       =  0x488,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
        )

        self.addVariable(   
            name         = "MaxVBRAM",
            description  = "maximum VBRAM measurement",
            offset       =  0x48C,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
        )

        self.addVariable(   
            name         = "MinTemp",
            description  = "minimum temperature measurement",
            offset       =  0x490,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
        )

        self.addVariable(   
            name         = "MinVCCINT",
            description  = "minimum VCCINT measurement",
            offset       =  0x494,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
        )

        self.addVariable(   
            name         = "MinVCCAUX",
            description  = "minimum VCCAUX measurement",
            offset       =  0x498,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
        )

        self.addVariable(   
            name         = "MinVBRAM",
            description  = "minimum VBRAM measurement",
            offset       =  0x49C,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
        )

        self.addVariable(   
            name         = "I2C_Address",
            description  = "I2C Address",
            offset       =  0x4E0,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
            hidden       =  True,
        )

        self.addVariable(   
            name         = "FlagRegister",
            description  = "Flag Register",
            offset       =  0x4FC,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
            hidden       =  True,
        )

        self.addVariables(  
            name         = "ConfigurationRegister",
            description  = "Configuration Registers",
            offset       =  0x500,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
            number       =  4,
            stride       =  4,
            hidden       =  True,
        )

        self.addVariable(   
            name         = "SequenceRegister8",
            description  = "Sequence Register 8",
            offset       =  0x518,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
            hidden       =  True,
        )

        self.addVariable(   
            name         = "SequenceReg9",
            description  = "Sequence Register 9",
            offset       =  0x51C,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
            hidden       =  True,
        )

        self.addVariables(  
            name         = "SequenceReg_7_0",
            description  = "Sequence Register [7:0]",
            offset       =  0x520,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
            number       =  8,
            stride       =  4,
            hidden       =  True,
        )

        self.addVariables(  
            name         = "AlarmThresholdReg_8_0",
            description  = "Alarm Threshold Register [8:0]",
            offset       =  0x540,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
            number       =  9,
            stride       =  4,
            hidden       =  True,
        )

        self.addVariable(   
            name         = "AlarmThresholdReg12",
            description  = "Alarm Threshold Register 12",
            offset       =  0x570,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
            hidden       =  True,
        )

        self.addVariable(   
            name         = "AlarmThresholdReg16",
            description  = "Alarm Threshold Register 16",
            offset       =  0x580,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
            hidden       =  True,
        )

        self.addVariables(  
            name         = "AlarmThresholdReg_25_16",
            description  = "Alarm Threshold Register [25:16]",
            offset       =  0x580,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
            number       =  8,
            stride       =  4,
            hidden       =  True,
        )

        self.addVariables(  
            name         = "VUSER",
            description  = "VUSER[4:0] supply monitor measurement",
            offset       =  0x600,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
            number       =  4,
            stride       =  4,
            hidden       =  True,
        )

        self.addVariables(  
            name         = "MAX_VUSER",
            description  = "Maximum VUSER[4:0] supply monitor measurement",
            offset       =  0x680,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
            number       =  4,
            stride       =  4,
            hidden       =  True,
        )

        self.addVariables(  
            name         = "MIN_VUSER",
            description  = "Minimum VUSER[4:0] supply monitor measurement",
            offset       =  0x6A0,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
            number       =  4,
            stride       =  4,
            hidden       =  True,
        )
        