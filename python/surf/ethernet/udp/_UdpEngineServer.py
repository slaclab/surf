#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue UdpEngineServer
#-----------------------------------------------------------------------------
# File       : UdpEngineServer.py
# Created    : 2017-04-12
#-----------------------------------------------------------------------------
# Description:
# PyRogue UdpEngineServer
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
from surf.ethernet import udp

class UdpEngineServer(pr.Device):
    def __init__(   self,       
            name        = "UdpEngineServer",
            description = "UdpEngineServer",
            **kwargs):
        super().__init__(name=name, description=description, **kwargs) 
        ##############################
        # Variables
        ##############################

        self.add(pr.RemoteVariable(   
            name         = "ServerRemotePort",
            description  = "ServerRemotePort (big-Endian configuration)",
            offset       =  0x00,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
            hidden       = True,
        ))

        self.add(pr.LinkVariable(
            name         = "ServerRemotePortValue", 
            description  = "ServerRemotePort (human readable)",
            mode         = 'RO', 
            linkedGet    = udp.getPortValue,
            dependencies = [self.variables["ServerRemotePort"]],
        ))        
        
        self.add(pr.RemoteVariable(   
            name         = "ServerRemoteIp",
            description  = "ServerRemoteIp (big-Endian configuration)",
            offset       =  0x04,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RO",
            hidden       = True,
        ))
        
        self.add(pr.LinkVariable(
            name         = "ServerRemoteIpValue", 
            description  = "ServerRemoteIp (human readable)",
            mode         = 'RO', 
            linkedGet    = udp.getIpValue,
            dependencies = [self.variables["ServerRemoteIp"]],
        ))         
