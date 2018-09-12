#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue CameraLink Channel
#-----------------------------------------------------------------------------
# File       : ClinkChannel.py
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

class ClinkChannel(pr.Device):
    def __init__(   self,       
            name        = "ClinkChannel",
            description = "CameraLink channel",
            serial      = None,
            **kwargs):
        super().__init__(name=name, description=description, **kwargs) 

        ##############################
        # Variables
        ##############################

        self.add(pr.RemoteVariable(    
            name         = "LinkMode",
            description  = "Link mode control for camera link lanes",
            offset       =  0x00,
            bitSize      =  3,
            bitOffset    =  0,
            base         = pr.UInt,
            enum         = { 0 : 'Disable' , 1 : 'Base', 2 : 'Medium', 3 : 'Full', 4 : 'Deca'},
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "DataMode",
            description  = "Data mode",
            offset       =  0x04,
            bitSize      =  4,
            bitOffset    =  0,
            base         = pr.UInt,
            enum         = { 0 : 'None',  1 : '8Bit',  2 : '10Bit', 3 : '12Bit', 4 : '14Bit', 
                             5 : '16Bit', 6 : '24Bit', 7 : '30Bit', 8 : '36Bit'},
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "FrameMode",
            description  = "Frame mode",
            offset       =  0x08,
            bitSize      =  2,
            bitOffset    =  0,
            base         = pr.UInt,
            enum         = { 0 : 'None', 1 : 'Line', 2 : 'Frame'},
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "TapCount",
            description  = "Frame mode",
            offset       =  0x0C,
            bitSize      =  4,
            bitOffset    =  0,
            minimum      = 0,
            maximum      = 10,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "DataEn",
            description  = "Data enable",
            offset       =  0x10,
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.Bool,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "BaudRate",
            description  = "Baud rate",
            offset       =  0x14,
            bitSize      =  24,
            bitOffset    =  0,
            disp         = '{}',
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "SwControlValue",
            description  = "Software camera control bit values",
            offset       =  0x18,
            bitSize      =  4,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "SwControlEn",
            description  = "Software camera control bit enable mask for lane A",
            offset       =  0x1C,
            bitSize      =  4,
            bitOffset    =  0,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "Running",
            description  = "Camera link lane running status",
            offset       =  0x20,
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.Bool,
            pollInterval = 1,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "FrameCount",
            description  = "Frame counter",
            offset       =  0x24,
            bitSize      =  32,
            bitOffset    =  0,
            base         = pr.UInt,
            disp         = '{}',
            pollInterval = 1,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "DropCount",
            description  = "Drop counter",
            offset       =  0x28,
            bitSize      =  32,
            bitOffset    =  0,
            base         = pr.UInt,
            disp         = '{}',
            pollInterval = 1,
            mode         = "RO",
        ))

        self._rx = None
        self._tx = None

        if serial is not None:
            self._rx = surf.protocols.clink.ClinkSerialRx()
            pr.streamConnect(serial,self._rx)

            self._tx = surf.protocols.clink.ClinkSerialTx()
            pr.streamConnect(self._tx,serial)

        @self.command(value='', name='SendString', description='Send a command string')
        def sendString(arg):
            if self._tx is not None:
                self._tx.sendString(arg)

        @self.command(name='SendEscape', description='Send an escape charactor')
        def sendEscape():
            if self._tx is not None:
                self._tx.sendEscape()

        @self.command(name='SendGcp', description='Send gcp command')
        def sendGcp():
            if self._tx is not None:
                self._tx.sendString("gcp")

