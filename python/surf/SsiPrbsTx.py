#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Device SsiPrbsTx
#-----------------------------------------------------------------------------
# File       : SsiPrbsTx.py
# Created    : 2016-10-24
# Last update: 2016-10-24
#-----------------------------------------------------------------------------
# Description:
# Device creator for SsiPrbsTx
# Auto created from ../surf/protocols/ssi/yaml/SsiPrbsTx.yaml
#-----------------------------------------------------------------------------
# This file is part of 'SLAC Firmware Standard Library'.
# It is subject to the license terms in the LICENSE.txt file found in the 
# top-level directory of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of 'SLAC Firmware Standard Library', including this file, 
# may be copied, modified, propagated, or distributed except according to 
# the terms contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue

def create(name='ssiPrbsTx', offset=0, memBase=None, hidden=False):

    dev = pyrogue.Device(name=name,memBase=memBase,offset=offset,
                         hidden=hidden,size=0x100,
                         description='SsiPrbsTx')

    dev.add(pyrogue.Variable(name='axiEn',
                             description='',
                             hidden=False, enum=None, offset=0x0, bitSize=1, bitOffset=0, base='bool', mode='RW'))

    dev.add(pyrogue.Variable(name='txEn',
                             description='',
                             hidden=False, enum=None, offset=0x0, bitSize=1, bitOffset=1, base='bool', mode='RW'))

    dev.add(pyrogue.Variable(name='busy',
                             description='',
                             hidden=False, enum=None, offset=0x0, bitSize=1, bitOffset=2, base='bool', mode='RO'))

    dev.add(pyrogue.Variable(name='overflow',
                             description='',
                             hidden=False, enum=None, offset=0x0, bitSize=1, bitOffset=3, base='bool', mode='RO'))

    dev.add(pyrogue.Variable(name='oneShotCmd',
                             description='',
                             hidden=True, enum=None, offset=0x0, bitSize=1, bitOffset=4, base='bool', mode='SL'))

    dev.add(pyrogue.Variable(name='fwCnt',
                             description='',
                             hidden=False, enum=None, offset=0x0, bitSize=1, bitOffset=5, base='bool', mode='RW'))

    dev.add(pyrogue.Variable(name='packetLength',
                             description='',
                             hidden=False, enum=None, offset=0x4, bitSize=32, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tDest',
                             description='',
                             hidden=False, enum=None, offset=0x8, bitSize=8, bitOffset=0, base='hex', mode='RW'))

    dev.add(pyrogue.Variable(name='tId',
                             description='',
                             hidden=False, enum=None, offset=0x8, bitSize=8, bitOffset=8, base='hex', mode='RW'))

    dev.add(pyrogue.Variable(name='dataCount', pollInterval=1,
                             description='',
                             hidden=False, enum=None, offset=0xc, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='eventCount', pollInterval=1,
                             description='',
                             hidden=False, enum=None, offset=0x10, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='randomData', pollInterval=1,
                             description='',
                             hidden=False, enum=None, offset=0x14, bitSize=32, bitOffset=0, base='hex', mode='RO'))

    dev.add(pyrogue.Command(name='oneShot',
                            description='',
                            hidden=False, base='None',
                            function="""\
                                     dev.oneShotCmd.set(1)
                                     """))

    return dev
