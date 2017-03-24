#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Device Dac38J84
#-----------------------------------------------------------------------------
# File       : Dac38J84.py
# Created    : 2016-12-01
# Last update: 2016-12-01
#-----------------------------------------------------------------------------
# Description:
# Device creator for Dac38J84
# Auto created from ../surf/devices/Ti/dac38j84/yaml/Dac38J84.yaml
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

def create(name='dac38J84', offset=0, memBase=None, hidden=False):

    dev = pyrogue.Device(name=name,memBase=memBase,offset=offset,
                         hidden=hidden,size=0x200,
                         description='DAC38J84 Module')

    dev.add(pyrogue.Variable(name='dacReg_0',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_1',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_2',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_3',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xc, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_4',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x10, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_5',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x14, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_6',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x18, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_7',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_8',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x20, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_9',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x24, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_10',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x28, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_11',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x2c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_12',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x30, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_13',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x34, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_14',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x38, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_15',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x3c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_16',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x40, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_17',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x44, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_18',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x48, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_19',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x4c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_20',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x50, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_21',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x54, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_22',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x58, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_23',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x5c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_24',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x60, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_25',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x64, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_26',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x68, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_27',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x6c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_28',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x70, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_29',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x74, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_30',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x78, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_31',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x7c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_32',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x80, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_33',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x84, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_34',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x88, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_35',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x8c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_36',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x90, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_37',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x94, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_38',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x98, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_39',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x9c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_40',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xa0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_41',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xa4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_42',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xa8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_43',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xac, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_44',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xb0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_45',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xb4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_46',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xb8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_47',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xbc, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_48',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xc0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_49',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xc4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_50',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xc8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_51',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xcc, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_52',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xd0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_53',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xd4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_54',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xd8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_55',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xdc, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_56',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xe0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_57',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xe4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_58',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xe8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_59',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xec, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_60',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xf0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_61',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xf4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_62',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xf8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_63',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xfc, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_64',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x100, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_65',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x104, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_66',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x108, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_67',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x10c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_68',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x110, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_69',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x114, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_70',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x118, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_71',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x11c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_72',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x120, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_73',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x124, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_74',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x128, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_75',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x12c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_76',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x130, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_77',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x134, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_78',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x138, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_79',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x13c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_80',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x140, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_81',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x144, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_82',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x148, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_83',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x14c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_84',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x150, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_85',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x154, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_86',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x158, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_87',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x15c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_88',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x160, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_89',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x164, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_90',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x168, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_91',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x16c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_92',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x170, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_93',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x174, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_94',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x178, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_95',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x17c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_96',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x180, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_97',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x184, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_98',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x188, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_99',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x18c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_100',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x190, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_101',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x194, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_102',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x198, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_103',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x19c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_104',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1a0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_105',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1a4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_106',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1a8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_107',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1ac, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_108',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1b0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_109',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1b4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_110',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1b8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_111',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1bc, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_112',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1c0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_113',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1c4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_114',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1c8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_115',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1cc, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_116',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1d0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_117',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1d4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_118',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1d8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_119',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1dc, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_120',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1e0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_121',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1e4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_122',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1e8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_123',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1ec, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_124',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1f0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dacReg_125',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1f4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='laneBufferDelay',
                             description='Lane Buffer Delay',
                             hidden=False, enum=None, offset=0x1c, bitSize=5, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='temperature',
                             description='Temperature',
                             hidden=False, enum=None, offset=0x1c, bitSize=8, bitOffset=8, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='linkErrCnt_0',
                             description='Link Error Count',
                             hidden=False, enum=None, offset=0x104, bitSize=16, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='linkErrCnt_1',
                             description='Link Error Count',
                             hidden=False, enum=None, offset=0x108, bitSize=16, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='readFifoEmpty_0',
                             description='ReadFifoEmpty',
                             hidden=False, enum=None, offset=0x190, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='readFifoEmpty_1',
                             description='ReadFifoEmpty',
                             hidden=False, enum=None, offset=0x194, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='readFifoUnderflow_0',
                             description='ReadFifoUnderflow',
                             hidden=False, enum=None, offset=0x190, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='readFifoUnderflow_1',
                             description='ReadFifoUnderflow',
                             hidden=False, enum=None, offset=0x194, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='readFifoFull_0',
                             description='ReadFifoFull',
                             hidden=False, enum=None, offset=0x190, bitSize=1, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='readFifoFull_1',
                             description='ReadFifoFull',
                             hidden=False, enum=None, offset=0x194, bitSize=1, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='readFifoOverflow_0',
                             description='ReadFifoOverflow',
                             hidden=False, enum=None, offset=0x190, bitSize=1, bitOffset=3, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='readFifoOverflow_1',
                             description='ReadFifoOverflow',
                             hidden=False, enum=None, offset=0x194, bitSize=1, bitOffset=3, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='dispErr_0',
                             description='DispErr',
                             hidden=False, enum=None, offset=0x190, bitSize=1, bitOffset=8, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='dispErr_1',
                             description='DispErr',
                             hidden=False, enum=None, offset=0x194, bitSize=1, bitOffset=8, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='notitableErr_0',
                             description='NotitableErr',
                             hidden=False, enum=None, offset=0x190, bitSize=1, bitOffset=9, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='notitableErr_1',
                             description='NotitableErr',
                             hidden=False, enum=None, offset=0x194, bitSize=1, bitOffset=9, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='codeSyncErr_0',
                             description='CodeSyncErr',
                             hidden=False, enum=None, offset=0x190, bitSize=1, bitOffset=10, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='codeSyncErr_1',
                             description='CodeSyncErr',
                             hidden=False, enum=None, offset=0x194, bitSize=1, bitOffset=10, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='firstDataMatchErr_0',
                             description='FirstDataMatchErr',
                             hidden=False, enum=None, offset=0x190, bitSize=1, bitOffset=11, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='firstDataMatchErr_1',
                             description='FirstDataMatchErr',
                             hidden=False, enum=None, offset=0x194, bitSize=1, bitOffset=11, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='elasticBuffOverflow_0',
                             description='ElasticBuffOverflow',
                             hidden=False, enum=None, offset=0x190, bitSize=1, bitOffset=12, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='elasticBuffOverflow_1',
                             description='ElasticBuffOverflow',
                             hidden=False, enum=None, offset=0x194, bitSize=1, bitOffset=12, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='linkConfigErr_0',
                             description='LinkConfigErr',
                             hidden=False, enum=None, offset=0x190, bitSize=1, bitOffset=13, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='linkConfigErr_1',
                             description='LinkConfigErr',
                             hidden=False, enum=None, offset=0x194, bitSize=1, bitOffset=13, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='frameAlignErr_0',
                             description='FrameAlignErr',
                             hidden=False, enum=None, offset=0x190, bitSize=1, bitOffset=14, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='frameAlignErr_1',
                             description='FrameAlignErr',
                             hidden=False, enum=None, offset=0x194, bitSize=1, bitOffset=14, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='multiFrameAlignErr_0',
                             description='MultiFrameAlignErr',
                             hidden=False, enum=None, offset=0x190, bitSize=1, bitOffset=15, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='multiFrameAlignErr_1',
                             description='MultiFrameAlignErr',
                             hidden=False, enum=None, offset=0x194, bitSize=1, bitOffset=15, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='serdes1pllAlarm',
                             description='Serdes1pllAlarm',
                             hidden=False, enum=None, offset=0x1b0, bitSize=1, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='serdes0pllAlarm',
                             description='Serdes0pllAlarm',
                             hidden=False, enum=None, offset=0x1b0, bitSize=1, bitOffset=3, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='sysRefAlarms',
                             description='SysRefAlarms',
                             hidden=False, enum=None, offset=0x1b0, bitSize=4, bitOffset=12, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='laneLoss',
                             description='LaneLoss',
                             hidden=False, enum=None, offset=0x1b4, bitSize=8, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='laneAlarm',
                             description='LaneAlarm',
                             hidden=False, enum=None, offset=0x1b4, bitSize=8, bitOffset=8, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='iD',
                             description='Serials and IDs',
                             hidden=False, enum=None, offset=0x1fc, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='enableTx',
                             description='EnableTx',
                             hidden=False, enum=None, offset=0xc, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='initJesd',
                             description='InitJesd',
                             hidden=False, enum=None, offset=0x128, bitSize=5, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Command(name='clearAlarms',
                            description='Clear all the DAC alarms',
                            hidden=False, base='None',
                            function="""\
                                     dev.dacReg_100.set(0)
                                     dev.dacReg_101.set(0)
                                     dev.dacReg_102.set(0)
                                     dev.dacReg_103.set(0)
                                     dev.dacReg_104.set(0)
                                     dev.dacReg_105.set(0)
                                     dev.dacReg_106.set(0)
                                     dev.dacReg_107.set(0)
                                     dev.dacReg_108.set(0)
                                     """))

    dev.add(pyrogue.Command(name='initDac',
                            description='Initialization sequence for the DAC JESD core',
                            hidden=False, base='None',
                            function="""\
                                     dev.enableTx.set(0)
                                     dev.initJesd.set(30)
                                     dev.initJesd.set(1)
                                     dev.enableTx.set(1)
                                     """))

    return dev
