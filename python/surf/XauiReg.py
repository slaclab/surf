#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Device XauiReg
#-----------------------------------------------------------------------------
# File       : XauiReg.py
# Created    : 2016-12-01
# Last update: 2016-12-01
#-----------------------------------------------------------------------------
# Description:
# Device creator for XauiReg
# Auto created from ../surf/ethernet/XauiCore/core/yaml/XauiReg.yaml
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

def create(name='xauiReg', offset=0, memBase=None, hidden=False):

    dev = pyrogue.Device(name=name,memBase=memBase,offset=offset,
                         hidden=hidden,size=0x1000,
                         description='XauiReg')

    dev.add(pyrogue.Variable(name='statusCounters',
                             description='Status Counters',
                             hidden=False, enum=None, offset=0x0, bitSize=800, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='statusVector',
                             description='Status Vector',
                             hidden=False, enum=None, offset=0x100, bitSize=25, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='macAddress',
                             description='MAC Address (big-Endian)',
                             hidden=False, enum=None, offset=0x200, bitSize=48, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='pauseTime',
                             description='PauseTime',
                             hidden=False, enum=None, offset=0x21c, bitSize=16, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='filterEnable',
                             description='FilterEnable',
                             hidden=False, enum=None, offset=0x228, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='pauseEnable',
                             description='PauseEnable',
                             hidden=False, enum=None, offset=0x22c, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='configVector',
                             description='ConfigVector',
                             hidden=False, enum=None, offset=0x230, bitSize=7, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rollOverEn',
                             description='RollOverEn',
                             hidden=False, enum=None, offset=0xf00, bitSize=25, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='counterReset',
                             description='CounterReset',
                             hidden=False, enum=None, offset=0xff4, bitSize=1, bitOffset=0, base='uint', mode='WO'))

    dev.add(pyrogue.Variable(name='softReset',
                             description='SoftReset',
                             hidden=False, enum=None, offset=0xff8, bitSize=1, bitOffset=0, base='uint', mode='WO'))

    dev.add(pyrogue.Variable(name='hardReset',
                             description='HardReset',
                             hidden=False, enum=None, offset=0xffc, bitSize=1, bitOffset=0, base='uint', mode='WO'))

    return dev
