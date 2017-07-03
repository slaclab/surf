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
        memBase     =  None,
        offset      =  0x00,
        numBuffers  =  4,
        hidden      =  False,
        expand      =  True,
    ):
        super().__init__(
            name        = name,
            description = description,
            memBase     = memBase,
            offset      = offset,
            hidden      = hidden,
            expand      = expand,
        )  

        self._numBuffers = numBuffers
        
        ##############################
        # Variables
        ##############################

        self.addVariables(  
            name         = "StartAddr",
            description  = "",
            offset       =  0x00,
            bitSize      =  64,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
            number       =  numBuffers,
            stride       =  8,
        )

        self.addVariables(  
            name         = "EndAddr",
            description  = "",
            offset       =  0x200,
            bitSize      =  64,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
            number       =  numBuffers,
            stride       =  8,
        )

        self.addVariables(  
            name         = "WrAddr",
            description  = "",
            offset       =  0x400,
            bitSize      =  64,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
            number       =  numBuffers,
            stride       =  8,
        )

        self.addVariables(  
            name         = "TriggerAddr",
            description  = "",
            offset       =  0x600,
            bitSize      =  64,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
            number       =  numBuffers,
            stride       =  8,
        )

        self.addVariables(  
            name         = "Enabled",
            description  = "",
            offset       =  0x800,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
            number       =  numBuffers,
            stride       =  4,
        )
 
        self.addVariables(  
            name         = "Mode",
                description  = "",
                offset       =  0x800,
                bitSize      =  1,
                bitOffset    =  0x01,
                base         = "enum",
                mode         = "RW",
                number       =  numBuffers,
                stride       =  4,
                enum         = {
                    0 : "Wrap",
                    1 : "DoneWhenFull",
                },
            )

        self.addVariables(  
            name         = "Init",
            description  = "",
            offset       =  0x800,
            bitSize      =  1,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
            number       =  numBuffers,
            stride       =  4,
        )

        self.addVariables(  
            name         = "SoftTrigger",
            description  = "",
            offset       =  0x800,
            bitSize      =  1,
            bitOffset    =  0x03,
            base         = "hex",
            mode         = "RW",
            number       =  numBuffers,
            stride       =  4,
        )

        self.addVariables(  
            name         = "MsgDest",
            description  = "",
            offset       =  0x800,
            bitSize      =  4,
            bitOffset    =  0x04,
            base         = "enum",
            mode         = "RW",
            number       =  numBuffers,
            stride       =  4,
            enum         = {
                0 : "Software",
                1 : "Auto-Readout",
            },
        )

        self.addVariables(  
            name         = "FramesAfterTrigger",
            description  = "",
            offset       =  0x800,
            bitSize      =  16,
            bitOffset    =  16,
            base         = "hex",
            mode         = "RW",
            number       =  numBuffers,
            stride       =  4,
        )

        self.addVariables(  
            name         = "Status",
            description  = "Include all of the status bits in one access",
            offset       =  0xA00,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
            number       =  numBuffers,
            stride       =  4,
        )

        self.addVariables(  
            name         = "Empty",
            description  = "",
            offset       =  0xA00,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
            number       =  numBuffers,
            stride       =  4,
        )

        self.addVariables(  
            name         = "Full",
            description  = "",
            offset       =  0xA00,
            bitSize      =  1,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RO",
            number       =  numBuffers,
            stride       =  4,
        )

        self.addVariables(  
            name         = "Done",
            description  = "",
            offset       =  0xA00,
            bitSize      =  1,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RO",
            number       =  numBuffers,
            stride       =  4,
        )

        self.addVariables(  
            name         = "Triggered",
            description  = "",
            offset       =  0xA00,
            bitSize      =  1,
            bitOffset    =  0x03,
            base         = "hex",
            mode         = "RO",
            number       =  numBuffers,
            stride       =  4,
        )

        self.addVariables(  
            name         = "Error",
            description  = "",
            offset       =  0xA00,
            bitSize      =  1,
            bitOffset    =  0x04,
            base         = "hex",
            mode         = "RO",
            number       =  numBuffers,
            stride       =  4,
        )

        self.addVariable(   
            name         = "BurstSize",
            description  = "",
            offset       =  0xA00,
            bitSize      =  4,
            bitOffset    =  8,
            base         = "hex",
            mode         = "RO",
        )

        self.addVariables(  
            name         = "FramesSinceTrigger",
            description  = "",
            offset       =  0xA00,
            bitSize      =  16,
            bitOffset    =  16,
            base         = "hex",
            mode         = "RO",
            number       =  numBuffers,
            stride       =  4,
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
                