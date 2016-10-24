#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Device AxiSysMonUltraScale
#-----------------------------------------------------------------------------
# File       : AxiSysMonUltraScale.py
# Author     : Ryan Herbst, rherbst@slac.stanford.edu
# Created    : 2016-10-24
# Last update: 2016-10-24
#-----------------------------------------------------------------------------
# Description:
# Device creator for AxiSysMonUltraScale
# Auto created from ../surf/xilinx/UltraScale/general/yaml/AxiSysMonUltraScale.yaml
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
                         hidden=hidden,size=0x800,
                         description='AXI-Lite System Managment for Xilinx Ultra Scale (Refer to PG185 and UG580)')

    dev.add(pyrogue.Variable(name='SR',
                             description='Status Register',
                             hidden=False, enum=None, offset=0x4, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='AOSR',
                             description='Alarm Output Status Register',
                             hidden=False, enum=None, offset=0x8, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='CONVSTR',
                             description='CONVST Register',
                             hidden=False, enum=None, offset=0xc, bitSize=32, bitOffset=0, base='uint', mode='WO'))

    dev.add(pyrogue.Variable(name='SYSMONRR',
                             description='SYSMON Hard Macro Reset Register',
                             hidden=False, enum=None, offset=0x10, bitSize=32, bitOffset=0, base='uint', mode='WO'))

    dev.add(pyrogue.Variable(name='GIER',
                             description='Global Interrupt Enable Register',
                             hidden=False, enum=None, offset=0x5c, bitSize=32, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='IPISR',
                             description='IP Interrupt Status Register',
                             hidden=False, enum=None, offset=0x60, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='IPIER',
                             description='IP Interrupt Enable Register',
                             hidden=False, enum=None, offset=0x68, bitSize=32, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='Temperature',
                             description='Temperature's ADC value',
                             hidden=False, enum=None, offset=0x400, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='VCCINT',
                             description='VCCINT's ADC value',
                             hidden=False, enum=None, offset=0x404, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='VCCAUX',
                             description='VCCAUX's ADC value',
                             hidden=False, enum=None, offset=0x408, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='VP_VN',
                             description='VP/VN's ADC value',
                             hidden=False, enum=None, offset=0x40c, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='VREFP',
                             description='VREFP's ADC value',
                             hidden=False, enum=None, offset=0x410, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='VREFN',
                             description='VREFN's ADC value',
                             hidden=False, enum=None, offset=0x414, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='VBRAM',
                             description='VBRAM's ADC value',
                             hidden=False, enum=None, offset=0x418, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='SupplyOffset',
                             description='Supply Offset',
                             hidden=False, enum=None, offset=0x420, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='ADCOffset',
                             description='ADC Offset',
                             hidden=False, enum=None, offset=0x424, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='GainError',
                             description='Gain Error',
                             hidden=False, enum=None, offset=0x428, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='VAUXP_VAUXN',
                             description='VAUXP_VAUXN's ADC values',
                             hidden=False, enum=None, offset=0x440, bitSize=512, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='MaxTemp',
                             description='maximum temperature measurement',
                             hidden=False, enum=None, offset=0x480, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='MaxVCCINT',
                             description='maximum VCCINT measurement',
                             hidden=False, enum=None, offset=0x484, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='MaxVCCAUX',
                             description='maximum VCCAUX measurement',
                             hidden=False, enum=None, offset=0x488, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='MaxVBRAM',
                             description='maximum VBRAM measurement',
                             hidden=False, enum=None, offset=0x48c, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='MinTemp',
                             description='minimum temperature measurement',
                             hidden=False, enum=None, offset=0x490, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='MinVCCINT',
                             description='minimum VCCINT measurement',
                             hidden=False, enum=None, offset=0x494, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='MinVCCAUX',
                             description='minimum VCCAUX measurement',
                             hidden=False, enum=None, offset=0x498, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='MinVBRAM',
                             description='minimum VBRAM measurement',
                             hidden=False, enum=None, offset=0x49c, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='I2C_Address',
                             description='I2C Address',
                             hidden=False, enum=None, offset=0x4e0, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='FlagRegister',
                             description='Flag Register',
                             hidden=False, enum=None, offset=0x4fc, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='ConfigurationRegister',
                             description='Configuration Registers',
                             hidden=False, enum=None, offset=0x500, bitSize=128, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='SequenceRegister8',
                             description='Sequence Register 8',
                             hidden=False, enum=None, offset=0x518, bitSize=32, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='SequenceReg9',
                             description='Sequence Register 9',
                             hidden=False, enum=None, offset=0x51c, bitSize=32, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='SequenceReg_7_0',
                             description='Sequence Register [7:0]',
                             hidden=False, enum=None, offset=0x520, bitSize=256, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='AlarmThresholdReg_8_0',
                             description='Alarm Threshold Register [8:0]',
                             hidden=False, enum=None, offset=0x540, bitSize=288, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='AlarmThresholdReg12',
                             description='Alarm Threshold Register 12',
                             hidden=False, enum=None, offset=0x570, bitSize=32, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='AlarmThresholdReg16',
                             description='Alarm Threshold Register 16',
                             hidden=False, enum=None, offset=0x580, bitSize=32, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='AlarmThresholdReg_25_16',
                             description='Alarm Threshold Register [25:16]',
                             hidden=False, enum=None, offset=0x580, bitSize=256, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='VUSER',
                             description='VUSER[4:0] supply monitor measurement',
                             hidden=False, enum=None, offset=0x600, bitSize=128, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='MAX_VUSER',
                             description='Maximum VUSER[4:0] supply monitor measurement',
                             hidden=False, enum=None, offset=0x680, bitSize=128, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='MIN_VUSER',
                             description='Minimum VUSER[4:0] supply monitor measurement',
                             hidden=False, enum=None, offset=0x6a0, bitSize=128, bitOffset=0, base='uint', mode='RO'))

