#-----------------------------------------------------------------------------
# Title      : PyRogue DMA Ring Buffer Manager
#-----------------------------------------------------------------------------
# Description:
# PyRogue DMA Ring Buffer Manager
#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr

class AxiStreamDmaRingWrite(pr.Device):
    def __init__(self, numBuffers=4, **kwargs):
        super().__init__(**kwargs)

        self._numBuffers = numBuffers

        ##############################
        # Variables
        ##############################

        self.addRemoteVariables(
            name         = "StartAddr",
            description  = "Ring buffer start address",
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
            description  = "Ring buffer end address",
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
            description  = "Current DMA write pointer address",
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
            description  = "Address at which trigger event was captured",
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
            description  = "Enable DMA ring buffer capture",
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
            description  = "Ring buffer wrap mode (wrap around or stop when full)",
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
            description  = "Initialize buffer: reset write pointer to StartAddr and clear Done",
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
            description  = "Software trigger to stop ring buffer capture",
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
            description  = "Destination for done notification (software or auto-readout)",
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
            description  = "Number of frames to capture after trigger event",
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
            description  = "Ring buffer is empty (no data written since last init)",
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
            description  = "Ring buffer has wrapped around or filled completely",
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
            description  = "DMA ring buffer capture complete",
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
            description  = "Trigger event has been received for this buffer",
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
            description  = "DMA transfer error flag",
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
            name        = "BurstSize",
            description = "AXI burst size used for DMA ring buffer transfers",
            offset      =  0xA00,
            bitSize     =  4,
            bitOffset   =  8,
            base        = pr.UInt,
            mode        = "RO",
            overlapEn   = True,
        ))

        self.addRemoteVariables(
            name         = "FramesSinceTrigger",
            description  = "Number of frames captured since the last trigger event",
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
