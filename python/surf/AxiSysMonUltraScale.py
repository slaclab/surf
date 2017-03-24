#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Device AxiSysMonUltraScale
#-----------------------------------------------------------------------------
# File       : AxiSysMonUltraScale.py
# Created    : 2016-12-01
# Last update: 2016-12-01
#-----------------------------------------------------------------------------
# Description:
# Device creator for AxiSysMonUltraScale
# Auto created from ../surf/xilinx/UltraScale/general/yaml/AxiSysMonUltraScale.yaml
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

def create(name='axiSysMonUltraScale', offset=0, memBase=None, hidden=False):

    dev = pyrogue.Device(name=name,memBase=memBase,offset=offset,
                         hidden=hidden,size=0x800,
                         description='AXI-Lite System Managment for Xilinx Ultra Scale (Refer to PG185 and UG580)')

    dev.add(pyrogue.Variable(name='sR',
                             description='Status Register',
                             hidden=False, enum=None, offset=0x4, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='aOSR',
                             description='Alarm Output Status Register',
                             hidden=False, enum=None, offset=0x8, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='cONVSTR',
                             description='CONVST Register',
                             hidden=False, enum=None, offset=0xc, bitSize=32, bitOffset=0, base='uint', mode='WO'))

    dev.add(pyrogue.Variable(name='sYSMONRR',
                             description='SYSMON Hard Macro Reset Register',
                             hidden=False, enum=None, offset=0x10, bitSize=32, bitOffset=0, base='uint', mode='WO'))

    dev.add(pyrogue.Variable(name='gIER',
                             description='Global Interrupt Enable Register',
                             hidden=False, enum=None, offset=0x5c, bitSize=32, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='iPISR',
                             description='IP Interrupt Status Register',
                             hidden=False, enum=None, offset=0x60, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='iPIER',
                             description='IP Interrupt Enable Register',
                             hidden=False, enum=None, offset=0x68, bitSize=32, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='temperature',
                             description='Temperature's ADC value',
                             hidden=False, enum=None, offset=0x400, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='vCCINT',
                             description='VCCINT's ADC value',
                             hidden=False, enum=None, offset=0x404, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='vCCAUX',
                             description='VCCAUX's ADC value',
                             hidden=False, enum=None, offset=0x408, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='vP_VN',
                             description='VP/VN's ADC value',
                             hidden=False, enum=None, offset=0x40c, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='vREFP',
                             description='VREFP's ADC value',
                             hidden=False, enum=None, offset=0x410, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='vREFN',
                             description='VREFN's ADC value',
                             hidden=False, enum=None, offset=0x414, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='vBRAM',
                             description='VBRAM's ADC value',
                             hidden=False, enum=None, offset=0x418, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='supplyOffset',
                             description='Supply Offset',
                             hidden=False, enum=None, offset=0x420, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='aDCOffset',
                             description='ADC Offset',
                             hidden=False, enum=None, offset=0x424, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='gainError',
                             description='Gain Error',
                             hidden=False, enum=None, offset=0x428, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='vAUXP_VAUXN',
                             description='VAUXP_VAUXN's ADC values',
                             hidden=False, enum=None, offset=0x440, bitSize=512, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='maxTemp',
                             description='maximum temperature measurement',
                             hidden=False, enum=None, offset=0x480, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='maxVCCINT',
                             description='maximum VCCINT measurement',
                             hidden=False, enum=None, offset=0x484, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='maxVCCAUX',
                             description='maximum VCCAUX measurement',
                             hidden=False, enum=None, offset=0x488, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='maxVBRAM',
                             description='maximum VBRAM measurement',
                             hidden=False, enum=None, offset=0x48c, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='minTemp',
                             description='minimum temperature measurement',
                             hidden=False, enum=None, offset=0x490, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='minVCCINT',
                             description='minimum VCCINT measurement',
                             hidden=False, enum=None, offset=0x494, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='minVCCAUX',
                             description='minimum VCCAUX measurement',
                             hidden=False, enum=None, offset=0x498, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='minVBRAM',
                             description='minimum VBRAM measurement',
                             hidden=False, enum=None, offset=0x49c, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='i2C_Address',
                             description='I2C Address',
                             hidden=False, enum=None, offset=0x4e0, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='flagRegister',
                             description='Flag Register',
                             hidden=False, enum=None, offset=0x4fc, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='configurationRegister',
                             description='Configuration Registers',
                             hidden=False, enum=None, offset=0x500, bitSize=128, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='sequenceRegister8',
                             description='Sequence Register 8',
                             hidden=False, enum=None, offset=0x518, bitSize=32, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='sequenceReg9',
                             description='Sequence Register 9',
                             hidden=False, enum=None, offset=0x51c, bitSize=32, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='sequenceReg_7_0',
                             description='Sequence Register [7:0]',
                             hidden=False, enum=None, offset=0x520, bitSize=256, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='alarmThresholdReg_8_0',
                             description='Alarm Threshold Register [8:0]',
                             hidden=False, enum=None, offset=0x540, bitSize=288, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='alarmThresholdReg12',
                             description='Alarm Threshold Register 12',
                             hidden=False, enum=None, offset=0x570, bitSize=32, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='alarmThresholdReg16',
                             description='Alarm Threshold Register 16',
                             hidden=False, enum=None, offset=0x580, bitSize=32, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='alarmThresholdReg_25_16',
                             description='Alarm Threshold Register [25:16]',
                             hidden=False, enum=None, offset=0x580, bitSize=256, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='vUSER',
                             description='VUSER[4:0] supply monitor measurement',
                             hidden=False, enum=None, offset=0x600, bitSize=128, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='mAX_VUSER',
                             description='Maximum VUSER[4:0] supply monitor measurement',
                             hidden=False, enum=None, offset=0x680, bitSize=128, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='mIN_VUSER',
                             description='Minimum VUSER[4:0] supply monitor measurement',
                             hidden=False, enum=None, offset=0x6a0, bitSize=128, bitOffset=0, base='uint', mode='RO'))

    return dev
