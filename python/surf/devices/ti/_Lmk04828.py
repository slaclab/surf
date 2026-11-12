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
                name        = f'LmkReg_0x{offset:04X}',
                description = 'RESERVED',
                offset      = (offset << 2),
                bitSize     = 8,
                mode        = 'WO',
                hidden      = True,
            ))

        self.add(pr.RemoteVariable(
            name        = 'LmkReg_0x0145',
            description = 'Always program to 127 (0x7F)',
            offset      = (0x0145 << 2),
            bitSize     = 8,
            mode        = 'WO',
            value       = 0x7F,
        ))

        self.add(pr.RemoteVariable(
            name        = 'LmkReg_0x016D',
            description = 'PLL2_LF_C4, PLL2_LF_C3',
            offset      = (0x016D << 2),
            bitSize     = 8,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'LmkReg_0x016E',
            description = 'PLL2_LD_MUX, PLL2_LD_TYPE',
            offset      = (0x016E << 2),
            bitSize     = 8,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'LmkReg_0x0171',
            description = 'Always program to 170 (0xAA)',
            offset      = (0x0171 << 2),
            bitSize     = 8,
            mode        = 'WO',
            value       = 0xAA,
        ))
        self.add(pr.RemoteVariable(
            name        = 'LmkReg_0x0172',
            description = 'Always program to 2 (0x02)',
            offset      = (0x0172 << 2),
            bitSize     = 8,
            mode        = 'WO',
            value       = 0x02,
        ))

        self.add(pr.RemoteVariable(
            name        = 'LmkReg_0x0174',
            description = 'VCO1_DIV (LMK04821 only)',
            offset      = (0x0174 << 2),
            bitSize     = 8,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'LmkReg_0x017C',
            description = 'OPT_REG_1: 21: LMK04821, 24: LMK04826, 21: LMK04828',
            offset      = (0x017C << 2),
            bitSize     = 8,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'LmkReg_0x017D',
            description = 'OPT_REG_2: 51: LMK04821, 119: LMK04826, 51: LMK04828',
            offset      = (0x017D << 2),
            bitSize     = 8,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'LmkReg_0x1FFD',
            description = 'SPI_LOCK[23:16]',
            offset      = (0x1FFD << 2),
            bitSize     = 8,
            mode        = 'WO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'LmkReg_0x1FFE',
            description = 'SPI_LOCK[15:8]',
            offset      = (0x1FFE << 2),
            bitSize     = 8,
            mode        = 'WO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'LmkReg_0x1FFF',
            description = 'SPI_LOCK[7:0]',
            offset      = (0x1FFF << 2),
            bitSize     = 8,
            mode        = 'WO',
        ))

        # Lock detect: PLL1 in 0x182 and PLL2 in 0x183, each with the sticky lost
        # flag in bit 2, the readback in bit 1 and the clear in bit 0 (LMK04828
        # datasheet, tables 81 and 82); the LMK04832 lays these bits out differently.
        # Each register is read-write, so its block reads the device (a block
        # holding a write-only register returns its shadow), with no write verify,
        # since the code loader writes the read-only flags with values the device
        # does not keep
        self.add(pr.RemoteVariable(
            name        = 'LmkReg_0x0182',
            description = 'RB_PLL1_LD_LOST, RB_PLL1_LD, CLR_PLL1_LD_LOST',
            offset      = (0x0182 << 2),
            bitSize     = 8,
            mode        = 'RW',
            verify      = False,
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'RB_PLL1_LD_LOST',
            description = 'This is set when PLL1 DLD edge falls. Does not set if cleared while PLL1 DLD is low.',
            offset      = (0x0182 << 2),
            bitSize     = 1,
            bitOffset   = 2,
            mode        = 'RO',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'RB_PLL1_LD',
            description = 'Read back 0: PLL1 DLD is low., Read back 1: PLL1 DLD is high.',
            offset      = (0x0182 << 2),
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RO',
            overlapEn   = True,
        ))

        self.add(pr.RemoteCommand(
            name        = 'CLR_PLL1_LD_LOST',
            description = 'Clear PLL1 lock detect lost sticky bit',
            offset      = (0x0182 << 2),
            bitSize     = 1,
            bitOffset   = 0,
            overlapEn   = True,
            function    = pr.RemoteCommand.toggle
        ))

        self.add(pr.RemoteVariable(
            name        = 'LmkReg_0x0183',
            description = 'RB_PLL2_LD_LOST, RB_PLL2_LD, CLR_PLL2_LD_LOST',
            offset      = (0x0183 << 2),
            bitSize     = 8,
            mode        = 'RW',
            verify      = False,
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'RB_PLL2_LD_LOST',
            description = 'This is set when PLL2 DLD edge falls. Does not set if cleared while PLL2 DLD is low.',
            offset      = (0x0183 << 2),
            bitSize     = 1,
            bitOffset   = 2,
            mode        = 'RO',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'RB_PLL2_LD',
            description = 'Read back 0: PLL2 DLD is low., Read back 1: PLL2 DLD is high.',
            offset      = (0x0183 << 2),
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RO',
            overlapEn   = True,
        ))

        self.add(pr.RemoteCommand(
            name        = 'CLR_PLL2_LD_LOST',
            description = 'Clear PLL2 lock detect lost sticky bit',
            offset      = (0x0183 << 2),
            bitSize     = 1,
            bitOffset   = 0,
            overlapEn   = True,
            function    = pr.RemoteCommand.toggle
        ))

        # Default to simple view
        self.simpleView(simpleViewList)
