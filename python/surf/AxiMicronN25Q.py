#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Device AxiMicronN25Q
#-----------------------------------------------------------------------------
# File       : AxiMicronN25Q.py
# Created    : 2016-12-01
# Last update: 2016-12-01
#-----------------------------------------------------------------------------
# Description:
# Device creator for AxiMicronN25Q
# Auto created from ../surf/devices/Micron/n25q/yaml/AxiMicronN25Q.yaml
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

def create(name='axiMicronN25Q', offset=0, memBase=None, hidden=False):

    dev = pyrogue.Device(name=name,memBase=memBase,offset=offset,
                         hidden=hidden,size=0x400,
                         description='AXI-Lite Micron N25Q and Micron MT25Q PROM')

    dev.add(pyrogue.Variable(name='test',
                             description='Scratch Pad tester register',
                             hidden=False, enum=None, offset=0x0, bitSize=32, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='addr32BitMode',
                             description='Enable 32-bit PROM mode',
                             hidden=True, enum=None, offset=0x4, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='addr',
                             description='Address Register',
                             hidden=True, enum=None, offset=0x8, bitSize=32, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cmd',
                             description='Command Register',
                             hidden=True, enum=None, offset=0xc, bitSize=32, bitOffset=0, base='uint', mode='RW'))
                             
    for i in range(0,64):                         
        dev.add(pyrogue.Variable(name='data%02i'%(i), description='Data Register[%02i]'%(i),
                             hidden=True, enum=None, offset=(0x200+(i*4)), bitSize=32, bitOffset=0, base='uint', mode='RW'))

    return dev
