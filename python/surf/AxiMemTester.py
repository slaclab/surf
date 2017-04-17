#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Device AxiMemTester
#-----------------------------------------------------------------------------
# File       : AxiMemTester.py
# Created    : 2016-12-01
# Last update: 2016-12-01
#-----------------------------------------------------------------------------
# Description:
# Device creator for AxiMemTester
# Auto created from ../surf/axi/yaml/AxiMemTester.yaml
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

def create(name='axiMemTester', offset=0, memBase=None, hidden=False):

    dev = pyrogue.Device(name=name,memBase=memBase,offset=offset,
                         hidden=hidden,size=0x1000,
                         description='AXI4 Memory Tester Module')

    dev.add(pyrogue.Variable(name='passed',
                             description='Passed Memory Test',
                             hidden=False, enum=None, offset=0x100, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='failed',
                             description='Failed Memory Test',
                             hidden=False, enum=None, offset=0x104, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='writeTimer',
                             description='Write Timer',
                             hidden=False, enum=None, offset=0x108, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='readTimer',
                             description='Read Timer',
                             hidden=False, enum=None, offset=0x10c, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='startAddress',
                             description='Start Address',
                             hidden=False, enum=None, offset=0x110, bitSize=64, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='stopAddress',
                             description='Stop Address',
                             hidden=False, enum=None, offset=0x118, bitSize=64, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='aDDR_WIDTH_C',
                             description='AXI4 Address Bus Width (units of bits)',
                             hidden=False, enum=None, offset=0x120, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='dATA_BYTES_C',
                             description='AXI4 Data Bus Width (units of bits)',
                             hidden=False, enum=None, offset=0x124, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='iD_BITS_C',
                             description='AXI4 ID Bus Width (units of bits)',
                             hidden=False, enum=None, offset=0x128, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    return dev
