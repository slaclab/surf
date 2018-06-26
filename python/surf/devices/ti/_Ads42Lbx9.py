#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Ads42Lbx9 Module
#-----------------------------------------------------------------------------
# File       : ADS42LBx9.py
# Created    : 2017-06-23
#-----------------------------------------------------------------------------
# Description:
# PyRogue Ads42Lbx9 Module
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
import time

class Ads42Lbx9Config(pr.Device):
    def __init__( self,       
        name        = "Ads42Lbx9Config",
        description = "ADS42LBx9 Config Module",
        memBase     =  None,
        offset      =  0x00,
        hidden      =  False,
        expand      =  True,
        enabled     =  True,
    ):
        super().__init__(
            name        = name,
            description = description,
            memBase     = memBase,
            offset      = offset,
            hidden      = hidden,
            expand      = expand,
            enabled     = enabled,
        )

        ##############################
        # Variables
        ##############################
        
        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x0006",
            description  = "ADC Control Registers",
            offset       =  0x18,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
            verify       = False,
        ))
        
        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x0007",
            description  = "ADC Control Registers",
            offset       =  0x1C,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))
        
        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x0008",
            description  = "ADC Control Registers",
            offset       =  0x20,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))
        
        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x000B",
            description  = "ADC Control Registers",
            offset       =  0x2C,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))
        
        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x000C",
            description  = "ADC Control Registers",
            offset       =  0x30,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x000D",
            description  = "ADC Control Registers",
            offset       =  0x34,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
            verify       = False,
        ))

        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x000F",
            description  = "ADC Control Registers",
            offset       =  0x3C,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x0010",
            description  = "ADC Control Registers",
            offset       =  0x40,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x0011",
            description  = "ADC Control Registers",
            offset       =  0x44,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x0012",
            description  = "ADC Control Registers",
            offset       =  0x48,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x0013",
            description  = "ADC Control Registers",
            offset       =  0x4C,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x0014",
            description  = "ADC Control Registers",
            offset       =  0x50,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x0015",
            description  = "ADC Control Registers",
            offset       =  0x54,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x0016",
            description  = "ADC Control Registers",
            offset       =  0x58,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))
        
        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x0017",
            description  = "ADC Control Registers",
            offset       =  0x5C,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))
        
        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x0018",
            description  = "ADC Control Registers",
            offset       =  0x60,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))
        
        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x001F",
            description  = "ADC Control Registers",
            offset       =  0x7C,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
            verify       = False,
        ))
        
        self.add(pr.RemoteVariable(    
            name         = "AdcReg_0x0020",
            description  = "ADC Control Registers",
            offset       =  0x80,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

class Ads42Lbx9Readout(pr.Device):
    def __init__( self,       
        name        = "Ads42Lbx9Readout",
        description = "ADS42LBx9 Readout Module",
        memBase     =  None,
        offset      =  0x00,
        hidden      =  False,
        expand      =  True,
        enabled     =  True,
    ):
        super().__init__(
            name        = name,
            description = description,
            memBase     = memBase,
            offset      = offset,
            hidden      = hidden,
            expand      = expand,
            enabled     = enabled,
        )

        ##############################
        # Variables
        ##############################
        
        self.addRemoteVariables(    
            name         = "DelayAdcALane",
            description  = "LVDS Lane Delay",
            offset       =  0x200,
            bitSize      =  10,
            bitOffset    =  0x00,
            base         = pr.UInt,
            number       =  8,
            stride       =  4,            
            mode         = "RW",
            verify       = False,
        )

        self.addRemoteVariables(    
            name         = "DelayAdcBLane",
            description  = "LVDS Lane Delay",
            offset       =  0x220,
            bitSize      =  10,
            bitOffset    =  0x00,
            base         = pr.UInt,
            number       =  8,
            stride       =  4,            
            mode         = "RW",
            verify       = False,
        )
        
        self.addRemoteVariables(    
            name         = "AdcASample",
            description  = "ADC Sample",
            offset       =  0x180,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = pr.UInt,
            number       =  8,
            stride       =  4,             
            mode         = "RO",
        )
                            
        self.addRemoteVariables(    
            name         = "AdcBSample",
            description  = "ADC Sample",
            offset       =  0x1A0,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = pr.UInt,
            number       =  8,
            stride       =  4,             
            mode         = "RO",
        )
                        
        self.add(pr.RemoteVariable(    
            name         = "DMode",
            description  = "DMode",
            offset       =  0x240,
            bitSize      =  2,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))
        
        self.add(pr.RemoteVariable(    
            name         = "Invert",
            description  = "Invert",
            offset       =  0x244,
            bitSize      =  2,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))
        
        self.add(pr.RemoteVariable(    
            name         = "Convert",
            description  = "Convert",
            offset       =  0x248,
            bitSize      =  2,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))
