#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Device XauiReg
#-----------------------------------------------------------------------------
# File       : XauiReg.py
# Author     : Ryan Herbst, rherbst@slac.stanford.edu
# Created    : 2016-10-24
# Last update: 2016-10-24
#-----------------------------------------------------------------------------
# Description:
# Device creator for XauiReg
# Auto created from ../surf/ethernet/XauiCore/core/yaml/XauiReg.yaml
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
                         hidden=hidden,size=0x1000,
                         description='XauiReg')

    dev.add(pyrogue.Variable(name='StatusCounters',
                             description='Status Counters',
                             hidden=False, enum=None, offset=0x0, bitSize=800, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='StatusVector',
                             description='Status Vector',
                             hidden=False, enum=None, offset=0x100, bitSize=25, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='MacAddress',
                             description='MAC Address (big-Endian)',
                             hidden=False, enum=None, offset=0x200, bitSize=48, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='PauseTime',
                             description='PauseTime',
                             hidden=False, enum=None, offset=0x21c, bitSize=16, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='FilterEnable',
                             description='FilterEnable',
                             hidden=False, enum=None, offset=0x228, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='PauseEnable',
                             description='PauseEnable',
                             hidden=False, enum=None, offset=0x22c, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='ConfigVector',
                             description='ConfigVector',
                             hidden=False, enum=None, offset=0x230, bitSize=7, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RollOverEn',
                             description='RollOverEn',
                             hidden=False, enum=None, offset=0xf00, bitSize=25, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CounterReset',
                             description='CounterReset',
                             hidden=False, enum=None, offset=0xff4, bitSize=1, bitOffset=0, base='uint', mode='WO'))

    dev.add(pyrogue.Variable(name='SoftReset',
                             description='SoftReset',
                             hidden=False, enum=None, offset=0xff8, bitSize=1, bitOffset=0, base='uint', mode='WO'))

    dev.add(pyrogue.Variable(name='HardReset',
                             description='HardReset',
                             hidden=False, enum=None, offset=0xffc, bitSize=1, bitOffset=0, base='uint', mode='WO'))

