#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Device Dac38J84
#-----------------------------------------------------------------------------
# File       : Dac38J84.py
# Author     : Ryan Herbst, rherbst@slac.stanford.edu
# Created    : 2016-10-24
# Last update: 2016-10-24
#-----------------------------------------------------------------------------
# Description:
# Device creator for Dac38J84
# Auto created from ../surf/devices/Ti/dac38j84/yaml/Dac38J84.yaml
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
                         hidden=hidden,size=0x200,
                         description='DAC38J84 Module')

    dev.add(pyrogue.Variable(name='DacReg_0',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_1',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_2',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_3',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xc, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_4',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x10, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_5',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x14, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_6',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x18, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_7',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_8',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x20, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_9',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x24, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_10',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x28, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_11',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x2c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_12',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x30, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_13',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x34, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_14',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x38, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_15',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x3c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_16',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x40, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_17',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x44, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_18',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x48, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_19',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x4c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_20',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x50, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_21',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x54, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_22',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x58, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_23',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x5c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_24',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x60, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_25',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x64, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_26',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x68, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_27',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x6c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_28',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x70, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_29',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x74, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_30',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x78, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_31',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x7c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_32',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x80, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_33',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x84, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_34',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x88, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_35',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x8c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_36',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x90, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_37',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x94, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_38',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x98, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_39',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x9c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_40',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xa0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_41',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xa4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_42',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xa8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_43',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xac, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_44',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xb0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_45',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xb4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_46',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xb8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_47',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xbc, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_48',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xc0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_49',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xc4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_50',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xc8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_51',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xcc, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_52',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xd0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_53',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xd4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_54',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xd8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_55',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xdc, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_56',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xe0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_57',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xe4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_58',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xe8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_59',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xec, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_60',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xf0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_61',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xf4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_62',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xf8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_63',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0xfc, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_64',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x100, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_65',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x104, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_66',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x108, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_67',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x10c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_68',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x110, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_69',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x114, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_70',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x118, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_71',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x11c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_72',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x120, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_73',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x124, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_74',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x128, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_75',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x12c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_76',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x130, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_77',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x134, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_78',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x138, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_79',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x13c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_80',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x140, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_81',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x144, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_82',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x148, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_83',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x14c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_84',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x150, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_85',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x154, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_86',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x158, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_87',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x15c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_88',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x160, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_89',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x164, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_90',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x168, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_91',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x16c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_92',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x170, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_93',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x174, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_94',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x178, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_95',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x17c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_96',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x180, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_97',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x184, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_98',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x188, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_99',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x18c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_100',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x190, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_101',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x194, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_102',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x198, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_103',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x19c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_104',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1a0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_105',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1a4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_106',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1a8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_107',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1ac, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_108',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1b0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_109',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1b4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_110',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1b8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_111',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1bc, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_112',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1c0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_113',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1c4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_114',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1c8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_115',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1cc, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_116',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1d0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_117',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1d4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_118',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1d8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_119',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1dc, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_120',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1e0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_121',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1e4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_122',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1e8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_123',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1ec, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_124',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1f0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DacReg_125',
                             description='DAC Registers[125:0]',
                             hidden=False, enum=None, offset=0x1f4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='LaneBufferDelay',
                             description='Lane Buffer Delay',
                             hidden=False, enum=None, offset=0x1c, bitSize=5, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='Temperature',
                             description='Temperature',
                             hidden=False, enum=None, offset=0x7, bitSize=8, bitOffset=24, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='LinkErrCnt_0',
                             description='Link Error Count',
                             hidden=False, enum=None, offset=0x104, bitSize=16, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='LinkErrCnt_1',
                             description='Link Error Count',
                             hidden=False, enum=None, offset=0x108, bitSize=16, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='ReadFifoEmpty_0',
                             description='ReadFifoEmpty',
                             hidden=False, enum=None, offset=0x190, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='ReadFifoEmpty_1',
                             description='ReadFifoEmpty',
                             hidden=False, enum=None, offset=0x194, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='ReadFifoUnderflow_0',
                             description='ReadFifoUnderflow',
                             hidden=False, enum=None, offset=0x190, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='ReadFifoUnderflow_1',
                             description='ReadFifoUnderflow',
                             hidden=False, enum=None, offset=0x194, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='ReadFifoFull_0',
                             description='ReadFifoFull',
                             hidden=False, enum=None, offset=0x190, bitSize=1, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='ReadFifoFull_1',
                             description='ReadFifoFull',
                             hidden=False, enum=None, offset=0x194, bitSize=1, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='ReadFifoOverflow_0',
                             description='ReadFifoOverflow',
                             hidden=False, enum=None, offset=0x190, bitSize=1, bitOffset=3, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='ReadFifoOverflow_1',
                             description='ReadFifoOverflow',
                             hidden=False, enum=None, offset=0x194, bitSize=1, bitOffset=3, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='DispErr_0',
                             description='DispErr',
                             hidden=False, enum=None, offset=0x64, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='DispErr_1',
                             description='DispErr',
                             hidden=False, enum=None, offset=0x68, bitSize=1, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='NotitableErr_0',
                             description='NotitableErr',
                             hidden=False, enum=None, offset=0x64, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='NotitableErr_1',
                             description='NotitableErr',
                             hidden=False, enum=None, offset=0x68, bitSize=1, bitOffset=1, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='CodeSyncErr_0',
                             description='CodeSyncErr',
                             hidden=False, enum=None, offset=0x64, bitSize=1, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='CodeSyncErr_1',
                             description='CodeSyncErr',
                             hidden=False, enum=None, offset=0x68, bitSize=1, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='FirstDataMatchErr_0',
                             description='FirstDataMatchErr',
                             hidden=False, enum=None, offset=0x64, bitSize=1, bitOffset=3, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='FirstDataMatchErr_1',
                             description='FirstDataMatchErr',
                             hidden=False, enum=None, offset=0x68, bitSize=1, bitOffset=3, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='ElasticBuffOverflow_0',
                             description='ElasticBuffOverflow',
                             hidden=False, enum=None, offset=0x64, bitSize=1, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='ElasticBuffOverflow_1',
                             description='ElasticBuffOverflow',
                             hidden=False, enum=None, offset=0x68, bitSize=1, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='LinkConfigErr_0',
                             description='LinkConfigErr',
                             hidden=False, enum=None, offset=0x64, bitSize=1, bitOffset=5, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='LinkConfigErr_1',
                             description='LinkConfigErr',
                             hidden=False, enum=None, offset=0x68, bitSize=1, bitOffset=5, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='FrameAlignErr_0',
                             description='FrameAlignErr',
                             hidden=False, enum=None, offset=0x64, bitSize=1, bitOffset=6, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='FrameAlignErr_1',
                             description='FrameAlignErr',
                             hidden=False, enum=None, offset=0x68, bitSize=1, bitOffset=6, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='MultiFrameAlignErr_0',
                             description='MultiFrameAlignErr',
                             hidden=False, enum=None, offset=0x64, bitSize=1, bitOffset=7, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='MultiFrameAlignErr_1',
                             description='MultiFrameAlignErr',
                             hidden=False, enum=None, offset=0x68, bitSize=1, bitOffset=7, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='Serdes1pllAlarm',
                             description='Serdes1pllAlarm',
                             hidden=False, enum=None, offset=0x1b0, bitSize=1, bitOffset=2, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='Serdes0pllAlarm',
                             description='Serdes0pllAlarm',
                             hidden=False, enum=None, offset=0x1b0, bitSize=1, bitOffset=3, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='SysRefAlarms',
                             description='SysRefAlarms',
                             hidden=False, enum=None, offset=0x6c, bitSize=4, bitOffset=4, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='LaneLoss',
                             description='LaneLoss',
                             hidden=False, enum=None, offset=0x1b4, bitSize=8, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='LaneAlarm',
                             description='LaneAlarm',
                             hidden=False, enum=None, offset=0x6d, bitSize=8, bitOffset=8, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='ID',
                             description='Serials and IDs',
                             hidden=False, enum=None, offset=0x1fc, bitSize=32, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='EnableTx',
                             description='EnableTx',
                             hidden=False, enum=None, offset=0xc, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='InitJesd',
                             description='InitJesd',
                             hidden=False, enum=None, offset=0x128, bitSize=5, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Command(name='ClearAlarms',
                            description='Clear all the DAC alarms',
                            hidden=False, base=None,
                            function="""\
                                     dev.DacReg_100.set(0)
                                     dev.DacReg_101.set(0)
                                     dev.DacReg_102.set(0)
                                     dev.DacReg_103.set(0)
                                     dev.DacReg_104.set(0)
                                     dev.DacReg_105.set(0)
                                     dev.DacReg_106.set(0)
                                     dev.DacReg_107.set(0)
                                     dev.DacReg_108.set(0)
                                     """

    dev.add(pyrogue.Command(name='InitDac',
                            description='Initialization sequence for the DAC JESD core',
                            hidden=False, base=None,
                            function="""\
                                     dev.EnableTx.set(0)
                                     dev.InitJesd.set(30)
                                     dev.InitJesd.set(1)
                                     dev.EnableTx.set(1)
                                     """

