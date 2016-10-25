#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Device UdpEngineClient
#-----------------------------------------------------------------------------
# File       : UdpEngineClient.py
# Author     : Ryan Herbst, rherbst@slac.stanford.edu
# Created    : 2016-10-24
# Last update: 2016-10-24
#-----------------------------------------------------------------------------
# Description:
# Device creator for UdpEngineClient
# Auto created from ../surf/ethernet/UdpEngine/yaml/UdpEngineClient.yaml
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

def create(name='udpEngineClient', offset=0, memBase=None, hidden=False):

    dev = pyrogue.Device(name=name,memBase=memBase,offset=offset,
                         hidden=hidden,size=0x8,
                         description='UdpEngineClient')

    dev.add(pyrogue.Variable(name='clientRemotePort',
                             description='ClientRemotePort (big-Endian configuration)',
                             hidden=False, enum=None, offset=0x0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='clientRemoteIp',
                             description='ClientRemoteIp (big-Endian configuration)',
                             hidden=False, enum=None, offset=0x4, bitSize=32, bitOffset=0, base='uint', mode='RW'))

    return dev
