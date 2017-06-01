#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue AXI-Lite Micron N25Q and Micron MT25Q PROM
#-----------------------------------------------------------------------------
# File       : AxiMicronN25Q.py
# Created    : 2017-04-12
#-----------------------------------------------------------------------------
# Description:
# PyRogue AXI-Lite Micron N25Q and Micron MT25Q PROM
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

class AxiMicronN25Q(pr.Device):
    def __init__(   self,       
                    name        = "AxiMicronN25Q",
                    description = "AXI-Lite Micron N25Q and Micron MT25Q PROM",
                    memBase     =  None,
                    offset      =  0x00,
                    hidden      =  False,
                    expand	    =  True,
                ):
        super(self.__class__, self).__init__(name, description, memBase, offset, hidden, expand=expand)  

        ##############################
        # Variables
        ##############################

        self.addVariable(   name         = "Test",
                            description  = "Scratch Pad tester register",
                            offset       =  0x00,
                            bitSize      =  32,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                        )

        self.addVariable(   name         = "Addr32BitMode",
                            description  = "Enable 32-bit PROM mode",
                            offset       =  0x04,
                            bitSize      =  1,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                            hidden       =  True,
                        )

        self.addVariable(   name         = "Addr",
                            description  = "Address Register",
                            offset       =  0x08,
                            bitSize      =  32,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                            hidden       =  True,
                        )

        self.addVariable(   name         = "Cmd",
                            description  = "Command Register",
                            offset       =  0x0C,
                            bitSize      =  32,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                            hidden       =  True,
                        )

        self.addVariables(  name         = "Data",
                            description  = "Data Register Array",
                            offset       =  0x200,
                            bitSize      =  32,
                            bitOffset    =  0x00,
                            base         = "hex",
                            mode         = "RW",
                            number       =  64,
                            stride       =  4,
                            hidden       =  True,
                        )

