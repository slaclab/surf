#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Device AxiVersion
#-----------------------------------------------------------------------------
# File       : AxiVersion.py
# Author     : Ryan Herbst, rherbst@slac.stanford.edu
# Created    : 2016-10-24
# Last update: 2016-10-24
#-----------------------------------------------------------------------------
# Description:
# Device creator for AxiVersion
# Auto created from ../surf/axi/yaml/AxiVersion.yaml
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
                         description='AXI-Lite Version Module')

    dev.add(pyrogue.Variable(name='FpgaVersion',
                             description='FPGA Firmware Version Number',
                             hidden=False, enum=None, offset=0x0, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='ScratchPad',
                             description='Register to test reads and writes',
                             hidden=False, enum=None, offset=0x4, bitSize=32, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DeviceDna',
                             description='Xilinx Device DNA value burned into FPGA',
                             hidden=False, enum=None, offset=0x8, bitSize=64, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='FdSerial',
                             description='Board ID value read from DS2411 chip',
                             hidden=False, enum=None, offset=0x10, bitSize=64, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='MasterReset',
                             description='Optional User Reset',
                             hidden=False, enum=None, offset=0x18, bitSize=1, bitOffset=0, base='uint', mode='WO'))

    dev.add(pyrogue.Variable(name='FpgaReload',
                             description='Optional Reload the FPGA from the attached PROM',
                             hidden=False, enum=None, offset=0x1c, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='FpgaReloadAddress',
                             description='Reload start address',
                             hidden=False, enum=None, offset=0x20, bitSize=32, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='Counter',
                             description='Free running counter',
                             hidden=False, enum=None, offset=0x24, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='FpgaReloadHalt',
                             description='Used to halt automatic reloads via AxiVersion',
                             hidden=False, enum=None, offset=0x28, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='UpTimeCnt',
                             description='Number of seconds since last reset',
                             hidden=False, enum=None, offset=0x2c, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='DeviceId',
                             description='Device Identification',
                             hidden=False, enum=None, offset=0x30, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='UserConstants',
                             description='Optional user input values',
                             hidden=False, enum=None, offset=0x400, bitSize=2048, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='BuildStamp',
                             description='Firmware Build String',
                             hidden=False, enum=None, offset=0x800, bitSize=512, bitOffset=0, base='uint', mode='RO'))

