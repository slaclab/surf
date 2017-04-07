#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue DMA Ring Buffer Manager
#-----------------------------------------------------------------------------
# File       : AxiStreamDmaRingWrite.py
# Created    : 2017-04-04
#-----------------------------------------------------------------------------
# Description:
# PyRogue DMA Ring Buffer Manager
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

class AxiStreamDmaRingWrite(pr.Device):
    def __init__(self, name="AxiStreamDmaRingWrite", description="DMA Ring Buffer Manager", memBase=None, offset=0x0, hidden=False):
        super(self.__class__, self).__init__(name, description, memBase, offset, hidden)

        ##############################
        # Variables
        ##############################

        for i in range(4):
            self.add(pr.Variable(   name         = "StartAddr_%i" % (i),
                                    description  = "",
                                    offset       =  0x00 + (i * 0x08),
                                    bitSize      =  64,
                                    bitOffset    =  0x00,
                                    base         = "hex",
                                    mode         = "RW",
                                ))

        for i in range(4):
            self.add(pr.Variable(   name         = "EndAddr_%i" % (i),
                                    description  = "",
                                    offset       =  0x200 + (i * 0x08),
                                    bitSize      =  64,
                                    bitOffset    =  0x00,
                                    base         = "hex",
                                    mode         = "RW",
                                ))

        for i in range(4):
            self.add(pr.Variable(   name         = "WrAddr_%i" % (i),
                                    description  = "",
                                    offset       =  0x400 + (i * 0x08),
                                    bitSize      =  64,
                                    bitOffset    =  0x00,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

        for i in range(4):
            self.add(pr.Variable(   name         = "TriggerAddr_%i" % (i),
                                    description  = "",
                                    offset       =  0x600 + (i * 0x08),
                                    bitSize      =  64,
                                    bitOffset    =  0x00,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

        for i in range(4):
            self.add(pr.Variable(   name         = "Enabled_%i" % (i),
                                    description  = "",
                                    offset       =  0x800 + (i * 0x04),
                                    bitSize      =  1,
                                    bitOffset    =  0x00,
                                    base         = "hex",
                                    mode         = "RW",
                                ))

        for i in range(4):
            self.add(pr.Variable(   name         = "Mode_%i" % (i),
                                    description  = "",
                                    offset       =  0x800 + (i * 0x04),
                                    bitSize      =  1,
                                    bitOffset    =  0x01,
                                    base         = "enum",
                                    mode         = "RW",
                                    enum         = {
                                                      0 : "Wrap",
                                                      1 : "DoneWhenFull",
                                                   },
                                ))

        for i in range(4):
            self.add(pr.Variable(   name         = "Init_%i" % (i),
                                    description  = "",
                                    offset       =  0x800 + (i * 0x04),
                                    bitSize      =  1,
                                    bitOffset    =  0x02,
                                    base         = "hex",
                                    mode         = "RW",
                                ))

        for i in range(4):
            self.add(pr.Variable(   name         = "SoftTrigger_%i" % (i),
                                    description  = "",
                                    offset       =  0x800 + (i * 0x04),
                                    bitSize      =  1,
                                    bitOffset    =  0x03,
                                    base         = "hex",
                                    mode         = "RW",
                                ))

        for i in range(4):
            self.add(pr.Variable(   name         = "MsgDest_%i" % (i),
                                    description  = "",
                                    offset       =  0x800 + (i * 0x04),
                                    bitSize      =  4,
                                    bitOffset    =  0x04,
                                    base         = "enum",
                                    mode         = "RW",
                                    enum         = {
                                                      0 : "Software",
                                                      1 : "Auto-Readout",
                                                   },
                                ))

        for i in range(4):
            self.add(pr.Variable(   name         = "FramesAfterTrigger_%i" % (i),
                                    description  = "",
                                    offset       =  0x802 + (i * 0x04),
                                    bitSize      =  16,
                                    bitOffset    =  0x00,
                                    base         = "hex",
                                    mode         = "RW",
                                ))

        for i in range(4):
            self.add(pr.Variable(   name         = "Status_%i" % (i),
                                    description  = "Include all of the status bits in one access",
                                    offset       =  0xA00 + (i * 0x04),
                                    bitSize      =  32,
                                    bitOffset    =  0x00,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

        for i in range(4):
            self.add(pr.Variable(   name         = "Empty_%i" % (i),
                                    description  = "",
                                    offset       =  0xA00 + (i * 0x04),
                                    bitSize      =  1,
                                    bitOffset    =  0x00,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

        for i in range(4):
            self.add(pr.Variable(   name         = "Full_%i" % (i),
                                    description  = "",
                                    offset       =  0xA00 + (i * 0x04),
                                    bitSize      =  1,
                                    bitOffset    =  0x01,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

        for i in range(4):
            self.add(pr.Variable(   name         = "Done_%i" % (i),
                                    description  = "",
                                    offset       =  0xA00 + (i * 0x04),
                                    bitSize      =  1,
                                    bitOffset    =  0x02,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

        for i in range(4):
            self.add(pr.Variable(   name         = "Triggered_%i" % (i),
                                    description  = "",
                                    offset       =  0xA00 + (i * 0x04),
                                    bitSize      =  1,
                                    bitOffset    =  0x03,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

        for i in range(4):
            self.add(pr.Variable(   name         = "Error_%i" % (i),
                                    description  = "",
                                    offset       =  0xA00 + (i * 0x04),
                                    bitSize      =  1,
                                    bitOffset    =  0x04,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

        self.add(pr.Variable(   name         = "BurstSize",
                                description  = "",
                                offset       =  0xA01,
                                bitSize      =  4,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RO",
                            ))

        for i in range(4):
            self.add(pr.Variable(   name         = "FramesSinceTrigger_%i" % (i),
                                    description  = "",
                                    offset       =  0xA02 + (i * 0x04),
                                    bitSize      =  16,
                                    bitOffset    =  0x00,
                                    base         = "hex",
                                    mode         = "RO",
                                ))

        ##############################
        # Commands
        ##############################

        self.add(pr.Command (   name         = "Initialize",
                                description  = "Initialize the buffer. Reset the write pointer to StartAddr. Clear the Done field.",
                                function     = """\
                                               self.Init[0].set(1)
                                               self.Init[1].set(1)
                                               self.Init[2].set(1)
                                               self.Init[3].set(1)
                                               self.Init[0].set(0)
                                               self.Init[1].set(0)
                                               self.Init[2].set(0)
                                               self.Init[3].set(0)
                                               """
                            ))

        self.add(pr.Command (   name         = "C_SoftTrigger",
                                description  = "Send a trigger to the buffer",
                                function     = """\
                                               self.SoftTrigger.set(1)
                                               self.SoftTrigger.set(0)
                                               """
                            ))

        self.add(pr.Command (   name         = "SoftTriggerAll",
                                description  = "Send a trigger to the buffer",
                                function     = """\
                                               self.SoftTrigger.set(1)
                                               """
                            ))

