#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Device SsiPrbsRx
#-----------------------------------------------------------------------------
# File       : SsiPrbsRx.py
# Created    : 2016-12-01
# Last update: 2016-12-01
#-----------------------------------------------------------------------------
# Description:
# Device creator for SsiPrbsRx
# Auto created from ../surf/protocols/ssi/yaml/SsiPrbsRx.yaml
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

def create(name='ssiPrbsRx', offset=0, memBase=None, hidden=False):

    dev = pyrogue.Device(name=name,memBase=memBase,offset=offset,
                         hidden=hidden,size=0x400,
                         description='SsiPrbsRx')

    dev.add(pyrogue.Variable(name='missedPacketCnt',
                             description='Number of missed packets',
                             hidden=False, enum=None, offset=0x0, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='lengthErrCnt',
                             description='Number of packets that were the wrong length',
                             hidden=False, enum=None, offset=0x4, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='eofeErrCnt',
                             description='Number of EOFE errors',
                             hidden=False, enum=None, offset=0x8, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='dataBusErrCnt',
                             description='Number of data bus errors',
                             hidden=False, enum=None, offset=0xc, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='wordStrbErrCnt',
                             description='Number of word errors',
                             hidden=False, enum=None, offset=0x10, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='bitStrbErrCnt',
                             description='Number of bit errors',
                             hidden=False, enum=None, offset=0x14, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='rxFifoOverflowCnt',
                             description='',
                             hidden=False, enum=None, offset=0x18, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='rxFifoPauseCnt',
                             description='',
                             hidden=False, enum=None, offset=0x1c, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='txFifoOverflowCnt',
                             description='',
                             hidden=False, enum=None, offset=0x20, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='txFifoPauseCnt',
                             description='',
                             hidden=False, enum=None, offset=0x24, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='dummy',
                             description='',
                             hidden=False, enum=None, offset=0x28, bitSize=32, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='status',
                             description='',
                             hidden=False, enum=None, offset=0x1c0, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='packetLength',
                             description='',
                             hidden=False, enum=None, offset=0x1c4, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='packetRate',
                             description='',
                             hidden=False, enum=None, offset=0x1c8, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='bitErrCnt',
                             description='',
                             hidden=False, enum=None, offset=0x1cc, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='wordErrCnt',
                             description='',
                             hidden=False, enum=None, offset=0x1d0, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='rolloverEnable',
                             description='',
                             hidden=False, enum=None, offset=0x3c0, bitSize=32, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cntRst',
                             description='Status counter reset',
                             hidden=False, enum=None, offset=0x3fc, bitSize=1, bitOffset=0, base='uint', mode='WO'))

    return dev
