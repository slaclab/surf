#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Device Adc16Dx370
#-----------------------------------------------------------------------------
# File       : Adc16Dx370.py
# Created    : 2016-12-01
# Last update: 2016-12-01
#-----------------------------------------------------------------------------
# Description:
# Device creator for Adc16Dx370
# Auto created from ../surf/devices/Ti/adc16dx370/yaml/Adc16Dx370.yaml
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

def create(name='adc16Dx370', offset=0, memBase=None, hidden=False):

    dev = pyrogue.Device(name=name,memBase=memBase,offset=offset,
                         hidden=hidden,size=0x100000,
                         description='ADC16Dx370 Module')

    dev.add(pyrogue.Variable(name='adcReg_0x0000',
                             description='ADC Control Registers',
                             hidden=False, enum=None, offset=0x0, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='adcReg_0x0002',
                             description='ADC Control Registers',
                             hidden=False, enum=None, offset=0x8, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='adcReg_0x0003',
                             description='ADC Control Registers',
                             hidden=False, enum=None, offset=0xc, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='adcReg_0x0004',
                             description='ADC Control Registers',
                             hidden=False, enum=None, offset=0xc, bitSize=8, bitOffset=24, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='adcReg_0x0005',
                             description='ADC Control Registers',
                             hidden=False, enum=None, offset=0x14, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='adcReg_0x0006',
                             description='ADC Control Registers',
                             hidden=False, enum=None, offset=0x18, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='adcReg_0x000C',
                             description='ADC Control Registers',
                             hidden=False, enum=None, offset=0x30, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='adcReg_0x000D',
                             description='ADC Control Registers',
                             hidden=False, enum=None, offset=0x34, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='adcReg_0x000E',
                             description='ADC Control Registers',
                             hidden=False, enum=None, offset=0x38, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='adcReg_0x000F',
                             description='ADC Control Registers',
                             hidden=False, enum=None, offset=0x3c, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='adcReg_0x0010',
                             description='ADC Control Registers',
                             hidden=False, enum=None, offset=0x40, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='adcReg_0x0011',
                             description='ADC Control Registers',
                             hidden=False, enum=None, offset=0x44, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='adcReg_0x0012',
                             description='ADC Control Registers',
                             hidden=False, enum=None, offset=0x48, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='adcReg_0x0013',
                             description='ADC Control Registers',
                             hidden=False, enum=None, offset=0x4c, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='adcReg_0x0014',
                             description='ADC Control Registers',
                             hidden=False, enum=None, offset=0x50, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='adcReg_0x0015',
                             description='ADC Control Registers',
                             hidden=False, enum=None, offset=0x54, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='adcReg_0x0019',
                             description='ADC Control Registers',
                             hidden=False, enum=None, offset=0x64, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='adcReg_0x003B',
                             description='ADC Control Registers',
                             hidden=False, enum=None, offset=0xec, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='adcReg_0x003C',
                             description='ADC Control Registers',
                             hidden=False, enum=None, offset=0xf0, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='adcReg_0x003D',
                             description='ADC Control Registers',
                             hidden=False, enum=None, offset=0xf4, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='adcReg_0x0047',
                             description='ADC Control Registers',
                             hidden=False, enum=None, offset=0x11c, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='adcReg_0x0060',
                             description='ADC Control Registers',
                             hidden=False, enum=None, offset=0x180, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='adcReg_0x0061',
                             description='ADC Control Registers',
                             hidden=False, enum=None, offset=0x184, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='adcReg_0x0062',
                             description='ADC Control Registers',
                             hidden=False, enum=None, offset=0x188, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='adcReg_0x0063',
                             description='ADC Control Registers',
                             hidden=False, enum=None, offset=0x18c, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='adcReg_0x0070',
                             description='ADC Control Registers',
                             hidden=False, enum=None, offset=0x1c0, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='iD_DEVICE_TYPE',
                             description='ID_DEVICE_TYPE',
                             hidden=False, enum=None, offset=0xc, bitSize=8, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='iD_PROD_UPPER',
                             description='ID_PROD_UPPER',
                             hidden=False, enum=None, offset=0x10, bitSize=8, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='iD_PROD_LOWER',
                             description='ID_PROD_LOWER',
                             hidden=False, enum=None, offset=0x14, bitSize=8, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='iD_MASKREV',
                             description='ID_MASKREV',
                             hidden=False, enum=None, offset=0x18, bitSize=8, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='iD_VNDR_UPPER',
                             description='ID_VNDR_UPPER',
                             hidden=False, enum=None, offset=0x30, bitSize=8, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='iD_VNDR_LOWER',
                             description='ID_VNDR_LOWER',
                             hidden=False, enum=None, offset=0x34, bitSize=8, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='clock_ready',
                             description='Clock_ready',
                             hidden=False, enum=None, offset=0x1b0, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='calibration_done',
                             description='Calibration_done',
                             hidden=False, enum=None, offset=0x1b0, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='pLL_lock',
                             description='PLL_lock',
                             hidden=False, enum=None, offset=0x1b0, bitSize=1, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='aligned_to_sysref',
                             description='Aligned_to_sysref',
                             hidden=False, enum=None, offset=0x1b0, bitSize=1, bitOffset=3, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='realigned_to_sysref',
                             description='Realigned_to_sysref',
                             hidden=False, enum=None, offset=0x1b0, bitSize=1, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='sync_form_FPGA',
                             description='Sync_form_FPGA',
                             hidden=False, enum=None, offset=0x1b0, bitSize=1, bitOffset=5, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='link_active',
                             description='Link_active',
                             hidden=False, enum=None, offset=0x1b0, bitSize=1, bitOffset=6, base='uint', mode='RO'))

    dev.add(pyrogue.Command(name='powerDown',
                            description='PowerDown',
                            hidden=False, base='None',
                            function="""\
                                     dev.adcReg_0x0002.set(3)
                                     """))

    dev.add(pyrogue.Command(name='powerUp',
                            description='PowerUp',
                            hidden=False, base='None',
                            function="""\
                                     dev.adcReg_0x0002.set(0)
                                     """))

    dev.add(pyrogue.Command(name='calibrateAdc',
                            description='CalibrateAdc',
                            hidden=False, base='None',
                            function="""\
                                     dev.powerDown.set(1)
                                     dev.usleep.set(1000000)
                                     dev.powerUp.set(1)
                                     """))

    return dev
