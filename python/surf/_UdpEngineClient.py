#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue UdpEngineClient
#-----------------------------------------------------------------------------
# File       : UdpEngineClient.py
# Created    : 2017-04-04
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
    def __init__(self, name="UdpEngineClient", description="UdpEngineClient", memBase=None, offset=0x0, hidden=False):
        super(self.__class__, self).__init__(name, description, memBase, offset, hidden)

        ##############################
        # Variables
        ##############################

        self.add(pr.Variable(   name         = "ClientRemotePort",
                                description  = "ClientRemotePort (big-Endian configuration)",
                                offset       =  0x00,
                                bitSize      =  16,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

        self.add(pr.Variable(   name         = "ClientRemoteIp",
                                description  = "ClientRemoteIp (big-Endian configuration)",
                                offset       =  0x04,
                                bitSize      =  32,
                                bitOffset    =  0x00,
                                base         = "hex",
                                mode         = "RW",
                            ))

