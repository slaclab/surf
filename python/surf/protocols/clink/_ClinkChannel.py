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
            offset       =  0x00,
            bitSize      =  3,
            bitOffset    =  0,
            mode         = "RW",
            enum         = { 0 : 'Disable' , 1 : 'Base', 2 : 'Medium', 3 : 'Full', 4 : 'Deca'},
            description = """
                Link mode control for camera link lanes:
                Disable: Nothing connected
                Base: Port Supported [A,B,C], # of chips = 1, # of connectors = 1
                Medium: Port Supported [A,B,C,D,E,F], # of chips = 2, # of connectors = 2
                Full: Port Supported [A,B,C,D,E,F,G,H], # of chips = 3, # of connectors = 3
                Deca: Refer to section /"2.2.3 Camera Link 80 bit/" CameraLink spec V2.0, page 16
                """,
        ))

        self.add(pr.RemoteVariable(    
            name         = "DataMode",
            description  = "Data mode",
            offset       =  0x04,
            bitSize      =  4,
            bitOffset    =  0,
            mode         = "RW",
            enum         = { 0 : 'None',  1 : '8Bit',  2 : '10Bit', 3 : '12Bit', 4 : '14Bit', 
                             5 : '16Bit', 6 : '24Bit', 7 : '30Bit', 8 : '36Bit'},
        ))

        self.add(pr.RemoteVariable(    
            name         = "FrameMode",
            offset       =  0x08,
            bitSize      =  2,
            bitOffset    =  0,
            mode         = "RW",
            enum         = { 0 : 'None', 1 : 'Line', 2 : 'Frame'},
            description = """
                None: Disables output
                Line: 1D camera
                Frame" 2D pixel array
                """,            
        ))

        self.add(pr.RemoteVariable(    
            name         = "TapCount",
            description  = "# of video output taps on the Camera Link Interface (# of individual data value channels)",
            offset       =  0x0C,
            bitSize      =  4,
            bitOffset    =  0,
            minimum      = 0,
            maximum      = 10,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "DataEn",
            description  = "Data enable.  When 0x0 causes reset on ClinkData\'s FSM module",
            offset       =  0x10,
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.Bool,
            mode         = "RW",
        ))
        
        self.add(pr.RemoteVariable(    
            name         = "Blowoff",
            description  = "Blows off the outbound AXIS stream (for debugging)",
            offset       =  0x10,
            bitSize      =  1,
            bitOffset    =  1,
            base         = pr.Bool,
            mode         = "RW",
        ))    

        self.add(pr.RemoteVariable(    
            name         = "SerThrottle",
            description  = "Throttles the UART Serial TX byte rate. Used when the camera cannot accept new bytes until the previous command processed",
            offset       =  0x10,
            bitSize      =  16,
            bitOffset    =  16,
            mode         = "RW",
            units        = "microsec",
        ))            

        self.add(pr.RemoteVariable(    
            name         = "BaudRate",
            description  = "Baud rate",
            offset       =  0x14,
            bitSize      =  24,
            bitOffset    =  0,
            disp         = '{}',
            mode         = "RW",
            units        = "bps",
        ))
        
        self.add(pr.RemoteVariable(    
            name         = "SwControlValue",
            description  = "Software camera control bit values",
            offset       =  0x18,
            bitSize      =  4,
            bitOffset    =  0,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "SwControlEn",
            description  = "Software camera control bit enable mask for lane A",
            offset       =  0x1C,
            bitSize      =  4,
            bitOffset    =  0,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "Running",
            description  = "Camera link lane running status",
            offset       =  0x20,
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.Bool,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(    
            name         = "FrameCount",
            description  = "Frame counter",
            offset       =  0x24,
            bitSize      =  32,
            bitOffset    =  0,
            disp         = '{}',
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(    
            name         = "DropCount",
            description  = "Drop counter",
            offset       =  0x28,
            bitSize      =  32,
            bitOffset    =  0,
            disp         = '{}',
            mode         = "RO",
            pollInterval = 1,
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

