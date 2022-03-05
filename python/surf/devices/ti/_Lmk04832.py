#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue         as pr
from surf.devices import ti

class Lmk04832(ti.Lmk048Base):
    def __init__(self,
            simpleViewList = [
                'enable',
                'SYNC_MODE',
                'EnableSysRef',
                'RB_PLL1_LD_LOST',
                'RB_PLL1_LD',
                'RB_PLL2_LD_LOST',
                'RB_PLL2_LD',
                'ID_VNDR_LOWER',
                'ID_VNDR_UPPER',
                'ID_MASKREV',
                'ID_PROD_LOWER',
                'ID_PROD_UPPER',
                'ID_DEVICE_TYPE',
            ],
            **kwargs):
        super().__init__(**kwargs)

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0102',
            description  = 'CLKout0_1_PD, CLKout0_1_ODL, CLKout0_1_IDL, DCLK0_1_DDLY_PD, DCLK0_1_DDLY[9:8], DCLK0_1_DIV[9:8]',
            offset       = (0x0102 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x010A',
            description  = 'CLKout2_3_PD, CLKout2_3_ODL, CLKout2_3_IDL, DCLK2_3_DDLY_PD, DCLK2_3_DDLY[9:8], DCLK2_3_DIV[9:8]',
            offset       = (0x010A << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0112',
            description  = 'CLKout4_5_PD, CLKout4_5_ODL, CLKout4_5_IDL, DCLK4_5_DDLY_PD, DCLK4_5_DDLY[9:8], DCLK4_5_DIV[9:8]',
            offset       = (0x0112 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x011A',
            description  = 'CLKout6_7_PD, CLKout6_7_ODL, CLKout6_7_IDL, DCLK6_7_DDLY_PD, DCLK6_7_DDLY[9:8], DCLK6_7_DIV[9:8]',
            offset       = (0x011A << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0122',
            description  = 'CLKout8_9_PD, CLKout8_9_ODL, CLKout8_9_IDL, DCLK8_9_DDLY_PD, DCLK8_9_DDLY[9:8], DCLK8_9_DIV[9:8]',
            offset       = (0x0122 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x012A',
            description  = 'CLKout10_11_PD, CLKout10_11_ODL, CLKout10_11_IDL, DCLK10_11_DDLY_PD, DCLK10_11_DDLY[9:8], DCLK10_11_DIV[9:8]',
            offset       = (0x012A << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0132',
            description  = 'CLKout12_13_PD, CLKout12_13_ODL, CLKout12_13_IDL, DCLK12_13_DDLY_PD, DCLK12_13_DDLY[9:8], DCLK12_13_DIV[9:8]',
            offset       = (0x0132 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0145',
            description  = 'PLL1R_SYNC_EN, PLL1R_SYNC_SRC, PLL2R_SYNC_EN, FIN0_DIV2_EN, FIN0_INPUT_TYPE',
            offset       = (0x0145 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x016D',
            description  = '',
            offset       = (0x016D << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x016E',
            description  = 'PLL2_LD_MUX, PLL2_LD_TYPE',
            offset       = (0x016E << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0177',
            description  = 'PLL1R_RST',
            offset       = (0x0177 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0555',
            description  = 'SPI_LOCK',
            offset       = (0x555 << 2),
            bitSize      = 8,
            mode         = 'WO',
        ))

        # Default to simple view
        self.simpleView(simpleViewList)
