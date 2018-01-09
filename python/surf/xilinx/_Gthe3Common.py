#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Gthe3Common
#-----------------------------------------------------------------------------
# File       : Gthe3Common.py
# Created    : 2017-04-12
#-----------------------------------------------------------------------------
# Description:
# PyRogue Gthe3Common - QPLL
#-----------------------------------------------------------------------------
# This file is part of the rogue software platform. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the rogue software platform, including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr

class Gthe3Common(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.add(pr.RemoteVariable(
            offset=0x0008 << 2,
            bitSize=16,
            mode='RW',
            name='QPLL0_CFG0'))
        
        self.add(pr.RemoteVariable(
            offset=0x0009 << 2,
            bitSize=16,
            mode='RW',
            name='COMMON_CFG0'))
        
        self.add(pr.RemoteVariable(
            offset=0x000B << 2,
            bitSize=16,
            mode='RW',
            name='RSVD_ATTR0'))
        
        self.add(pr.RemoteVariable(
            offset=0x0010 << 2,
            bitSize=16,
            mode='RW',
            name='QPLL0_CFG1'))
        
        self.add(pr.RemoteVariable(
            offset=0x0011 << 2,
            bitSize=16,
            mode='RW',
            name='QPLL0_CFG2'))
        
        self.add(pr.RemoteVariable(
            offset=0x0012 << 2,
            bitSize=16,
            mode='RW',
            name='QPLL0_LOCK_CFG'))
        
        self.add(pr.RemoteVariable(
            offset=0x0013 << 2,
            bitSize=16,
            mode='RW',
            name='QPLL0_INIT_CFG0'))
        
        self.add(pr.RemoteVariable(
            offset=0x0014 << 2,
            bitSize=8,
            bitOffset=8,
            mode='RW',
            name='QPLL0_INIT_CFG1'))

        self.add(pr.RemoteVariable(
            offset=0x0014 << 2,
            bitSize=8,
            enum = __FBDIV_ENUM,
            mode='RW',
            name='QPLL0_FBDIV'))

        self.add(pr.RemoteVariable(
            offset=0x0015 << 2,
            bitSize=16,
            mode='RW',
            name='QPLL0_CFG3'))

        self.add(pr.RemoteVariable(
            offset=0x0016 << 2,
            bitSize=10,
            mode='RW',
            name='QPLL0_CP'))

        self.add(pr.RemoteVariable(
            offset=0x0018 << 2,
            bitSize=5,
            bitOffset=7,
            enum = __REFCLK_DIV_ENUM,
            mode='RW',
            name='QPLL0_REFCLK_DIV'))

        self.add(pr.RemoteVariable(
            offset=0x0019 << 2,
            bitSize=10,
            mode='RW',
            name='QPLL0_LPF'))

        self.add(pr.RemoteVariable(
            offset=0x001A << 2,
            bitSize=16,
            mode='RW',
            name='QPLL0_CFG1_G3'))

        self.add(pr.RemoteVariable(
            offset=0x001B << 2,
            bitSize=16,
            mode='RW',
            name='QPLL0_CFG2_G3'))

        self.add(pr.RemoteVariable(
            offset=0x001C << 2,
            bitSize=10,
            mode='RW',
            name='QPLL0_LPF_G3'))

        self.add(pr.RemoteVariable(
            offset=0x001D << 2,
            bitSize=16,
            mode='RW',
            name='QPLL0_LOCK_CFG_G3'))

        self.add(pr.RemoteVariable(
            offset=0x001E << 2,
            bitSize=16,
            mode='RW',
            name='RSVD_ATTR1'))

        self.add(pr.RemoteVariable(
            offset=0x001F << 2,
            bitSize=8,
            bitOffset=8,
            enum = __FBDIV_ENUM,
            mode='RW',
            name='QPLL0_FBDIV_G3'))

        self.add(pr.RemoteVariable(
            offset=0x001F << 2,
            bitSize=2,
            mode='RW',
            name='RXRECCLKOUT0_SEL'))

        self.add(pr.RemoteVariable(
            offset=0x0020 << 2,
            bitSize=16,
            mode='RW',
            name='QPLL0_SDM_CFG0'))

        self.add(pr.RemoteVariable(
            offset=0x0021 << 2,
            bitSize=16,
            mode='RW',
            name='QPLL0_SDM_CFG1'))

        self.add(pr.RemoteVariable(
            offset=0x0022 << 2,
            bitSize=16,
            mode='RW',
            name='SDM0INITSEED0_0'))

        self.add(pr.RemoteVariable(
            offset=0x0023 << 2,
            bitSize=8,
            mode='RW',
            name='SDM0INITSEED0_1'))

        self.add(pr.RemoteVariable(
            offset=0x0024 << 2,
            bitSize=16,
            mode='RW',
            name='QPLL0_SDM_CFG2'))

        self.add(pr.RemoteVariable(
            offset=0x0025 << 2,
            bitSize=10,
            mode='RW',
            name='QPLL0_CP_G3'))

        self.add(pr.RemoteVariable(
            offset=0x0028 << 2,
            bitSize=16,
            mode='RW',
            name='SDM0DATA1_0'))

        self.add(pr.RemoteVariable(
            offset=0x0029 << 2,
            bitSize=1,
            bitOffset=10,
            mode='RW',
            name='SDM0_WIDTH_PIN_SEL'))

        self.add(pr.RemoteVariable(
            offset=0x0029 << 2,
            bitSize=1,
            bitOffset=9,
            mode='RW',
            name='SDM0_DATA_PIN_SEL'))

        self.add(pr.RemoteVariable(
            offset=0x0029 << 2,
            bitSize=9,
            mode='RW',
            name='SDM0DATA1_1'))

        self.add(pr.RemoteVariable(
            offset=0x0030 << 2,
            bitSize=16,
            mode='RW',
            name='QPLL0_CFG4'))

        self.add(pr.RemoteVariable(
            offset=0x0081 << 2,
            bitSize=16,
            mode='RW',
            name='BIAS_CFG0'))

        self.add(pr.RemoteVariable(
            offset=0x0082 << 2,
            bitSize=16,
            mode='RW',
            name='BIAS_CFG1'))

        self.add(pr.RemoteVariable(
            offset=0x0083 << 2,
            bitSize=16,
            mode='RW',
            name='BIAS_CFG2'))

        self.add(pr.RemoteVariable(
            offset=0x0084 << 2,
            bitSize=16,
            mode='RW',
            name='BIAS_CFG3'))

        self.add(pr.RemoteVariable(
            offset=0x0085 << 2,
            bitSize=10,
            mode='RW',
            name='BIAS_CFG_RSVD'))

        self.add(pr.RemoteVariable(
            offset=0x0086 << 2,
            bitSize=16,
            mode='RW',
            name='BIAS_CFG4'))

        self.add(pr.RemoteVariable(
            offset=0x0088 << 2,
            bitSize=16,
            mode='RW',
            name='QPLL1_CFG0'))

        self.add(pr.RemoteVariable(
            offset=0x0089 << 2,
            bitSize=16,
            mode='RW',
            name='COMMON_CFG1'))

        self.add(pr.RemoteVariable(
            offset=0x008B << 2,
            bitSize=16,
            mode='RW',
            name='POR_CFG'))

        self.add(pr.RemoteVariable(
            offset=0x0090 << 2,
            bitSize=16,
            mode='RW',
        name='QPLL1_CFG1'))

        self.add(pr.RemoteVariable(
            offset=0x0091 << 2,
            bitSize=16,
            mode='RW',
            name='QPLL1_CFG2'))

        self.add(pr.RemoteVariable(
            offset=0x0092 << 2,
            bitSize=16,
            mode='RW',
            name='QPLL1_LOCK_CFG'))

        self.add(pr.RemoteVariable(
            offset=0x0093 << 2,
            bitSize=16,
            mode='RW',
            name='QPLL1_INIT_CFG0'))

        self.add(pr.RemoteVariable(
            offset=0x0094 << 2,
            bitSize=8,
            bitOffset=8
            mode='RW',
            name='QPLL1_INIT_CFG1'))

        self.add(pr.RemoteVariable(
            offset=0x0094 << 2,
            bitSize=8,
            enum = __FBDIV_ENUM,
            mode='RW',
            name='QPLL1_FBDIV_G'))

        self.add(pr.RemoteVariable(
            offset=0x0095 << 2,
            bitSize=16,
            mode='RW',
            name='QPLL1_CFG3'))

        self.add(pr.RemoteVariable(
            offset=0x0096 << 2,
            bitSize=10,
            mode='RW',
            name='QPLL1_CP'))

        self.add(pr.RemoteVariable(
            offset=0x0098 << 2,
            bitSize=1,
            bitOffset=13,
            mode='RW',
            name='SARC_SEL'))

        self.add(pr.RemoteVariable(
            offset=0x0098 << 2,
            bitSize=1,
            bitOffset=12,
            mode='RW',
            name='SARC_EN'))

        self.add(pr.RemoteVariable(
            offset=0x0098 << 2,
            bitSize=5,
            bitOffset=7,
            enum = __REFCLK_DIV_ENUM,
            mode='RW',
            name='QPLL1_REFCLK_DIV'))
        
        self.add(pr.RemoteVariable(
            offset=0x0099 << 2,
            bitSize=10,
            mode='RW',
            name='QPLL1_LPF'))
        
        self.add(pr.RemoteVariable(
            offset=0x009A << 2,
            bitSize=16,
            mode='RW',
            name='QPLL1_CFG1_G3'))
        
        self.add(pr.RemoteVariable(
            offset=0x009B << 2,
            bitSize=16,
            mode='RW',
            name='QPLL1_CFG2_G3'))
        
        self.add(pr.RemoteVariable(
            offset=0x009C << 2,
            bitSize=10,
            mode='RW',
            name='QPLL1_LPF_G3'))
        
        self.add(pr.RemoteVariable(
            offset=0x009D << 2,
            bitSize=16,
            mode='RW',
            name='QPLL1_LOCK_CFG_G3'))
        
        self.add(pr.RemoteVariable(
            offset=0x009E << 2,
            bitSize=16,
            mode='RW',
            name='RSVD_ATTR2'))
        
        self.add(pr.RemoteVariable(
            offset=0x009F << 2,
            bitSize=8,
            bitOffset=8,
            mode='RW',
            name='QPLL1_FBDIV_G3'))
        
        self.add(pr.RemoteVariable(
            offset=0x009F << 2,
            bitSize=2,
            mode='RW',
            name='RXRECCLKOUT1_SEL'))
        
        self.add(pr.RemoteVariable(
            offset=0x00A0 << 2,
            bitSize=16,
            mode='RW',
            name='QPLL1_SDM_CFG0'))
        
        self.add(pr.RemoteVariable(
            offset=0x00A1 << 2,
            bitSize=16,
            mode='RW',
            name='QPLL1_SDM_CFG1'))
        
        self.add(pr.RemoteVariable(
            offset=0x00A2 << 2,
            bitSize=16,
            mode='RW',
            name='SDM1INITSEED0_0'))
        
        self.add(pr.RemoteVariable(
            offset=0x00A3 << 2,
            bitSize=9,
            mode='RW',
            name='SDM1INITSEED0_1'))
        
        self.add(pr.RemoteVariable(
            offset=0x00A4 << 2,
            bitSize=16,
            mode='RW',
            name='QPLL1_SDM_CFG2'))
        
        self.add(pr.RemoteVariable(
            offset=0x00A5 << 2,
            bitSize=10,
            mode='RW',
            name='QPLL1_CP_G3'))
        
        self.add(pr.RemoteVariable(
            offset=0x00A8 << 2,
            bitSize=16,
            mode='RW',
            name='SDM1DATA1_0'))
        
        self.add(pr.RemoteVariable(
            offset=0x00A9 << 2,
            bitSize=1,
            bitOffset=10,
            mode='RW',
            name='SDM1_WIDTH_PIN_SEL'))
        
        self.add(pr.RemoteVariable(
            offset=0x00A9 << 2,
            bitSize=1,
            bitOffset=9,
            mode='RW',
            name='SDM1_DATA_PIN_SEL'))
        
        self.add(pr.RemoteVariable(
            offset=0x00A9 << 2,
            bitSize=9
            mode='RW',
            name='SDM1DATA1_1'))
        
        self.add(pr.RemoteVariable(
            offset=0x00AD << 2,
            bitSize=16,
            mode='RW',
            name='RSVD_ATTR3'))
        
        self.add(pr.RemoteVariable(
            offset=0x00B0 << 2,
            bitSize=16,
            mode='RW',
            name='QPLL1_CFG4'))

__REFCLK_DIV_ENUM = {
    0 : '2',
    1 : '3',
    2 : '4',
    3 : '5',
    5 : '6',
    6 : '8',
    7 : '10',
    13 : '12',
    14 : '16',
    15 : '20',
    16 : '1',
}

__FBDIV_ENUM = {
    14 : '16',
    15 : '17',
    16 : '18',
    17 : '19',
    18 : '20',
    19 : '21',
    20 : '22',
    21 : '23',
    22 : '24',
    23 : '25',
    24 : '26',
    25 : '27',
    26 : '28',
    27 : '29',
    28 : '30',
    29 : '31',
    30 : '32',
    31 : '33',
    32 : '34',
    33 : '35',
    34 : '36',
    35 : '37',
    36 : '38',
    37 : '39',
    38 : '40',
    39 : '41',
    40 : '42',
    41 : '43',
    42 : '44',
    43 : '45',
    44 : '46',
    45 : '47',
    46 : '48',
    47 : '49',
    48 : '50',
    49 : '51',
    50 : '52',
    51 : '53',
    52 : '54',
    53 : '55',
    54 : '56',
    55 : '57',
    56 : '58',
    57 : '59',
    58 : '60',
    59 : '61',
    60 : '62',
    61 : '63',
    62 : '64',
    63 : '65',
    64 : '66',
    65 : '67',
    66 : '68',
    67 : '69',
    68 : '70',
    69 : '71',
    70 : '72',
    71 : '73',
    72 : '74',
    73 : '75',
    74 : '76',
    75 : '77',
    76 : '78',
    77 : '79',
    78 : '80',
    79 : '81',
    80 : '82',
    81 : '83',
    82 : '84',
    83 : '85',
    84 : '86',
    85 : '87',
    86 : '88',
    87 : '89',
    88 : '90',
    89 : '91',
    90 : '92',
    91 : '93',
    92 : '94',
    93 : '95',
    94 : '96',
    95 : '97',
    96 : '98',
    97 : '99',
    98 : '100',
    99 : '101',
    100 : '102',
    101 : '103',
    102 : '104',
    103 : '105',
    104 : '106',
    105 : '107',
    106 : '108',
    107 : '109',
    108 : '110',
    109 : '111',
    110 : '112',
    111 : '113',
    112 : '114',
    113 : '115',
    114 : '116',
    115 : '117',
    116 : '118',
    117 : '119',
    118 : '120',
    119 : '121',
    120 : '122',
    121 : '123',
    122 : '124',
    123 : '125',
    124 : '126',
    125 : '127',
    126 : '128',
    127 : '129',
    128 : '130',
    129 : '131',
    130 : '132',
    131 : '133',
    132 : '134',
    133 : '135',
    134 : '136',
    135 : '137',
    136 : '138',
    137 : '139',
    138 : '140',
    139 : '141',
    140 : '142',
    141 : '143',
    142 : '144',
    143 : '145',
    144 : '146',
    145 : '147',
    146 : '148',
    147 : '149',
    148 : '150',
    149 : '151',
    150 : '152',
    151 : '153',
    152 : '154',
    153 : '155',
    154 : '156',
    155 : '157',
    156 : '158',
    157 : '159',
    158 : '160',
}
