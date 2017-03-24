#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Device Lmk04828
#-----------------------------------------------------------------------------
# File       : Lmk04828.py
# Created    : 2016-12-01
# Last update: 2016-12-01
#-----------------------------------------------------------------------------
# Description:
# Device creator for Lmk04828
# Auto created from ../surf/devices/Ti/lmk04828/yaml/Lmk04828.yaml
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

def create(name='lmk04828', offset=0, memBase=None, hidden=False):

    dev = pyrogue.Device(name=name,memBase=memBase,offset=offset,
                         hidden=hidden,size=0x800,
                         description='LMK04828 Module')

    dev.add(pyrogue.Variable(name='lmkReg_0x0100',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x400, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0101',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x404, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0103',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x40c, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0104',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x410, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0105',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x414, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0106',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x418, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0107',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x41c, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0108',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x420, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0109',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x424, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x010B',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x42c, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x010C',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x430, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x010D',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x434, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x010E',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x438, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x010F',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x43c, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0110',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x440, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0111',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x444, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0113',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x44c, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0114',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x450, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0115',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x454, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0116',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x458, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0117',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x45c, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0118',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x460, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0119',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x464, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x011B',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x46c, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x011C',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x470, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x011D',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x474, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x011E',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x478, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x011F',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x47c, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0120',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x480, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0121',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x484, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0123',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x48c, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0124',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x490, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0125',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x494, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0126',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x498, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0127',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x49c, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0128',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x4a0, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0129',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x4a4, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x012B',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x4ac, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x012C',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x4b0, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x012D',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x4b4, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x012E',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x4b8, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x012F',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x4bc, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0130',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x4c0, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0131',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x4c4, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0133',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x4cc, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0134',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x4d0, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0135',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x4d4, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0136',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x4d8, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0137',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x4dc, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0138',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x4e0, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0139',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x4e4, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x013A',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x4e8, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x013B',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x4ec, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x013C',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x4f0, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x013D',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x4f4, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x013E',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x4f8, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x013F',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x4fc, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0140',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x500, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0141',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x504, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0142',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x508, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0143',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x50c, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0144',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x510, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0145',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x514, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0146',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x518, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0147',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x51c, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0148',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x520, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0149',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x524, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x014A',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x528, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x014B',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x52c, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x014C',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x530, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x014D',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x534, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x014E',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x538, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x014F',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x53c, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0150',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x540, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0151',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x544, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0152',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x548, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0153',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x54c, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0154',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x550, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0155',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x554, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0156',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x558, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0157',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x55c, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0158',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x560, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0159',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x564, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x015A',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x568, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x015B',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x56c, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x015C',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x570, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x015D',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x574, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x015E',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x578, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x015F',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x57c, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0160',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x580, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0161',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x584, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0162',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x588, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0163',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x58c, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0164',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x590, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0165',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x594, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0166',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x598, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0167',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x59c, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0168',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x5a0, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0169',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x5a4, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x016A',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x5a8, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Command(name='pwrDwnSysRef',
                            description='Powerdown the sysref lines',
                            hidden=False, base='None',
                            function="""\
                                     dev.enableSysRef.set(0)
                                     """))

    dev.add(pyrogue.Command(name='pwrUpSysRef',
                            description='Powerup the sysref lines',
                            hidden=False, base='None',
                            function="""\
                                     dev.enableSysRef.set(3)
                                     """))

    dev.add(pyrogue.Command(name='initLmk',
                            description='Synchronise LMK internal counters. Warning this function will power off and power on all the system clocks',
                            hidden=False, base='None',
                            function="""\
                                     dev.enableSysRef.set(0)
                                     dev.enableSync.set(0)
                                     dev.usleep.set(1000000)
                                     dev.syncBit.set(1)
                                     dev.syncBit.set(0)
                                     dev.usleep.set(1000000)
                                     dev.enableSysRef.set(3)
                                     dev.enableSync.set(255)
                                     """))

    dev.add(pyrogue.Variable(name='syncBit',
                             description='SyncBit',
                             hidden=False, enum=None, offset=0x50c, bitSize=1, bitOffset=5, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='enableSync',
                             description='EnableSync',
                             hidden=False, enum=None, offset=0x510, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='enableSysRef',
                             description='EnableSysRef',
                             hidden=False, enum=None, offset=0x4e4, bitSize=2, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='iD_VNDR_LOWER',
                             description='ID_VNDR_LOWER',
                             hidden=False, enum=None, offset=0x34, bitSize=8, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='iD_VNDR_UPPER',
                             description='ID_VNDR_UPPER',
                             hidden=False, enum=None, offset=0x30, bitSize=8, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='iD_MASKREV',
                             description='ID_MASKREV',
                             hidden=False, enum=None, offset=0x18, bitSize=8, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='iD_PROD_LOWER',
                             description='ID_PROD_LOWER',
                             hidden=False, enum=None, offset=0x14, bitSize=8, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='iD_PROD_UPPER',
                             description='ID_PROD_UPPER',
                             hidden=False, enum=None, offset=0x10, bitSize=8, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='iD_DEVICE_TYPE',
                             description='ID_DEVICE_TYPE',
                             hidden=False, enum=None, offset=0xc, bitSize=8, bitOffset=0, base='uint', mode='RO'))

    dev.add(pyrogue.Variable(name='lmkReg_0x017D',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x5f4, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x017C',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x5f0, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0174',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x5d0, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x0173',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x5cc, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x016E',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x5b8, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x016D',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x5b4, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x016C',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x5b0, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lmkReg_0x016B',
                             description='LMK Registers',
                             hidden=False, enum=None, offset=0x5ac, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    return dev
