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

class UdpEngineClient(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        ##############################
        # Variables
        ##############################

        self.add(pr.RemoteVariable(
            name         = "ClientRemotePortRaw",
            description  = "ClientRemotePort (big-Endian configuration)",
            offset       =  0x00,
            bitSize      =  16,
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
