#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Device AxiSy56040
#-----------------------------------------------------------------------------
# File       : AxiSy56040.py
# Created    : 2016-12-01
# Last update: 2016-12-01
#-----------------------------------------------------------------------------
# Description:
# Device creator for AxiSy56040
# Auto created from ../surf/devices/Microchip/sy56040/yaml/AxiSy56040.yaml
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

def create(name='axiSy56040', offset=0, memBase=None, hidden=False):

    dev = pyrogue.Device(name=name,memBase=memBase,offset=offset,
                         hidden=hidden,size=0x10,
                         description='AXI-Lite Microchip SY56040 and Microchip SY58040')

    dev.add(pyrogue.Variable(name='outputConfig_0',
                             description='Output Configuration Register Array',
                             hidden=False, enum=None, offset=0x0, bitSize=2, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='outputConfig_1',
                             description='Output Configuration Register Array',
                             hidden=False, enum=None, offset=0x4, bitSize=2, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='outputConfig_2',
                             description='Output Configuration Register Array',
                             hidden=False, enum=None, offset=0x8, bitSize=2, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='outputConfig_3',
                             description='Output Configuration Register Array',
                             hidden=False, enum=None, offset=0xc, bitSize=2, bitOffset=0, base='uint', mode='RW'))

    return dev
