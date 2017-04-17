#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Device TenGigEthReg
#-----------------------------------------------------------------------------
# File       : TenGigEthReg.py
# Created    : 2016-12-01
# Last update: 2016-12-01
#-----------------------------------------------------------------------------
# Description:
# Device creator for TenGigEthReg
# Auto created from ../surf/ethernet/TenGigEthCore/core/yaml/TenGigEthReg.yaml
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

def create(name='tenGigEthReg', offset=0, memBase=None, hidden=False):

    dev = pyrogue.Device(name=name,memBase=memBase,offset=offset,
                         hidden=hidden,size=0x1000,
                         description='TenGigEthReg')

    dev.add(pyrogue.Variable(name='statusCounters',
                             description='Status Counters',
                             hidden=False, enum=None, offset=0x0, bitSize=608, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='statusVector',
                             description='Status Vector',
                             hidden=False, enum=None, offset=0x100, bitSize=19, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='phyStatus',
                             description='PhyStatus',
                             hidden=False, enum=None, offset=0x108, bitSize=8, bitOffset=0, base='uint', mode='RO'))

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

    dev.add(pyrogue.Variable(name='pma_pmd_type',
                             description='pma_pmd_type',
                             hidden=False, enum=None, offset=0x230, bitSize=3, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='pma_loopback',
                             description='pma_loopback',
                             hidden=False, enum=None, offset=0x234, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='pma_reset',
                             description='pma_reset',
                             hidden=False, enum=None, offset=0x238, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='pcs_loopback',
                             description='pcs_loopback',
                             hidden=False, enum=None, offset=0x23c, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='pcs_reset',
                             description='pcs_reset',
                             hidden=False, enum=None, offset=0x240, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rollOverEn',
                             description='RollOverEn',
                             hidden=False, enum=None, offset=0xf00, bitSize=19, bitOffset=0, base='uint', mode='RW'))

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
