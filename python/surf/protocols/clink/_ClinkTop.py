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
            serialA     = None,
            serialB     = None,
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
            bitOffset    =  0x00,
            base         = pr.UInt,
            enum         = { 0 : 'Disable' , 1 : 'Base', 2 : 'Medium', 3 : 'Full', 4 : 'Deca'},
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(    
            name         = "LinkLockedA",
            description  = "Camera link channel locked status",
            offset       =  0x04,
            bitSize      =  1,
            bitOffset    =  0,
            base         = pr.Bool,
            pollInterval = 1,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "LinkLockedB",
            description  = "Camera link channel locked status",
            offset       =  0x04,
            bitSize      =  1,
            bitOffset    =  1,
            base         = pr.Bool,
            pollInterval = 1,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "LinkLockedC",
            description  = "Camera link channel locked status",
            offset       =  0x04,
            bitSize      =  1,
            bitOffset    =  2,
            base         = pr.Bool,
            pollInterval = 1,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "ShiftCountA",
            description  = "Shift count for channel",
            offset       =  0x08,
            bitSize      =  8,
            bitOffset    =  0,
            base         = pr.UInt,
            pollInterval = 1,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "ShiftCountB",
            description  = "Shift count for channel",
            offset       =  0x08,
            bitSize      =  8,
            bitOffset    =  8,
            base         = pr.UInt,
            pollInterval = 1,
            mode         = "RO",
        ))

        self.add(pr.RemoteVariable(    
            name         = "ShiftCountC",
            description  = "Shift count for channel",
            offset       =  0x08,
            bitSize      =  8,
            bitOffset    =  16,
            base         = pr.UInt,
            pollInterval = 1,
            mode         = "RO",
        ))

        self.add(surf.protocols.clink.ClinkChannel( name = "ChannelA", serial=serialA, offset=0x100))
        self.add(surf.protocols.clink.ClinkChannel( name = "ChannelB", serial=serialB, offset=0x200))

