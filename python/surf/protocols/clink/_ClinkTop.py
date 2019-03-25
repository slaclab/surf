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

import pyrogue              as pr
import surf.protocols.clink as cl

class ClinkTop(pr.Device):
    def __init__(   self,       
            name        = "ClinkTop",
            description = "CameraLink module",
            serial      = [None,None],
            camType     = [None,None],
            **kwargs):
        super().__init__(name=name, description=description, **kwargs) 

        ##############################
        # Variables
        ##############################

        self.add(pr.RemoteVariable(    
            name         = "ChanCount",
            description  = "Supported channels",
            offset       =  0x00,
            bitSize      =  4,
            bitOffset    =  0x00,
            mode         = "RO",
        ))

        self.add(pr.RemoteCommand(   
            name         = "ResetPll",
            description  = "Camera link channel PLL reset",
            offset       =  0x04,
            bitSize      =  1,
            bitOffset    =  0,
            function     = pr.BaseCommand.toggle,
        ))   

        self.add(pr.RemoteCommand(   
            name         = "ResetFsm",
            description  = "Camera link channel FSM reset",
            offset       =  0x04,
            bitSize      =  1,
            bitOffset    =  1,
            function     = pr.BaseCommand.toggle,
        ))           
        
        self.add(pr.RemoteCommand(    
            name         = "CntRst",
            description  = "",
            offset       = 0x04,
            bitSize      = 1,
            bitOffset    = 2,
            function     = pr.BaseCommand.toggle,
        ))         
     
        self.add(pr.RemoteVariable(    
            name         = "LinkLockedA",
            description  = "Camera link channel locked status",
            offset       =  0x10,
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.Bool,
            pollInterval = 1,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "LinkLockedB",
            description  = "Camera link channel locked status",
            offset       =  0x10,
            bitSize      =  1,
            bitOffset    =  1,
            base         = pr.Bool,
            pollInterval = 1,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "LinkLockedC",
            description  = "Camera link channel locked status",
            offset       =  0x10,
            bitSize      =  1,
            bitOffset    =  2,
            base         = pr.Bool,
            pollInterval = 1,
            mode         = "RO",
        ))
        
        self.add(pr.RemoteVariable(    
            name         = "LinkLockedCntA",
            description  = "Camera link channel locked status counter",
            offset       =  0x10,
            bitSize      =  8,
            bitOffset    =  8,
            disp         = '{}',
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(    
            name         = "LinkLockedCntB",
            description  = "Camera link channel locked status counter",
            offset       =  0x10,
            bitSize      =  8,
            bitOffset    =  16,
            disp         = '{}',
            mode         = "RO",
            pollInterval = 1,
        ))  

        self.add(pr.RemoteVariable(    
            name         = "LinkLockedCntC",
            description  = "Camera link channel locked status counter",
            offset       =  0x10,
            bitSize      =  8,
            bitOffset    =  24,
            disp         = '{}',
            mode         = "RO",
            pollInterval = 1,
        ))          
        
        self.add(pr.RemoteVariable(    
            name         = "ShiftCountA",
            description  = "Shift count for channel",
            offset       =  0x14,
            bitSize      =  3,
            bitOffset    =  0,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(    
            name         = "ShiftCountB",
            description  = "Shift count for channel",
            offset       =  0x14,
            bitSize      =  3,
            bitOffset    =  8,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(    
            name         = "ShiftCountC",
            description  = "Shift count for channel",
            offset       =  0x14,
            bitSize      =  3,
            bitOffset    =  16,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(    
            name         = "DelayA",
            description  = "Precision delay for channel A",
            offset       =  0x18,
            bitSize      =  5,
            bitOffset    =  0,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(    
            name         = "DelayB",
            description  = "Precision delay for channel B",
            offset       =  0x18,
            bitSize      =  5,
            bitOffset    =  8,
            mode         = "RO",
            pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(    
            name         = "DelayC",
            description  = "Precision delay for channel C",
            offset       =  0x18,
            bitSize      =  5,
            bitOffset    =  16,
            mode         = "RO",
            pollInterval = 1,
        ))

        for i in range(2):
            if serial[i] is not None:
                self.add(cl.ClinkChannel( 
                    name    = f'Ch[{i}]', 
                    offset  = 0x100+(i*0x100),
                    serial  = serial[i], 
                    camType = camType[i], 
                    # expand  = False,
                ))

    def hardReset(self):
        self.CntRst()

    def softReset(self):
        self.CntRst()

    def countReset(self):
        self.CntRst()        