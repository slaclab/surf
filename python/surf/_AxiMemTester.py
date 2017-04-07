#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue AXI4 Memory Tester Module
#-----------------------------------------------------------------------------
# File       : AxiMemTester.py
# Created    : 2017-04-04
#-----------------------------------------------------------------------------
# Description:
# PyRogue AXI4 Memory Tester Module
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

class AxiMemTester(pr.Device):
    def __init__(self, name="AxiMemTester", description="AXI4 Memory Tester Module", memBase=None, offset=0x0, hidden=False):
        super(self.__class__, self).__init__(name, description, memBase, offset, hidden)

        ##############################
        # Variables
        ##############################

        self.add(pr.Variable(   name         = "Passed",
                                description  = "Passed Memory Test",
                                offset       =  0x100,
                                bitSize      =  1,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "Failed",
                                description  = "Failed Memory Test",
                                offset       =  0x104,
                                bitSize      =  1,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "WriteTimer",
                                description  = "Write Timer",
                                offset       =  0x108,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "ReadTimer",
                                description  = "Read Timer",
                                offset       =  0x10C,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "StartAddress",
                                description  = "Start Address",
                                offset       =  0x110,
                                bitSize      =  64,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "StopAddress",
                                description  = "Stop Address",
                                offset       =  0x118,
                                bitSize      =  64,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "ADDR_WIDTH_C",
                                description  = "AXI4 Address Bus Width (units of bits)",
                                offset       =  0x120,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "DATA_BYTES_C",
                                description  = "AXI4 Data Bus Width (units of bits)",
                                offset       =  0x124,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "ID_BITS_C",
                                description  = "AXI4 ID Bus Width (units of bits)",
                                offset       =  0x128,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

