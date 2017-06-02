#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue AXI-Lite Micron P30 PROM
#-----------------------------------------------------------------------------
# File       : AxiMicronP30.py
# Created    : 2017-04-12
#-----------------------------------------------------------------------------
# Description:
# PyRogue AXI-Lite Micron P30 PROM
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

class AxiMicronP30(pr.Device):
    def __init__(   self,       
                    name        = "AxiMicronP30",
                    description = "AXI-Lite Micron P30 PROM",
                    memBase     =  None,
                    offset      =  0x00,
                    hidden      =  False,
                    expand	    =  True,
                ):
        super(self.__class__, self).__init__(name, description, memBase, offset, hidden, expand=expand)   
        
        ##############################
        # Variables
        ##############################

        self.addVariable(   name         = "WrData",
                            description  = "Write Data",
                            offset       =  0x00,
                            bitSize      =  32,
                            bitOffset    =  0,
                            base         = "hex",
                            mode         = "RW",
                            hidden       =  True,                            
                            verify       =  False,
                        )

        self.addVariable(   name         = "Addr",
                            description  = "Address",
                            offset       =  0x04,
                            bitSize      =  32,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                            hidden       =  True,                            
                            verify       =  False,
                        )

        self.addVariable(   name         = "RdData",
                            description  = "Read Data",
                            offset       =  0x08,
                            bitSize      =  16,
                            bitOffset    =  0,
                            base         = "hex",
                            mode         = "RO",
                            hidden       =  True,                            
                            verify       =  False,
                        )                  
                        
        self.addVariable(   name         = "Test",
                            description  = "Scratch Pad tester register",
                            offset       =  0x0C,
                            bitSize      =  32,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )
                        