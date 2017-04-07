#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue AXI-Lite Micron P30 PROM
#-----------------------------------------------------------------------------
# File       : AxiMicronP30.py
# Created    : 2017-04-04
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
    def __init__(self, name="AxiMicronP30", description="AXI-Lite Micron P30 PROM", memBase=None, offset=0x0, hidden=False):
        super(self.__class__, self).__init__(name, description, memBase, offset, hidden)

        ##############################
        # Variables
        ##############################

        self.add(pr.Variable(   name         = "WrData",
                                description  = "Write Data",
                                offset       =  0x00,
                                bitSize      =  16,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "WrCmd",
                                description  = "Write Command",
                                offset       =  0x02,
                                bitSize      =  16,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "Address",
                                description  = "Read/Write Address",
                                offset       =  0x04,
                                bitSize      =  31,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "RnW",
                                description  = "Read/Write operation bit",
                                offset       =  0x07,
                                bitSize      =  1,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "RdData",
                                description  = "Read Data",
                                offset       =  0x08,
                                bitSize      =  16,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "Test",
                                description  = "Scratch Pad tester register",
                                offset       =  0x0C,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

