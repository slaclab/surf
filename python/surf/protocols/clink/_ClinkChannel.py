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

import pyrogue              as pr
import surf.protocols.clink as cl

class ClinkChannel(pr.Device):
    def __init__(   self,       
            name        = "ClinkChannel",
            description = "CameraLink channel",
            serial      = None,
            camType     = None,
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

        self.add(pr.RemoteCommand(    
            name         = "CntRst",
            description  = "",
            offset       = 0x10,
            bitSize      = 1,
            bitOffset    = 2,
            function     = pr.BaseCommand.toggle,
        ))          

        self.add(pr.RemoteVariable(    
            name         = "SerThrottle",
            description  = "Throttles the UART Serial TX byte rate. Used when the camera cannot accept new bytes until the previous command processed",
            offset       =  0x10,
            bitSize      =  16,
            bitOffset    =  16,
            disp         = '{}',
            mode         = "RW",
            units        = "microsec",
            value        = 30000, # 30ms/byte
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
            value        = 9600,
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
        
        ##############################################################################

        self._rx = None
        self._tx = None
        
        # Check if serial interface defined
        if serial is not None:
        
            # Check for OPA1000 camera
            if (camType=='Opal000'):
                
                # Override defaults
                self.BaudRate._default    = 57600
            
                # Add the device
                self.add(cl.UartOpal000(      
                    name   = 'UartOpal000', 
                    serial = serial,
                    expand = False,
                ))
                
            # Check for Piranha4 camera
            elif (camType=='Piranha4'):
            
                # Add the device
                self.add(cl.UartPiranha4(      
                    name        = 'UartPiranha4', 
                    serial      = serial,
                    expand      = False,
                ))      
                
            # Check for Uniq UP-900CL-12B camera
            elif (camType=='Up900cl12b'):

                # Override defaults
                self.SerThrottle._default = 30000
            
                # Add the device
                self.add(cl.UartUp900cl12b(      
                    name        = 'UartUp900cl12b', 
                    serial      = serial,
                    expand      = False,
                ))
                
            # Else generic interface to serial stream
            elif camType is None:
                
                # Add the device
                self.add(cl.UartGeneric(      
                    name        = 'UartGeneric', 
                    serial      = serial,
                    expand      = False,
                ))              
                
            else:
                raise ValueError('Invalid camType (%s)' % (camType) )                
        ##############################################################################
        
    def hardReset(self):
        self.CntRst()

    def softReset(self):
        self.CntRst()

    def countReset(self):
        self.CntRst()
        