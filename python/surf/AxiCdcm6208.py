#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Device AxiCdcm6208
#-----------------------------------------------------------------------------
# File       : AxiCdcm6208.py
# Created    : 2016-12-01
# Last update: 2016-12-01
#-----------------------------------------------------------------------------
# Description:
# Device creator for AxiCdcm6208
# Auto created from ../surf/devices/Ti/cdcm6208/yaml/AxiCdcm6208.yaml
#-----------------------------------------------------------------------------
# This file is part of 'SLAC Firmware Standard Library'.
# It is subject to the license terms in the LICENSE.txt file found in the 
# top-level directory of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of 'SLAC Firmware Standard Library', including this file, 
# may be copied, modified, propagated, or distributed except according to 
# the terms contained in the LICENSE.txt file.
#-------------------------------------------------------------------------------

import pyrogue

def create(name='axiCdcm6208', offset=0, memBase=None, hidden=False):

    dev = pyrogue.Device(name=name,memBase=memBase,offset=offset,
                        hidden=hidden,size=0x100,
                        description='AxiCdcm6208 Module')

    for i in range(21):
        dev.add(pyrogue.Variable(name='cdcm6208_%02i'%(i),
                        description='Cdcm6208 Control Registers_%02i'%(i),
                        hidden=False, enum=None, offset=0x0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='sEL_REF',
                             description='Indicates Reference Selected for PLL:0 SEL_REF 0 => Primary 1 => Secondary',
                             hidden=False, enum=None, offset=0x54, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='lOS_REF',
                             description='Loss of reference input: 0 => Reference input present 1 => Loss of reference input.',
                             hidden=False, enum=None, offset=0x54, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='pLL_UNLOCK',
                             description='Indicates unlock status for PLL (digital):0 => PLL locked 1 => PLL unlocked',
                             hidden=False, enum=None, offset=0x54, bitSize=1, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='dIE_REVISION',
                             description='Indicates the silicon die revision (Read only): 2:0 DIE_REVISION 00X --> Engineering Prototypes 010 --> Production Materia',
                             hidden=False, enum=None, offset=0xa0, bitSize=3, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='vCO_VERSION',
                             description='Indicates the device version (Read only):5:3 VCO_VERSION 000 => CDCM6208V1 001 => CDCM6208V2',
                             hidden=False, enum=None, offset=0xa0, bitSize=3, bitOffset=3, base='uint', mode='RO'))

    return dev
