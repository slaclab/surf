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
            name         = "ClientRemotePort",
            description  = "ClientRemotePort (big-Endian configuration)",
            offset       =  0x00,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.LinkVariable(
            name         = "ClientRemotePortValue", 
            description  = "ClientRemotePort (human readable)",
            mode         = 'RO', 
            linkedGet    = self.dispPortValue,
            dependencies = [self.variables["ClientRemotePort"]],
        ))         
        
        self.add(pr.RemoteVariable(   
            name         = "ClientRemoteIp",
            description  = "ClientRemoteIp (big-Endian configuration)",
            offset       =  0x04,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = pr.UInt,
            mode         = "RW",
        ))
        
        self.add(pr.LinkVariable(
            name         = "ClientRemoteIpValue", 
            description  = "ClientRemoteIp (human readable)",
            mode         = 'RO', 
            linkedGet    = self.dispIpValue,
            dependencies = [self.variables["ClientRemoteIp"]],
        ))         

    @staticmethod
    def dispPortValue(var):
        x = var.dependencies[0].value()
        value = int.from_bytes(x.to_bytes(2, byteorder='little'), byteorder='big', signed=False)
        return ( '%d' % value )   

    @staticmethod
    def dispIpValue(var):
        x = var.dependencies[0].value()
        return ( '%d.%d.%d.%d' % ( ((x>>0)&0xFF),((x>>8)&0xFF),((x>>16)&0xFF),((x>>24)&0xFF) ) )
