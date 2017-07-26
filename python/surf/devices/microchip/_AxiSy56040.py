#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue AXI-Lite Microchip SY56040 and Microchip SY58040
#-----------------------------------------------------------------------------
# File       : AxiSy56040.py
# Created    : 2017-04-12
#-----------------------------------------------------------------------------
# Description:
# PyRogue AXI-Lite Microchip SY56040 and Microchip SY58040
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

class AxiSy56040(pr.Device):
    def __init__(self,       
            name        = "AxiSy56040",
            description = "AXI-Lite Microchip SY56040 and Microchip SY58040",
            **kwargs):
        super().__init__(name=name, description=description, **kwargs) 

        ##############################
        # Variables
        ##############################

        self.addRemoteVariables( 
            name         = "OutputConfig",
            description  = "Output Configuration Register Array",
            offset       =  0x00,
            bitSize      =  2,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
            number       =  4,
            stride       =  4,
        )

