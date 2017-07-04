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

class UdpEngineServer(pr.Device):
    def __init__(   self,       
        name        = "UdpEngineServer",
        description = "UdpEngineServer",
        memBase     =  None,
        offset      =  0x00,
        hidden      =  False,
        expand      =  True,
    ):
        super().__init__(
            name        = name,
            description = description,
            memBase     = memBase,
            offset      = offset,
            hidden      = hidden,
            expand      = expand,
        )

        ##############################
        # Variables
        ##############################

        self.addVariable(   
            name         = "ServerRemotePort",
            description  = "ServerRemotePort (big-Endian configuration)",
            offset       =  0x00,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
        )

        self.addVariable(   
            name         = "ServerRemoteIp",
            description  = "ServerRemoteIp (big-Endian configuration)",
            offset       =  0x04,
            bitSize      =  32,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RO",
        )

