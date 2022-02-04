#-----------------------------------------------------------------------------
# Title      : PyRogue LMK04828 Module
#-----------------------------------------------------------------------------
# Description:
# PyRogue LMK04828 Module
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

class Lmk04828(ti.Lmk048Base):
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

        reservedList = [
            0x0102,0x010A,
            0x0112,0x011A,
            0x0122,0x012A,
            0x0132,0x0189,0x018A,0x018B,
        ]

        for offset in reservedList:
            self.add(pr.RemoteVariable(
                name         = f'LmkReg_0x{offset:04X}',
                description  = 'RESERVED',
                offset       = (offset << 2),
                bitSize      = 8,
                mode         = 'WO',
                hidden       = True,
            ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0145',
            description  = 'Always program to 127 (0x7F)',
            offset       = (0x0145 << 2),
            bitSize      = 8,
            mode         = 'WO',
            value        = 0x7F,
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x016D',
            description  = 'PLL2_LF_C4, PLL2_LF_C3',
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
            name         = 'LmkReg_0x0171',
            description  = 'Always program to 170 (0xAA)',
            offset       = (0x0171 << 2),
            bitSize      = 8,
            mode         = 'WO',
            value        = 0xAA,
        ))
        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0172',
            description  = 'Always program to 2 (0x02)',
            offset       = (0x0172 << 2),
            bitSize      = 8,
            mode         = 'WO',
            value        = 0x02,
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0174',
            description  = 'VCO1_DIV (LMK04821 only)',
            offset       = (0x0174 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x017C',
            description  = 'OPT_REG_1: 21: LMK04821, 24: LMK04826, 21: LMK04828',
            offset       = (0x017C << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x017D',
            description  = 'OPT_REG_2: 51: LMK04821, 119: LMK04826, 51: LMK04828',
            offset       = (0x017D << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x1FFD',
            description  = 'SPI_LOCK[23:16]',
            offset       = (0x1FFD << 2),
            bitSize      = 8,
            mode         = 'WO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x1FFE',
            description  = 'SPI_LOCK[15:8]',
            offset       = (0x1FFE << 2),
            bitSize      = 8,
            mode         = 'WO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x1FFF',
            description  = 'SPI_LOCK[7:0]',
            offset       = (0x1FFF << 2),
            bitSize      = 8,
            mode         = 'WO',
        ))

        # Default to simple view
        self.simpleView(simpleViewList)
