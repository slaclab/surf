#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue AXI-Lite Version Module
#-----------------------------------------------------------------------------
# File       : AxiVersion.py
# Created    : 2017-04-04
#-----------------------------------------------------------------------------
# Description:
# PyRogue AXI-Lite Version Module
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

class AxiVersion(pr.Device):
    def __init__(self, name="AxiVersion", description="AXI-Lite Version Module", memBase=None, offset=0x0, hidden=False):
        super(self.__class__, self).__init__(name, description, memBase, offset, hidden)

        ##############################
        # Variables
        ##############################

        self.add(pr.Variable(   name         = "FpgaVersion",
                                description  = "FPGA Firmware Version Number",
                                offset       =  0x00,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "ScratchPad",
                                description  = "Register to test reads and writes",
                                offset       =  0x04,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "UpTimeCnt",
                                description  = "Number of seconds since last reset",
                                offset       =  0x08,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "FpgaReloadHalt",
                                description  = "Used to halt automatic reloads via AxiVersion",
                                offset       =  0x100,
                                bitSize      =  1,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "FpgaReload",
                                description  = "Optional Reload the FPGA from the attached PROM",
                                offset       =  0x104,
                                bitSize      =  1,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "FpgaReloadAddress",
                                description  = "Reload start address",
                                offset       =  0x108,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "MasterReset",
                                description  = "Optional User Reset",
                                offset       =  0x10C,
                                bitSize      =  1,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "WO",
                            ))

        self.add(pr.Variable(   name         = "FdSerial",
                                description  = "Board ID value read from DS2411 chip",
                                offset       =  0x300,
                                bitSize      =  64,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        for i in range(64):
            self.add(pr.Variable(   name         = "UserConstants_%.*i" % (2, i),
                                    description  = "Optional user input values. Constant %.*i" % (2, i),
                                    offset       =  0x400 + (0x04*i),
                                    bitSize      =  32,
                                    bitOffset    =  0x00,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

        self.add(pr.Variable(   name         = "DeviceId",
                                description  = "Device Identification  (configued by generic)",
                                offset       =  0x500,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "GitHash",
                                description  = "GIT SHA-1 Hash",
                                offset       =  0x600,
                                bitSize      =  160,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "DeviceDna",
                                description  = "Xilinx Device DNA value burned into FPGA",
                                offset       =  0x700,
                                bitSize      =  128,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        self.add(pr.Variable(   name         = "BuildStamp",
                                description  = "Firmware Build String",
                                offset       =  0x800,
                                bitSize      =  8*256,
                                bitOffset    =  0x00,
                                base         = "string",
                                mode         = "RO",
                            ))