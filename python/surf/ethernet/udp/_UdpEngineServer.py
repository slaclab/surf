#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr
from surf.ethernet import udp

class UdpEngineServer(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        ##############################
        # Variables
        ##############################

        self.add(pr.RemoteVariable(
            name         = "ServerRemotePort",
            description  = "ServerRemotePort (big-Endian configuration)",
            offset       =  0x00,
            bitSize      =  16,
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
