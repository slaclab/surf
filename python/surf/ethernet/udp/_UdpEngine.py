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

class UdpEngine(pr.Device):
    def __init__(
            self,
            numSrv = 0,
            numClt = 0,
            numIgmp = 0,
            **kwargs):
        super().__init__(**kwargs)

        #############
        # UDP Clients
        #############

        for i in range(numClt):

            self.add(pr.RemoteVariable(
                name         = f'ClientRemotePortRaw[{i}]',
                description  = 'ClientRemotePort (big-Endian configuration)',
                offset       = (0x000+8*i),
                bitSize      = 16,
                mode         = 'RW',
                hidden       = True,
            ))

            self.add(pr.LinkVariable(
                name         = f'ClientRemotePort[{i}]',
                description  = 'ClientRemotePort (human readable & little-Endian configuration)',
                mode         = 'RW',
                linkedGet    = udp.getPortValue,
                linkedSet    = udp.setPortValue,
                dependencies = [self.variables[f'ClientRemotePortRaw[{i}]']],
            ))

            self.add(pr.RemoteVariable(
                name         = f'ClientRemoteIpRaw[{i}]',
                description  = 'ClientRemoteIp (big-Endian configuration)',
                offset       = (0x004+8*i),
                bitSize      = 32,
                mode         = 'RW',
                hidden       = True,
            ))

            self.add(pr.LinkVariable(
                name         = f'ClientRemoteIp[{i}]',
                description  = 'ClientRemoteIp (human readable string)',
                mode         = 'RW',
                linkedGet    = udp.getIpValue,
                linkedSet    = udp.setIpValue,
                dependencies = [self.variables[f'ClientRemoteIpRaw[{i}]']],
            ))

        #############
        # UDP Servers
        #############

        for i in range(numSrv):

            self.add(pr.RemoteVariable(
                name         = f'ServerRemotePortRaw[{i}]',
                description  = 'ServerRemotePort (big-Endian configuration)',
                offset       = (0x800+8*i),
                bitSize      = 16,
                mode         = 'RO',
                hidden       = True,
            ))

            self.add(pr.LinkVariable(
                name         = f'ServerRemotePort[{i}]',
                description  = 'ServerRemotePort (human readable)',
                mode         = 'RO',
                linkedGet    = udp.getPortValue,
                dependencies = [self.variables[f'ServerRemotePortRaw[{i}]']],
            ))

            self.add(pr.RemoteVariable(
                name         = f'ServerRemoteIpRaw[{i}]',
                description  = 'ServerRemoteIp (big-Endian configuration)',
                offset       = (0x804+8*i),
                bitSize      = 32,
                mode         = 'RO',
                hidden       = True,
            ))

            self.add(pr.LinkVariable(
                name         = f'ServerRemoteIp[{i}]',
                description  = 'ServerRemoteIp (human readable)',
                mode         = 'RO',
                linkedGet    = udp.getIpValue,
                dependencies = [self.variables[f'ServerRemoteIpRaw[{i}]']],
            ))

        ######################
        # IGMP Group Addresses
        ######################

        for i in range(numIgmp):

            self.add(pr.RemoteVariable(
                name         = f'IgmpIpRaw[{i}]',
                description  = 'IgmpIp (big-Endian configuration)',
                offset       = (0xFD0+4*i),
                bitSize      = 32,
                mode         = 'RW',
                hidden       = True,
            ))

            self.add(pr.LinkVariable(
                name         = f'IgmpIp[{i}]',
                description  = 'IgmpIp (human readable)',
                mode         = 'RW',
                linkedGet    = udp.getIpValue,
                linkedSet    = udp.setIpValue,
                dependencies = [self.variables[f'IgmpIpRaw[{i}]']],
            ))

        ##############
        # Local Config
        ##############

        self.add(pr.RemoteVariable(
            name         = 'SoftIpRaw',
            description  = 'software configurable IP used when softIp connected to localIp in firmware (big-Endian configuration)',
            offset       = 0xFE4,
            bitSize      = 32,
            mode         = 'RW',
            hidden       = True,
        ))

        self.add(pr.LinkVariable(
            name         = 'SoftIp',
            description  = 'Ip (human readable string)',
            mode         = 'RW',
            linkedGet    = udp.getIpValue,
            linkedSet    = udp.setIpValue,
            dependencies = [self.variables['SoftIpRaw']],
        ))

        self.add(pr.RemoteVariable(
            name         = 'SoftMacRaw',
            description  = 'software configurable MAC used when softMac connected to localMac in firmware (big-Endian configuration)',
            description  = 'MacAddress (big-Endian configuration)',
            offset       = 0xFE8,
            bitSize      = 48,
            mode         = 'RW',
            hidden       = True,
        ))

        self.add(pr.LinkVariable(
            name         = 'SoftMac',
            description  = 'MacAddress (human readable)',
            mode         = 'RO',
            linkedGet    = udp.getMacValue,
            linkedSet    = udp.setMacValue,
            dependencies = [self.variables['SoftMacRaw']],
        ))

        self.add(pr.RemoteVariable(
            name         = 'BroadcastIpRaw',
            description  = 'BroadcastIp (big-Endian configuration)',
            offset       = 0xFF0,
            bitSize      = 32,
            mode         = 'RW',
            hidden       = True,
        ))

        self.add(pr.LinkVariable(
            name         = 'BroadcastIp',
            description  = 'BroadcastIp (human readable string)',
            mode         = 'RW',
            linkedGet    = udp.getIpValue,
            linkedSet    = udp.setIpValue,
            dependencies = [self.variables['BroadcastIpRaw']],
        ))

        self.add(pr.RemoteVariable(
            name         = 'LocalIpRaw',
            description  = 'LocalIp (big-Endian configuration)',
            offset       = 0xFF4,
            bitSize      = 32,
            mode         = 'RO',
            hidden       = True,
        ))

        self.add(pr.LinkVariable(
            name         = 'LocalIp',
            description  = 'LocalIp (human readable)',
            mode         = 'RO',
            linkedGet    = udp.getIpValue,
            dependencies = [self.variables['LocalIpRaw']],
        ))

        self.add(pr.RemoteVariable(
            name         = 'LocalMacRaw',
            description  = 'MacAddress (big-Endian configuration)',
            offset       = 0xFF8,
            bitSize      = 48,
            mode         = 'RO',
            hidden       = True,
        ))

        self.add(pr.LinkVariable(
            name         = 'LocalMac',
            description  = 'MacAddress (human readable)',
            mode         = 'RO',
            linkedGet    = udp.getMacValue,
            dependencies = [self.variables['LocalMacRaw']],
        ))
