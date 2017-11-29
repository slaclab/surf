#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue CameraLink module
#-----------------------------------------------------------------------------
# File       : ClinkTop.py
# Created    : 2017-11-21
#-----------------------------------------------------------------------------
# Description:
# PyRogue CameraLink module
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
import surf.protocols.clink

class ClinkTop(pr.Device):
    def __init__(   self,       
            name        = "ClinkTop",
            description = "CameraLink module",
            serial      = None,
            **kwargs):
        super().__init__(name=name, description=description, **kwargs) 

        ##############################
        # Variables
        ##############################

        self.add(pr.RemoteVariable(    
            name         = "LinkMode",
            description  = "Link mode control for camera link lanes",
            offset       =  0x10,
            bitSize      =  4,
            bitOffset    =  0x00,
            base         = pr.UInt,
            enum         = { 0 : 'Disable' , 1 : 'Base', 2 : 'Medium', 3 : 'Full', 4 : 'Deca'},
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "DataModeA",
            description  = "Data mode for lane A",
            offset       =  0x10,
            bitSize      =  4,
            bitOffset    =  8,
            base         = pr.UInt,
            enum         = { 0 : 'None', 1 : '8Bit', 2 : '10Bit', 3 : '12Bit'},
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "DataModeB",
            description  = "Data mode for lane B",
            offset       =  0x10,
            bitSize      =  4,
            bitOffset    =  16,
            base         = pr.UInt,
            enum         = { 0 : 'None', 1 : '8Bit', 2 : '10Bit', 3 : '12Bit'},
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "DataEnA",
            description  = "Data enable for lane A",
            offset       =  0x10,
            bitSize      =  1,
            bitOffset    =  24,
            base         = pr.Bool,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "DataEnB",
            description  = "Data enable for lane A",
            offset       =  0x10,
            bitSize      =  1,
            bitOffset    =  25,
            base         = pr.Bool,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "BaudRateA",
            description  = "Baud rate for lane A",
            offset       =  0x18,
            bitSize      =  24,
            bitOffset    =  0,
            disp         = '{}',
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "BaudRateB",
            description  = "Baud rate for lane B",
            offset       =  0x1C,
            bitSize      =  24,
            bitOffset    =  0,
            disp         = '{}',
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "LinkLocked",
            description  = "Camera link channel locked status",
            offset       =  0x20,
            bitSize      =  3,
            bitOffset    =  0,
            base         = pr.UInt,
            pollInterval = 1,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "Running",
            description  = "Camera link lane running status",
            offset       =  0x20,
            bitSize      =  2,
            bitOffset    =  4,
            base         = pr.UInt,
            pollInterval = 1,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "ShiftCountA",
            description  = "Shift count for channel",
            offset       =  0x24,
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            pollInterval = 1,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "ShiftCountB",
            description  = "Shift count for channel",
            offset       =  0x24,
            bitSize      =  8,
            bitOffset    =  8,
            base         = pr.UInt,
            pollInterval = 1,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "ShiftCountC",
            description  = "Shift count for channel",
            offset       =  0x24,
            bitSize      =  8,
            bitOffset    =  16,
            base         = pr.UInt,
            pollInterval = 1,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "FrameCountA",
            description  = "Lane A frame counter",
            offset       =  0x30,
            bitSize      =  32,
            bitOffset    =  0,
            base         = pr.UInt,
            disp         = '{}',
            pollInterval = 1,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "FrameCountB",
            description  = "Lane B frame counter",
            offset       =  0x34,
            bitSize      =  32,
            bitOffset    =  0,
            base         = pr.UInt,
            disp         = '{}',
            pollInterval = 1,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "DropCountA",
            description  = "Lane A frame counter",
            offset       =  0x38,
            bitSize      =  32,
            bitOffset    =  0,
            base         = pr.UInt,
            disp         = '{}',
            pollInterval = 1,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "DropCountB",
            description  = "Lane B frame counter",
            offset       =  0x3C,
            bitSize      =  32,
            bitOffset    =  0,
            base         = pr.UInt,
            disp         = '{}',
            pollInterval = 1,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "SwControlValueA",
            description  = "Software camera control bit values for lane A",
            offset       =  0x40,
            bitSize      =  4,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "SwControlValueB",
            description  = "Software camera control bit values for lane B",
            offset       =  0x40,
            bitSize      =  4,
            bitOffset    =  4,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "SwControlEnA",
            description  = "Software camera control bit enable mask for lane A",
            offset       =  0x40,
            bitSize      =  4,
            bitOffset    =  8,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "SwControlEnB",
            description  = "Software camera control bit enable mask for lane B",
            offset       =  0x40,
            bitSize      =  4,
            bitOffset    =  12,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self._rx = None
        self._tx = None

        if serial is not None:
            self._rx = surf.protocols.clink.ClinkSerialRx()
            pr.streamConnect(serial,self._rx)

            self._tx = surf.protocols.clink.ClinkSerialTx()
            pr.streamConnect(self._tx,serial)

    @pr.command(order=1, value='', name='SendString', description='Send a command string')
    def sendString(self, arg):
        if self._tx is not None:
            self._tx.sendString(arg)

    @pr.command(order=2, name='SendEscape', description='Send an escape charactor')
    def sendEscape(self):
        if self._tx is not None:
            self._tx.sendEscape()

    @pr.command(order=3, name='SendGcp', description='Send gcp command')
    def sendGcp(self):
        if self._tx is not None:
            self._tx.sendString("gcp")

