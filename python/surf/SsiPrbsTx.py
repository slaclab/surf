#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Device SsiPrbsTx
#-----------------------------------------------------------------------------
# File       : SsiPrbsTx.py
# Author     : Ryan Herbst, rherbst@slac.stanford.edu
# Created    : 2016-10-24
# Last update: 2016-10-24
#-----------------------------------------------------------------------------
# Description:
# Device creator for SsiPrbsTx
# Auto created from ../surf/protocols/ssi/yaml/SsiPrbsTx.yaml
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

def create(name, offset, memBase=None, hidden=False):

    dev = pyrogue.Device(name=name,memBase=memBase,offset=offset,
                         hidden=hidden,size=0x100,
                         description='SsiPrbsTx')

    dev.add(pyrogue.Variable(name='AxiEn',
                             description='',
                             hidden=False, enum=None, offset=0x0, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TxEn',
                             description='',
                             hidden=False, enum=None, offset=0x0, bitSize=1, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='Busy',
                             description='',
                             hidden=False, enum=None, offset=0x0, bitSize=1, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='Overflow',
                             description='',
                             hidden=False, enum=None, offset=0x0, bitSize=1, bitOffset=3, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='OneShot',
                             description='',
                             hidden=False, enum=None, offset=0x0, bitSize=1, bitOffset=4, base='uint', mode='WO'))

    dev.add(pyrogue.Variable(name='FwCnt',
                             description='',
                             hidden=False, enum=None, offset=0x0, bitSize=1, bitOffset=5, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='PacketLength',
                             description='',
                             hidden=False, enum=None, offset=0x4, bitSize=32, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tDest',
                             description='',
                             hidden=False, enum=None, offset=0x8, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tId',
                             description='',
                             hidden=False, enum=None, offset=0x2, bitSize=8, bitOffset=16, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DataCount',
                             description='',
                             hidden=False, enum=None, offset=0xc, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='EventCount',
                             description='',
                             hidden=False, enum=None, offset=0x10, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='RandomData',
                             description='',
                             hidden=False, enum=None, offset=0x14, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Command(name='C_OneShot',
                            description='',
                            hidden=False, base=None,
                            function="""\
                                     dev.OneShot.set(1)
                                     """

