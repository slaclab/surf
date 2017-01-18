#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Device UdpClient
#-----------------------------------------------------------------------------
# File       : UdpClient.py
# Author     : Ryan Herbst, rherbst@slac.stanford.edu
# Created    : 2016-12-01
# Last update: 2016-12-01
#-----------------------------------------------------------------------------
# Description:
# Device creator for UdpClient
# Auto created from ../surf/ethernet/UdpEngine/yaml/UdpClient.yaml
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

class UdpClient(pr.Device):
    def __init__(self, name="UdpClient", memBase=None, offset=0, hidden=False):
        super(self.__class__, self).__init__(name, "UDP Client module",
                                             memBase, offset, hidden)
                                             
        self.add(pr.Variable(name='clientRemotePort',
                description='ClientRemotePort (big-Endian configuration)',
                hidden=False, enum=None, offset=0x0, bitSize=16, bitOffset=0, base='hex', mode='RW'))

        self.add(pr.Variable(name='clientRemoteIp',
                description='ClientRemoteIp (big-Endian configuration)',
                hidden=False, enum=None, offset=0x4, bitSize=32, bitOffset=0, base='hex', mode='RW'))
                