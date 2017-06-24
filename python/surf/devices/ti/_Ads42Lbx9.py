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

class Ads42Lbx9(pr.Device):
    def __init__(self, **kwargs):
        super(self.__class__, self).__init__(description="ADS42LBx9 Module",
                                             **kwargs)

        ##############################
        # Variables
        ##############################
        
        self.addVariable(   name         = "AdcReg_0x0006",
                            description  = "ADC Control Registers",
                            offset       =  0x18,
                            bitSize      =  8,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )
        
        self.addVariable(   name         = "AdcReg_0x0007",
                            description  = "ADC Control Registers",
                            offset       =  0x1C,
                            bitSize      =  8,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )
        
        self.addVariable(   name         = "AdcReg_0x0008",
                            description  = "ADC Control Registers",
                            offset       =  0x20,
                            bitSize      =  8,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )
        
        self.addVariable(   name         = "AdcReg_0x000B",
                            description  = "ADC Control Registers",
                            offset       =  0x2C,
                            bitSize      =  8,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )
        
        self.addVariable(   name         = "AdcReg_0x000C",
                            description  = "ADC Control Registers",
                            offset       =  0x30,
                            bitSize      =  8,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "AdcReg_0x000D",
                            description  = "ADC Control Registers",
                            offset       =  0x34,
                            bitSize      =  8,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "AdcReg_0x000F",
                            description  = "ADC Control Registers",
                            offset       =  0x3C,
                            bitSize      =  8,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "AdcReg_0x0010",
                            description  = "ADC Control Registers",
                            offset       =  0x40,
                            bitSize      =  8,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "AdcReg_0x0011",
                            description  = "ADC Control Registers",
                            offset       =  0x44,
                            bitSize      =  8,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "AdcReg_0x0012",
                            description  = "ADC Control Registers",
                            offset       =  0x48,
                            bitSize      =  8,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "AdcReg_0x0013",
                            description  = "ADC Control Registers",
                            offset       =  0x4C,
                            bitSize      =  8,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "AdcReg_0x0014",
                            description  = "ADC Control Registers",
                            offset       =  0x50,
                            bitSize      =  8,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "AdcReg_0x0015",
                            description  = "ADC Control Registers",
                            offset       =  0x54,
                            bitSize      =  8,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "AdcReg_0x0016",
                            description  = "ADC Control Registers",
                            offset       =  0x58,
                            bitSize      =  8,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )
        
        self.addVariable(   name         = "AdcReg_0x0017",
                            description  = "ADC Control Registers",
                            offset       =  0x5C,
                            bitSize      =  8,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )
        
        self.addVariable(   name         = "AdcReg_0x0018",
                            description  = "ADC Control Registers",
                            offset       =  0x60,
                            bitSize      =  8,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )
        
        self.addVariable(   name         = "AdcReg_0x001F",
                            description  = "ADC Control Registers",
                            offset       =  0x7C,
                            bitSize      =  8,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )
        
        self.addVariable(   name         = "AdcReg_0x0020",
                            description  = "ADC Control Registers",
                            offset       =  0x80,
                            bitSize      =  8,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )

