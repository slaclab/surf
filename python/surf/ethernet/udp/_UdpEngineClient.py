#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue UdpEngineClient
#-----------------------------------------------------------------------------
# File       : UdpEngineClient.py
# Created    : 2017-04-12
#-----------------------------------------------------------------------------
# Description:
# PyRogue UdpEngineClient
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

class UdpEngineClient(pr.Device):
    def __init__(   self,       
            name        = "UdpEngineClient",
            description = "UdpEngineClient",
            **kwargs):
        super().__init__(name=name, description=description, **kwargs) 
        
        ##############################
        # Variables
        ##############################

        self.add(pr.RemoteVariable(   
            name         = "ClientRemotePortRaw",
            description  = "ClientRemotePort (big-Endian configuration)",
            offset       =  0x00,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
            hidden       = True,            
        ))

        self.add(pr.LinkVariable(
            name         = "ClientRemotePort", 
            description  = "ClientRemotePort (human readable & little-Endian configuration)",
            mode         = 'RW', 
            linkedGet    = udp.getPortValue,
            linkedSet    = udp.setPortValue,
            dependencies = [self.variables["ClientRemotePortRaw"]],
        ))         
        
        self.add(pr.RemoteVariable(   
            name         = "ClientRemoteIpRaw",
            description  = "ClientRemoteIp (big-Endian configuration)",
            offset       =  0x04,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
            hidden       = True,            
        ))
        
        self.add(pr.LinkVariable(
            name         = "ClientRemoteIp", 
            description  = "ClientRemoteIp (human readable string)",
            mode         = 'RW', 
            linkedGet    = udp.getIpValue,
            linkedSet    = udp.setIpValue,
            dependencies = [self.variables["ClientRemoteIpRaw"]],
        ))         
