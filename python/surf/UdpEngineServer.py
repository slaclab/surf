#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Device UdpEngineServer
#-----------------------------------------------------------------------------
# File       : UdpEngineServer.py
# Author     : Ryan Herbst, rherbst@slac.stanford.edu
# Created    : 2016-12-01
# Last update: 2016-12-01
#-----------------------------------------------------------------------------
# Description:
# Device creator for UdpEngineServer
# Auto created from ../surf/ethernet/UdpEngine/yaml/UdpEngineServer.yaml
#-----------------------------------------------------------------------------
# This file is part of the rogue software platform. It is subject to 
# the license terms in the LICENSE.txt file found in the top-level directory 
# of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of the rogue software platform, including this file, may be 
# copied, modified, propagated, or distributed except according to the terms 
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue

def create(name='udpEngineServer', offset=0, memBase=None, hidden=False):

    dev = pyrogue.Device(name=name,memBase=memBase,offset=offset,
                         hidden=hidden,size=0x8,
                         description='UdpEngineServer')

    dev.add(pyrogue.Variable(name='serverRemotePort',
                             description='ServerRemotePort (big-Endian configuration)',
                             hidden=False, enum=None, offset=0x0, bitSize=16, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='serverRemoteIp',
                             description='ServerRemoteIp (big-Endian configuration)',
                             hidden=False, enum=None, offset=0x4, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    return dev
