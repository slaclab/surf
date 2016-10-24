#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Device AxiMicronN25Q
#-----------------------------------------------------------------------------
# File       : AxiMicronN25Q.py
# Author     : Ryan Herbst, rherbst@slac.stanford.edu
# Created    : 2016-10-24
# Last update: 2016-10-24
#-----------------------------------------------------------------------------
# Description:
# Device creator for AxiMicronN25Q
# Auto created from ../surf/devices/Micron/n25q/yaml/AxiMicronN25Q.yaml
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
                         description='AXI-Lite Micron N25Q and Micron MT25Q PROM')

    dev.add(pyrogue.Variable(name='Test',
                             description='Scratch Pad tester register',
                             hidden=False, enum=None, offset=0x0, bitSize=32, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='Addr32BitMode',
                             description='Enable 32-bit PROM mode',
                             hidden=False, enum=None, offset=0x4, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='Addr',
                             description='Address Register',
                             hidden=False, enum=None, offset=0x8, bitSize=32, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='Cmd',
                             description='Command Register',
                             hidden=False, enum=None, offset=0xc, bitSize=32, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='Data',
                             description='Data Register Array',
                             hidden=False, enum=None, offset=0x200, bitSize=2048, bitOffset=0, base='uint', mode='RW'))

