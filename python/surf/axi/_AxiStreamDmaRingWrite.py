#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue DMA Ring Buffer Manager
#-----------------------------------------------------------------------------
# File       : AxiStreamDmaRingWrite.py
# Created    : 2017-04-12
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
    def __init__(   self,       
            name        = "AxiStreamDmaRingWrite",
            description = "DMA Ring Buffer Manager",
            numBuffers  =  4,
            **kwargs):
        super().__init__(name=name, description=description, **kwargs)  

        self._numBuffers = numBuffers
        
        ##############################
        # Variables
        ##############################

        self.addRemoteVariables(   
            name         = "StartAddr",
            description  = "",
            offset       =  0x00,
            bitSize      =  64,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
            number       =  numBuffers,
            stride       =  8,
        )

        self.addRemoteVariables(   
            name         = "EndAddr",
            description  = "",
            offset       =  0x200,
            bitSize      =  64,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
            number       =  numBuffers,
            stride       =  8,
        )

        self.addRemoteVariables(   
            name         = "WrAddr",
            description  = "",
            offset       =  0x400,
            bitSize      =  64,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
            number       =  numBuffers,
            stride       =  8,
        )

        self.addRemoteVariables(   
            name         = "TriggerAddr",
            description  = "",
            offset       =  0x600,
            bitSize      =  64,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
            number       =  numBuffers,
            stride       =  8,
        )

        self.addRemoteVariables(   
            name         = "Enabled",
            description  = "",
            offset       =  0x800,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
            number       =  numBuffers,
            stride       =  4,
        )
 
        self.addRemoteVariables(   
            name         = "Mode",
                description  = "",
                offset       =  0x800,
                bitSize      =  1,
                bitOffset    =  0x01,
                mode         = "RW",
                number       =  numBuffers,
                stride       =  4,
                enum         = {
                    0 : "Wrap",
                    1 : "DoneWhenFull",
                },
            )

        self.addRemoteVariables(   
            name         = "Init",
            description  = "",
            offset       =  0x800,
            bitSize      =  1,
            bitOffset    =  0x02,
            base         = pr.UInt,
            mode         = "RW",
            number       =  numBuffers,
            stride       =  4,
        )

        self.addRemoteVariables(   
            name         = "SoftTrigger",
            description  = "",
            offset       =  0x800,
            bitSize      =  1,
            bitOffset    =  0x03,
            base         = pr.UInt,
            mode         = "RW",
            number       =  numBuffers,
            stride       =  4,
        )

        self.addRemoteVariables(   
            name         = "MsgDest",
            description  = "",
            offset       =  0x800,
            bitSize      =  4,
            bitOffset    =  0x04,
            mode         = "RW",
            number       =  numBuffers,
            stride       =  4,
            enum         = {
                0 : "Software",
                1 : "Auto-Readout",
            },
        )

        self.addRemoteVariables(   
            name         = "FramesAfterTrigger",
            description  = "",
            offset       =  0x800,
            bitSize      =  16,
            bitOffset    =  16,
            base         = pr.UInt,
            mode         = "RW",
            number       =  numBuffers,
            stride       =  4,
        )

        self.addRemoteVariables(   
            name         = "Status",
            description  = "Include all of the status bits in one access",
            offset       =  0xA00,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
            number       =  numBuffers,
            stride       =  4,
            overlapEn    = True,
        )

        self.addRemoteVariables(   
            name         = "Empty",
            description  = "",
            offset       =  0xA00,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
            number       =  numBuffers,
            stride       =  4,
            overlapEn    = True,
        )

        self.addRemoteVariables(   
            name         = "Full",
            description  = "",
            offset       =  0xA00,
            bitSize      =  1,
            bitOffset    =  0x01,
            base         = pr.UInt,
            mode         = "RO",
            number       =  numBuffers,
            stride       =  4,
            overlapEn    = True,
        )

        self.addRemoteVariables(   
            name         = "Done",
            description  = "",
            offset       =  0xA00,
            bitSize      =  1,
            bitOffset    =  0x02,
            base         = pr.UInt,
            mode         = "RO",
            number       =  numBuffers,
            stride       =  4,
            overlapEn    = True,
        )

        self.addRemoteVariables(   
            name         = "Triggered",
            description  = "",
            offset       =  0xA00,
            bitSize      =  1,
            bitOffset    =  0x03,
            base         = pr.UInt,
            mode         = "RO",
            number       =  numBuffers,
            stride       =  4,
            overlapEn    = True,
        )

        self.addRemoteVariables(   
            name         = "Error",
            description  = "",
            offset       =  0xA00,
            bitSize      =  1,
            bitOffset    =  0x04,
            base         = pr.UInt,
            mode         = "RO",
            number       =  numBuffers,
            stride       =  4,
            overlapEn    = True,
        )

        self.add(pr.RemoteVariable(    
            name         = "BurstSize",
            description  = "",
            offset       =  0xA00,
            bitSize      =  4,
            bitOffset    =  8,
            base         = pr.UInt,
            mode         = "RO",
            overlapEn    = True,
        ))

        self.addRemoteVariables(   
            name         = "FramesSinceTrigger",
            description  = "",
            offset       =  0xA00,
            bitSize      =  16,
            bitOffset    =  16,
            base         = pr.UInt,
            mode         = "RO",
            number       =  numBuffers,
            stride       =  4,
            overlapEn    = True,
        )

        ##############################
        # Commands
        ##############################
        @self.command(name="Initialize", description="Initialize the buffer. Reset the write pointer to StartAddr. Clear the Done field.",)
        def Initialize():
            for i in range(self._numBuffers):
                self.Init[i].set(1)
                self.Init[i].set(0)       

        @self.command(name="SoftTriggerAll", description="Send a trigger to the buffer",)
        def SoftTriggerAll():
            for i in range(self._numBuffers):
                self.SoftTrigger[i].set(1)
                self.SoftTrigger[i].set(0)                       
                
