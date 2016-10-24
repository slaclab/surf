#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Device SsiPrbsRx
#-----------------------------------------------------------------------------
# File       : SsiPrbsRx.py
# Author     : Ryan Herbst, rherbst@slac.stanford.edu
# Created    : 2016-10-24
# Last update: 2016-10-24
#-----------------------------------------------------------------------------
# Description:
# Device creator for SsiPrbsRx
# Auto created from ../surf/protocols/ssi/yaml/SsiPrbsRx.yaml
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
                         hidden=hidden,size=0x400,
                         description='SsiPrbsRx')

    dev.add(pyrogue.Variable(name='MissedPacketCnt',
                             description='Number of missed packets',
                             hidden=False, enum=None, offset=0x0, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='LengthErrCnt',
                             description='Number of packets that were the wrong length',
                             hidden=False, enum=None, offset=0x4, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='EofeErrCnt',
                             description='Number of EOFE errors',
                             hidden=False, enum=None, offset=0x8, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='DataBusErrCnt',
                             description='Number of data bus errors',
                             hidden=False, enum=None, offset=0xc, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='WordStrbErrCnt',
                             description='Number of word errors',
                             hidden=False, enum=None, offset=0x10, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='BitStrbErrCnt',
                             description='Number of bit errors',
                             hidden=False, enum=None, offset=0x14, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='RxFifoOverflowCnt',
                             description='',
                             hidden=False, enum=None, offset=0x18, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='RxFifoPauseCnt',
                             description='',
                             hidden=False, enum=None, offset=0x1c, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='TxFifoOverflowCnt',
                             description='',
                             hidden=False, enum=None, offset=0x20, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='TxFifoPauseCnt',
                             description='',
                             hidden=False, enum=None, offset=0x24, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='Dummy',
                             description='',
                             hidden=False, enum=None, offset=0x28, bitSize=32, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='Status',
                             description='',
                             hidden=False, enum=None, offset=0x1c0, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='PacketLength',
                             description='',
                             hidden=False, enum=None, offset=0x1c4, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='PacketRate',
                             description='',
                             hidden=False, enum=None, offset=0x1c8, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='BitErrCnt',
                             description='',
                             hidden=False, enum=None, offset=0x1cc, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='WordErrCnt',
                             description='',
                             hidden=False, enum=None, offset=0x1d0, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='RolloverEnable',
                             description='',
                             hidden=False, enum=None, offset=0x3c0, bitSize=32, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CntRst',
                             description='Status counter reset',
                             hidden=False, enum=None, offset=0x3fc, bitSize=1, bitOffset=0, base='uint', mode='WO'))

