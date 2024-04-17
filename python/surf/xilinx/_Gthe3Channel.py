#-----------------------------------------------------------------------------
# Description:
# PyRogue Gthe3Channel
#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr

DIV_ENU = {
    0: '2',
    1: '3',
    2: '4',
    3: '5',
    5: '6',
    7: '10',
    13: '12',
    14: '16',
    15: '20',
    16: '1'}

class Gthe3Channel(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        ##############################
        # Variables
        ##############################

        def addVar(**kwargs):
            kwargs['offset'] = kwargs['offset'] << 2
            self.add(pr.RemoteVariable(**kwargs))

        self.add(pr.RemoteVariable(
            name         = "CDR_SWAP_MODE_EN",
            offset       =  0x02 << 2,
            bitSize      =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXCDRFREQRESET_TIME",
            offset       =  0x03 << 2,
            bitSize      =  5,
            bitOffset    =  0,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "EYE_SCAN_SWAP_EN",
            offset       = 0x3 << 2,
            bitSize      =  1,
            bitOffset    =  9,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_DATA_WIDTH",
            offset       =  0x03 << 2,
            bitSize      =  4,
            bitOffset    =  5,
            mode         = "RW",
            # enum         = {
                # 0 : '-',
                # 2 : '16',
                # 3 : '20',
                # 4 : '32',
                # 5 : '40',
                # 6 : '64',
                # 7 : '80',
                # 8 : '128',
                # 9 : '160'},
        ))

        self.add(pr.RemoteVariable(
            name         = "RXBUFRESET_TIME",
            offset       =  0x0D,
            bitSize      =  5,
            bitOffset    =  3,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_FABINT_USRCLK_FLOP",
            offset       =  0x10,
            bitSize      =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFELPMRESET_TIME",
            offset       =  0x10,
            bitSize      =  7,
            bitOffset    =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PCI3_RX_ELECIDLE_H2L_DISABLE",
            offset       =  0x11,
            bitSize      =  3,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXCDRPHRESET_TIME",
            offset       =  0x11,
            bitSize      =  5,
            bitOffset    =  3,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXELECIDLE_CFG",
            offset       =  0x14,
            bitSize      =  3,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXPCSRESET_TIME",
            offset       =  0x14,
            bitSize      =  5,
            bitOffset    =  3,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PCI3_RX_FIFO_DISABLE",
            offset       =  0x15,
            bitSize      =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PCI3_RX_ELECIDLE_EI2_ENABLE",
            offset       =  0x15,
            bitSize      =  1,
            bitOffset    =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PCI3_RX_ELECIDLE_LP4_DISABLE",
            offset       =  0x15,
            bitSize      =  1,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXPMARESET_TIME",
            offset       =  0x15,
            bitSize      =  5,
            bitOffset    =  3,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFE_HB_CFG1",
            offset       =  0x18,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TXPCSRESET_TIME",
            offset       =  0x24,
            bitSize      =  5,
            bitOffset    =  3,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TX_PMA_POWER_SAVE",
            offset       =  0x25,
            bitSize      =  1,
            bitOffset    =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_PMA_POWER_SAVE",
            offset       =  0x25,
            bitSize      =  1,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TXPMARESET_TIME",
            offset       =  0x25,
            bitSize      =  5,
            bitOffset    =  3,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TX_FABINT_USRCLK_FLOP",
            offset       =  0x2C,
            bitSize      =  1,
            bitOffset    =  4,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXPMACLK_SEL",
            offset       =  0x2B,
            bitSize      =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "WB_MODE",
            offset       =  0x2B,
            bitSize      =  2,
            bitOffset    =  6,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXISCANRESET_TIME",
            offset       =  0x30,
            bitSize      =  5,
            bitOffset    =  5,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TX_PROGCLK_SEL",
            offset       =  0x31,
            bitSize      =  2,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.addRemoteVariables(
            name         = "RXCDR_CFG",
            offset       =  0x38,
            bitSize      =  16,
            mode         = "RW",
            number       =  5,
            stride       =  4,
        )

        self.add(pr.RemoteVariable(
            name         = "RXCDR_LOCK_CFG0",
            offset       =  0x4C,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "CHAN_BOND_SEQ_1_1",
            offset       =  0x50,
            bitSize      =  10,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "CHAN_BOND_SEQ_LEN",
            offset       =  0x51,
            bitSize      =  2,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "CHAN_BOND_MAX_SKEW",
            offset       =  0x51,
            bitSize      =  4,
            bitOffset    =  4,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "CHAN_BOND_SEQ_1_3",
            offset       =  0x54,
            bitSize      =  10,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PCI3_RX_ELECIDLE_HI_COUNT",
            offset       =  0x55,
            bitSize      =  5,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "CHAN_BOND_SEQ_1_4",
            offset       =  0x58,
            bitSize      =  10,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PCI3_RX_ELECIDLE_H2L_COUNT",
            offset       =  0x59,
            bitSize      =  5,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PCI3_PIPE_RX_ELECIDLE",
            offset       =  0x5C,
            bitSize      =  1,
            bitOffset    =  4,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PCI3_AUTO_REALIGN",
            offset       =  0x5C,
            bitSize      =  2,
            bitOffset    =  5,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "OOBDIVCTL",
            offset       =  0x5C,
            bitSize      =  2,
            bitOffset    =  7,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_DEFER_RESET_BUF_EN",
            offset       =  0x5D,
            bitSize      =  1,
            bitOffset    =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_BUFFER_CFG",
            offset       =  0x5D,
            bitSize      =  6,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "CHAN_BOND_SEQ_2_1",
            offset       =  0x60,
            bitSize      =  10,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PCI3_RX_ASYNC_EBUF_BYPASS",
            offset       =  0x61,
            bitSize      =  2,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "CHAN_BOND_SEQ_1_ENABLE",
            offset       =  0x61,
            bitSize      =  4,
            bitOffset    =  4,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "CHAN_BOND_SEQ_2_2",
            offset       =  0x64,
            bitSize      =  10,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "CHAN_BOND_SEQ_2_3",
            offset       =  0x68,
            bitSize      =  10,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "CHAN_BOND_SEQ_2_4",
            offset       =  0x6C,
            bitSize      =  10,
            mode         = "RW",
        ))


        self.add(pr.RemoteVariable(
            name         = "CHAN_BOND_SEQ_2_USE",
            offset       =  0x71,
            bitSize      =  1,
            bitOffset    =  3,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "CHAN_BOND_SEQ_2_ENABLE",
            offset       =  0x71,
            bitSize      =  4,
            bitOffset    =  4,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "CHAN_BOND_KEEP_ALIGN",
            offset       =  0x74,
            bitSize      =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "CLK_CORRECT_USE",
            offset       =  0x91,
            bitSize      =  1,
            bitOffset    =  2,
            mode         = "RW",
        ))


        self.add(pr.RemoteVariable(
            name         = "CLK_COR_MIN_LAT",
            offset       =  0x70,
            bitSize      =  6,
            mode         = "RW",
            disp         = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name         = "CLK_COR_MAX_LAT",
            offset       =  0x75,
            bitSize      =  6,
            bitOffset    =  2,
            mode         = "RW",
            disp         = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name         = "CLK_COR_KEEP_IDLE",
            offset       =  0x70,
            bitSize      =  1,
            bitOffset    =  6,
            mode         = "RW",
        ))


        self.add(pr.RemoteVariable(
            name         = "CLK_COR_SEQ_LEN",
            offset       =  0x74,
            bitSize      =  2,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "CLK_COR_REPEAT_WAIT",
            offset       =  0x74,
            bitSize      =  5,
            bitOffset    =  4,
            mode         = "RW",
            disp         = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name         = "CLK_COR_PRECEDENCE",
            offset       =  0x75,
            bitSize      =  1,
            bitOffset    =  1,
            mode         = "RW",
        ))



        self.add(pr.RemoteVariable(
            name         = "CLK_COR_SEQ_1_ENABLE",
            offset       =  0x89,
            bitSize      =  4,
            bitOffset    =  4,
            mode         = "RW",
            disp         = '0b{:04b}',
        ))

        self.add(pr.RemoteVariable(
            name         = "CLK_COR_SEQ_1_1",
            offset       =  0x78,
            bitSize      =  10,
            mode         = "RW",
            disp         = '0b{:010b}',
        ))

        self.add(pr.RemoteVariable(
            name         = "CLK_COR_SEQ_1_2",
            offset       =  0x7C,
            bitSize      =  10,
            mode         = "RW",
            disp         = '0b{:010b}',
        ))

        self.add(pr.RemoteVariable(
            name         = "CLK_COR_SEQ_1_3",
            offset       =  0x80,
            bitSize      =  10,
            mode         = "RW",
            disp         = '0b{:010b}',
        ))

        self.add(pr.RemoteVariable(
            name         = "CLK_COR_SEQ_1_4",
            offset       =  0x84,
            bitSize      =  10,
            mode         = "RW",
            disp         = '0b{:010b}',
        ))

        self.add(pr.RemoteVariable(
            name         = "CLK_COR_SEQ_2_ENABLE",
            offset       =  0x91,
            bitSize      =  4,
            bitOffset    =  4,
            mode         = "RW",
            disp         = '0b{:04b}',
        ))

        self.add(pr.RemoteVariable(
            name         = "CLK_COR_SEQ_2_USE",
            offset       =  0x91,
            bitSize      =  1,
            bitOffset    =  3,
            base         = pr.Bool,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "CLK_COR_SEQ_2_1",
            offset       =  0x88,
            bitSize      =  10,
            mode         = "RW",
            disp         = '0b{:010b}',
        ))



        self.add(pr.RemoteVariable(
            name         = "CLK_COR_SEQ_2_2",
            offset       =  0x8C,
            bitSize      =  10,
            mode         = "RW",
            disp         = '0b{:010b}',
        ))

        self.add(pr.RemoteVariable(
            name         = "CLK_COR_SEQ_2_3",
            offset       =  0x90,
            bitSize      =  10,
            mode         = "RW",
            disp         = '0b{:010b}',
        ))

        self.add(pr.RemoteVariable(
            name         = "CLK_COR_SEQ_2_4",
            offset       =  0x94,
            bitSize      =  10,
            mode         = "RW",
            disp         = '0b{:010b}',
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFE_HE_CFG0",
            offset       =  0x98,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "ALIGN_COMMA_ENABLE",
            offset       =  0x9C,
            bitSize      =  10,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "SHOW_REALIGN_COMMA",
            offset       =  0x9D,
            bitSize      =  1,
            bitOffset    =  3,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "ALIGN_COMMA_DOUBLE",
            offset       =  0x9D,
            bitSize      =  1,
            bitOffset    =  4,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "ALIGN_COMMA_WORD",
            offset       =  0x9D,
            bitSize      =  3,
            bitOffset    =  5,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TXDRVBIAS_N",
            offset       =  0xA0,
            bitSize      =  4,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "CPLL_FBDIV_45",
            offset       =  0xA0,
            bitSize      =  1,
            bitOffset    =  7,
            mode         = "RW",
            enum = {
                0: '4',
                1: '5'}
        ))

        self.add(pr.RemoteVariable(
            name         = "CPLL_FBDIV",
            offset       =  0xA0,
            bitSize      =  8,
            bitOffset    =  8,
            mode         = "RW",
            # enum         = DIV_ENU,
        ))

        self.add(pr.RemoteVariable(
            name         = "CPLL_LOCK_CFG",
            offset       =  0xA4,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TXDRVBIAS_P",
            offset       =  0xA8,
            bitSize      =  4,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "SATA_CPLL_CFG",
            offset       =  0xA8,
            bitSize      =  2,
            bitOffset    =  5,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "CPLL_REFCLK_DIV",
            offset       =  0xA9,
            bitSize      =  5,
            bitOffset    =  3,
            mode         = "RW",
            # enum         = DIV_ENU,
        ))

        self.add(pr.RemoteVariable(
            name         = "CPLL_INIT_CFG0",
            offset       =  0xAC,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "A_RXPROGDIVRESET",
            offset       =  0xB0,
            bitSize      =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "A_TXPROGDIVRESET",
            offset       =  0xB0,
            bitSize      =  1,
            bitOffset    =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_DIVRESET_TIME",
            offset       =  0xB0,
            bitSize      =  5,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TX_DIVRESET_TIME",
            offset       =  0xB0,
            bitSize      =  5,
            bitOffset    =  7,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "DEC_PCOMMA_DETECT",
            offset       =  0xB1,
            bitSize      =  1,
            bitOffset    =  7,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXCDR_LOCK_CFG1",
            offset       =  0xB4,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXCFOK_CFG1",
            offset       =  0xB8,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFE_H2_CFG0",
            offset       =  0xBC,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFE_H2_CFG1",
            offset       =  0xC0,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXCFOK_CFG2",
            offset       =  0xC4,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXLPM_CFG",
            offset       =  0xC8,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXLPM_KH_CFG0",
            offset       =  0xCC,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXLPM_KH_CFG1",
            offset       =  0xD0,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFELPM_KL_CFG0",
            offset       =  0xD4,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFELPM_KL_CFG1",
            offset       =  0xD8,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXLPM_OS_CFG0",
            offset       =  0xDC,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXLPM_OS_CFG1",
            offset       =  0xE0,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXLPM_GC_CFG",
            offset       =  0xE4,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "DMONITOR_CFG1",
            offset       =  0xE9,
            bitSize      =  8,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "ES_PRESCALE",
            offset       =  0xF0,
            bitSize      =  5,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "ES_EYE_SCAN_EN",
            offset       =  0xF1,
            bitSize      =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFE_HB_CFG0",
            offset       =  0x33C,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFE_HA_CFG1",
            offset       =  0x338,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "CPLL_INIT_CFG1",
            offset       =  0x335,
            bitSize      =  8,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_DDI_SEL",
            offset       =  0x334,
            bitSize      =  6,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "DEC_VALID_COMMA_ONLY",
            offset       =  0x334,
            bitSize      =  1,
            bitOffset    =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "DEC_MCOMMA_DETECT",
            offset       =  0x334,
            bitSize      =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "CPLL_CFG1",
            offset       =  0x330,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "CPLL_CFG0",
            offset       =  0x32C,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "CHAN_BOND_SEQ_1_2",
            offset       =  0x328,
            bitSize      =  10,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFE_HA_CFG0",
            offset       =  0x320,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFE_H9_CFG1",
            offset       =  0x31C,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_PROGDIV_CFG",
            offset       =  0x318,
            bitSize      =  16,
            mode         = "RW",
            # enum         = {
                # 0 : '-',
                # 32768 : '0.0' ,
                # 57744 : '4.0' ,
                # 49648 : '5.0' ,
                # 57728 : '8.0' ,
                # 57760 : '10.0' ,
                # 57730 : '16.0' ,
                # 49672 : '16.5' ,
                # 57762 : '20.0' ,
                # 57734 : '32.0' ,
                # 49800 : '33.0' ,
                # 57766 : '40.0' ,
                # 57742 : '64.0' ,
                # 50056 : '66.0' ,
                # 57743 : '80.0' ,
                # 57775 : '100.0' },
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFE_H9_CFG0",
            offset       =  0x314,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PCIE_RXPCS_CFG_GEN3",
            offset       =  0x310,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PCIE_BUFG_DIV_CTRL",
            offset       =  0x30C,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFE_H8_CFG1",
            offset       =  0x308,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFE_H8_CFG0",
            offset       =  0x304,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFE_H7_CFG1",
            offset       =  0x300,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXPHBEACON_CFG",
            offset       =  0x2FC,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXPHSLIP_CFG",
            offset       =  0x2F8,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXPHSAMP_CFG",
            offset       =  0x2F4,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "CPLL_CFG2",
            offset       =  0x2F0,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TXGBOX_FIFO_INIT_RD_ADDR",
            offset       =  0x2ED,
            bitSize      =  3,
            bitOffset    =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TX_SAMPLE_PERIOD",
            offset       =  0x2EC,
            bitSize      =  3,
            bitOffset    =  6,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXGBOX_FIFO_INIT_RD_ADDR",
            offset       =  0x2EC,
            bitSize      =  3,
            bitOffset    =  3,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_SAMPLE_PERIOD",
            offset       =  0x2EC,
            bitSize      =  3,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "DDI_REALIGN_WAIT",
            offset       =  0x2E8,
            bitSize      =  5,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "DDI_CTRL",
            offset       =  0x2E8,
            bitSize      =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFE_H7_CFG0",
            offset       =  0x2E4,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFE_H6_CFG1",
            offset       =  0x2E0,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFE_H6_CFG0",
            offset       =  0x2DC,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TX_DCD_CFG",
            offset       =  0x2D9,
            bitSize      =  6,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TX_DCD_EN",
            offset       =  0x2D9,
            bitSize      =  1,
            bitOffset    =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TX_EML_PHI_TUNE",
            offset       =  0x2D9,
            bitSize      =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "CPLL_CFG3",
            offset       =  0x2D8,
            bitSize      =  6,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFE_H5_CFG1",
            offset       =  0x2D4,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PROCESS_PAR",
            offset       =  0x2D1,
            bitSize      =  3,
            bitOffset    =  5,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TEMPERATUR_PAR",
            offset       =  0x2D1,
            bitSize      =  4,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TX_MODE_SEL",
            offset       =  0x2D0,
            bitSize      =  3,
            bitOffset    =  5,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TX_SARC_LPBK_ENB",
            offset       =  0x2D0,
            bitSize      =  1,
            bitOffset    =  4,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFE_H5_CFG0",
            offset       =  0x2CC,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFE_H4_CFG1",
            offset       =  0x2C8,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFE_H4_CFG0",
            offset       =  0x2C4,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFE_H3_CFG1",
            offset       =  0x2C0,
            bitSize      =  16,
            mode         = "RW",
        ))

        # self.add(pr.RemoteVariable(
            # name         = "DFE_D_X_REL_POS",
            # offset       =  0x2BD,
            # bitSize      =  1,
            # bitOffset    =  6,
            # mode         = "RW",
        # ))

        # self.add(pr.RemoteVariable(
            # name         = "DFE_VCM_COMP_EN",
            # offset       =  0x2BD,
            # bitSize      =  1,
            # bitOffset    =  6,
            # mode         = "RW",
        # ))

        # self.add(pr.RemoteVariable(
            # name         = "GM_BIAS_SELECT",
            # offset       =  0x2BD,
            # bitSize      =  1,
            # bitOffset    =  5,
            # mode         = "RW",
        # ))

        self.add(pr.RemoteVariable(
            name         = "EVODD_PHI_CFG",
            offset       =  0x2BC,
            bitSize      =  11,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFE_H3_CFG0",
            offset       =  0x2B8,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PLL_SEL_MODE_GEN3",
            offset       =  0x2B5,
            bitSize      =  2,
            bitOffset    =  3,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PLL_SEL_MODE_GEN12",
            offset       =  0x2B5,
            bitSize      =  2,
            bitOffset    =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RATE_SW_USE_DRP",
            offset       =  0x2B5,
            bitSize      =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXPI_LPM",
            offset       =  0x2B4,
            bitSize      =  1,
            bitOffset    =  3,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXPI_VREFSEL",
            offset       =  0x2B4,
            bitSize      =  1,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_CLK_SLIP_OVRD",
            offset       =  0x2B0,
            bitSize      =  5,
            bitOffset    =  3,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PCS_RSVD1",
            offset       =  0x2B0,
            bitSize      =  3,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PCIE_TXPMA_CFG",
            offset       =  0x2AC,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PCIE_TXPCS_CFG_GEN3",
            offset       =  0x2A8,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PCIE_RXPMA_CFG",
            offset       =  0x2A4,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXCDR_CFG5",
            offset       =  0x2A0,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXCDR_CFG5_GEN3",
            offset       =  0x29C,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXCDR_CFG4_GEN3",
            offset       =  0x298,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXCDR_CFG3_GEN3",
            offset       =  0x294,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXCDR_CFG2_GEN3",
            offset       =  0x290,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXCDR_CFG1_GEN3",
            offset       =  0x28C,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXCDR_CFG0_GEN3",
            offset       =  0x288,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFE_GC_CFG2",
            offset       =  0x284,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFE_GC_CFG1",
            offset       =  0x280,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFE_GC_CFG0",
            offset       =  0x27C,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFE_UT_CFG0",
            offset       =  0x278,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXPI_CFG1",
            offset       =  0x275,
            bitSize      =  2,
            bitOffset    =  6,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXPI_CFG2",
            offset       =  0x275,
            bitSize      =  2,
            bitOffset    =  4,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXPI_CFG3",
            offset       =  0x275,
            bitSize      =  2,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXPI_CFG4",
            offset       =  0x275,
            bitSize      =  1,
            bitOffset    =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXPI_CFG5",
            offset       =  0x275,
            bitSize      =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXPI_CFG6",
            offset       =  0x274,
            bitSize      =  3,
            bitOffset    =  5,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXPI_CFG0",
            offset       =  0x274,
            bitSize      =  2,
            bitOffset    =  3,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TXPI_CFG0",
            offset       =  0x271,
            bitSize      =  2,
            bitOffset    =  3,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TXPI_CFG1",
            offset       =  0x271,
            bitSize      =  2,
            bitOffset    =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TXPI_CFG2",
            offset       =  0x270,
            bitSize      =  2,
            bitOffset    =  7,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TXPI_CFG3",
            offset       =  0x270,
            bitSize      =  1,
            bitOffset    =  6,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TXPI_CFG4",
            offset       =  0x270,
            bitSize      =  1,
            bitOffset    =  5,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TXPI_CFG5",
            offset       =  0x270,
            bitSize      =  3,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_DFELPM_KLKH_AGC_STUP_EN",
            offset       =  0x26D,
            bitSize      =  1,
            bitOffset    =  7,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_DFELPM_CFG0",
            offset       =  0x26D,
            bitSize      =  4,
            bitOffset    =  3,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_DFELPM_CFG1",
            offset       =  0x26D,
            bitSize      =  1,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_DFE_KL_LPM_KH_CFG0",
            offset       =  0x26D,
            bitSize      =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_DFE_KL_LPM_KH_CFG1",
            offset       =  0x26C,
            bitSize      =  3,
            bitOffset    =  5,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TXPI_PPM_CFG",
            offset       =  0x268,
            bitSize      =  8,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "GEARBOX_MODE",
            offset       =  0x265,
            bitSize      =  5,
            bitOffset    =  3,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TXPI_SYNFREQ_PPM",
            offset       =  0x265,
            bitSize      =  3,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TXPI_PPMCLK_SEL",
            offset       =  0x264,
            bitSize      =  1,
            bitOffset    =  7,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TXPI_INVSTROBE_SEL",
            offset       =  0x264,
            bitSize      =  1,
            bitOffset    =  6,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TXPI_GRAY_SEL",
            offset       =  0x264,
            bitSize      =  1,
            bitOffset    =  5,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TXPI_LPM",
            offset       =  0x264,
            bitSize      =  1,
            bitOffset    =  3,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TXPI_VREFSEL",
            offset       =  0x264,
            bitSize      =  1,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFE_HE_CFG1",
            offset       =  0x260,
            bitSize      =  16,
            mode         = "RW",
        ))

        # self.add(pr.RemoteVariable(
            # name         = "RX_AFE_CM_EN",
            # offset       =  0x25D,
            # bitSize      =  1,
            # bitOffset    =  2,
            # mode         = "RW",
        # ))

        # self.add(pr.RemoteVariable(
            # name         = "RX_CAPFF_SARC_ENB",
            # offset       =  0x25D,
            # bitSize      =  1,
            # bitOffset    =  3,
            # mode         = "RW",
        # ))

        # self.add(pr.RemoteVariable(
            # name         = "RX_EYESCAN_VS_NEG_DIR",
            # offset       =  0x25D,
            # bitSize      =  1,
            # bitOffset    =  2,
            # mode         = "RW",
        # ))

        # self.add(pr.RemoteVariable(
            # name         = "RX_EYESCAN_VS_UT_SIGN",
            # offset       =  0x25D,
            # bitSize      =  1,
            # bitOffset    =  1,
            # mode         = "RW",
        # ))

        # self.add(pr.RemoteVariable(
            # name         = "RX_EYESCAN_VS_CODE",
            # offset       =  0x25C,
            # bitSize      =  7,
            # bitOffset    =  2,
            # mode         = "RW",
        # ))

        # self.add(pr.RemoteVariable(
            # name         = "RX_EYESCAN_VS_RANGE",
            # offset       =  0x25C,
            # bitSize      =  2,
            # mode         = "RW",
        # ))

        self.add(pr.RemoteVariable(
            name         = "PMA_RSV1",
            offset       =  0x254,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "ES_CLK_PHASE_SEL",
            offset       =  0x251,
            bitSize      =  1,
            bitOffset    =  3,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "USE_PCS_CLK_PHASE_SEL",
            offset       =  0x251,
            bitSize      =  1,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXCFOK_CFG0",
            offset       =  0x24C,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "ADAPT_CFG1",
            offset       =  0x248,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "ADAPT_CFG0",
            offset       =  0x244,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFE_UT_CFG1",
            offset       =  0x240,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFE_VP_CFG1",
            offset       =  0x23C,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFE_VP_CFG0",
            offset       =  0x238,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFELPM_KL_CFG2",
            offset       =  0x234,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "ACJTAG_MODE",
            offset       =  0x231,
            bitSize      =  1,
            bitOffset    =  7,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "ACJTAG_DEBUG_MODE",
            offset       =  0x231,
            bitSize      =  1,
            bitOffset    =  6,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "ACJTAG_RESET",
            offset       =  0x231,
            bitSize      =  1,
            bitOffset    =  5,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RESET_POWERSAVE_DISABLE",
            offset       =  0x231,
            bitSize      =  1,
            bitOffset    =  4,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_TUNE_AFE_OS",
            offset       =  0x231,
            bitSize      =  2,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_DFE_KL_LPM_KL_CFG0",
            offset       =  0x231,
            bitSize      =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_DFE_KL_LPM_KL_CFG1",
            offset       =  0x230,
            bitSize      =  3,
            bitOffset    =  5,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TXSYNC_MULTILANE",
            offset       =  0x22D,
            bitSize      =  1,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXSYNC_MULTILANE",
            offset       =  0x22D,
            bitSize      =  1,
            bitOffset    =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_CTLE3_LPF",
            offset       =  0x22C,
            bitSize      =  8,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TX_PMADATA_OPT",
            offset       =  0x229,
            bitSize      =  1,
            bitOffset    =  7,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXSYNC_OVRD",
            offset       =  0x229,
            bitSize      =  1,
            bitOffset    =  6,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TXSYNC_OVRD",
            offset       =  0x229,
            bitSize      =  1,
            bitOffset    =  5,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TX_IDLE_DATA_ZERO",
            offset       =  0x229,
            bitSize      =  1,
            bitOffset    =  4,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "A_RXOSCALRESET",
            offset       =  0x229,
            bitSize      =  1,
            bitOffset    =  3,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXOOB_CLK_CFG",
            offset       =  0x229,
            bitSize      =  1,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TXSYNC_SKIP_DA",
            offset       =  0x229,
            bitSize      =  1,
            bitOffset    =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXSYNC_SKIP_DA",
            offset       =  0x229,
            bitSize      =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXOSCALRESET_TIME",
            offset       =  0x228,
            bitSize      =  5,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXPRBS_LINKACQ_CNT",
            offset       =  0x224,
            bitSize      =  8,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TX_QPI_STATUS_EN",
            offset       =  0x215,
            bitSize      =  1,
            bitOffset    =  5,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TX_INT_DATAWIDTH",
            offset       =  0x215,
            bitSize      =  2,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFE_HD_CFG1",
            offset       =  0x210,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TX_MARGIN_LOW_3",
            offset       =  0x20D,
            bitSize      =  7,
            bitOffset    =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TX_MARGIN_LOW_4",
            offset       =  0x20C,
            bitSize      =  7,
            bitOffset    =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TX_MARGIN_LOW_1",
            offset       =  0x209,
            bitSize      =  7,
            bitOffset    =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TX_MARGIN_LOW_2",
            offset       =  0x208,
            bitSize      =  7,
            bitOffset    =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TX_MARGIN_FULL_4",
            offset       =  0x205,
            bitSize      =  7,
            bitOffset    =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TX_MARGIN_LOW_0",
            offset       =  0x204,
            bitSize      =  7,
            bitOffset    =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TX_MARGIN_FULL_2",
            offset       =  0x201,
            bitSize      =  7,
            bitOffset    =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TX_MARGIN_FULL_3",
            offset       =  0x200,
            bitSize      =  7,
            bitOffset    =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TX_MARGIN_FULL_0",
            offset       =  0x1FD,
            bitSize      =  7,
            bitOffset    =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TX_MARGIN_FULL_1",
            offset       =  0x1FC,
            bitSize      =  7,
            bitOffset    =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TX_CLKMUX_EN",
            offset       =  0x1F9,
            bitSize      =  1,
            bitOffset    =  7,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TX_LOOPBACK_DRIVE_HIZ",
            offset       =  0x1F9,
            bitSize      =  1,
            bitOffset    =  6,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TX_DRIVE_MODE",
            offset       =  0x1F9,
            bitSize      =  5,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TX_EIDLE_ASSERT_DELAY",
            offset       =  0x1F8,
            bitSize      =  3,
            bitOffset    =  5,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TX_EIDLE_DEASSERT_DELAY",
            offset       =  0x1F8,
            bitSize      =  3,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TX_RXDETECT_CFG",
            offset       =  0x1F4,
            bitSize      =  14,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TX_MAINCURSOR_SEL",
            offset       =  0x1F1,
            bitSize      =  1,
            bitOffset    =  6,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TXGEARBOX_EN",
            offset       =  0x1F1,
            bitSize      =  1,
            bitOffset    =  5,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TXOUT_DIV",
            offset       =  0x1F1,
            bitSize      =  3,
            mode         = "RW",
            # enum = {
                # 0: '1',
                # 4: '16',
                # 1: '2',
                # 2: '4',
                # 3: '8'},
        ))

        self.add(pr.RemoteVariable(
            name         = "TXBUF_EN",
            offset       =  0x1F0,
            bitSize      =  1,
            bitOffset    =  7,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TXBUF_RESET_ON_RATE_CHANGE",
            offset       =  0x1F0,
            bitSize      =  1,
            bitOffset    =  6,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TX_RXDETECT_REF",
            offset       =  0x1F0,
            bitSize      =  3,
            bitOffset    =  3,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TXFIFO_ADDR_CFG",
            offset       =  0x1F0,
            bitSize      =  1,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TX_DEEMPH0",
            offset       =  0x1ED,
            bitSize      =  8,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TX_DEEMPH1",
            offset       =  0x1EC,
            bitSize      =  8,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TX_CLK25_DIV",
            offset       =  0x1E9,
            bitSize      =  5,
            bitOffset    =  3,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TX_XCLK_SEL",
            offset       =  0x1E9,
            bitSize      =  1,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TX_DATA_WIDTH",
            offset       =  0x1E8,
            bitSize      =  4,
            mode         = "RW",
            # enum         = {
                # 0 : '-',
                # 2 : '16',
                # 3 : '20',
                # 4 : '32',
                # 5 : '40',
                # 6 : '64',
                # 7 : '80',
                # 8 : '128',
                # 9 : '160'},
        ))

        self.add(pr.RemoteVariable(
            name         = "TST_RSV0",
            offset       =  0x1E5,
            bitSize      =  8,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TST_RSV1",
            offset       =  0x1E4,
            bitSize      =  8,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TRANS_TIME_RATE",
            offset       =  0x1E1,
            bitSize      =  8,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PD_TRANS_TIME_NONE_P2",
            offset       =  0x1DD,
            bitSize      =  8,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PD_TRANS_TIME_TO_P2",
            offset       =  0x1DC,
            bitSize      =  8,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PD_TRANS_TIME_FROM_P2",
            offset       =  0x1D8,
            bitSize      =  12,
            bitOffset    =  4,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TERM_RCAL_OVRD",
            offset       =  0x1D8,
            bitSize      =  2,
            bitOffset    =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFE_HF_CFG1",
            offset       =  0x1D4,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TERM_RCAL_CFG",
            offset       =  0x1D0,
            bitSize      =  15,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TXPH_CFG",
            offset       =  0x1CC,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXCDR_LOCK_CFG2",
            offset       =  0x1C8,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TXPH_MONITOR_SEL",
            offset       =  0x1C4,
            bitSize      =  5,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TAPDLY_SET_TX",
            offset       =  0x1C4,
            bitSize      =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TXDLY_CFG",
            offset       =  0x1C0,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.addRemoteVariables(
            name         = "TXPHDLY_CFG",
            offset       =  0x1B8,
            bitSize      =  16,
            mode         = "RW",
            number       =  2,
            stride       =  4,
        )

        self.add(pr.RemoteVariable(
            name         = "RX_CLK25_DIV",
            offset       =  0x1B4,
            bitSize      =  5,
            bitOffset    =  3,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "SATA_MAX_INIT",
            offset       =  0x1B1,
            bitSize      =  6,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "SATA_MAX_WAKE",
            offset       =  0x1B0,
            bitSize      =  6,
            bitOffset    =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "SATA_MAX_BURST",
            offset       =  0x1AD,
            bitSize      =  6,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "SAS_MAX_COM",
            offset       =  0x1AC,
            bitSize      =  6,
            bitOffset    =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "SATA_MIN_INIT",
            offset       =  0x1A9,
            bitSize      =  6,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "SATA_MIN_WAKE",
            offset       =  0x1A8,
            bitSize      =  6,
            bitOffset    =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "SATA_MIN_BURST",
            offset       =  0x1A5,
            bitSize      =  6,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "SAS_MIN_COM",
            offset       =  0x1A4,
            bitSize      =  6,
            bitOffset    =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "SATA_BURST_VAL",
            offset       =  0x1A1,
            bitSize      =  3,
            bitOffset    =  5,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "SATA_BURST_SEQ_LEN",
            offset       =  0x1A0,
            bitSize      =  4,
            bitOffset    =  4,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "SATA_EIDLE_VAL",
            offset       =  0x1A0,
            bitSize      =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXBUF_EIDLE_HI_CNT",
            offset       =  0x19D,
            bitSize      =  4,
            bitOffset    =  4,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXCDR_HOLD_DURING_EIDLE",
            offset       =  0x19D,
            bitSize      =  1,
            bitOffset    =  3,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_DFE_LPM_HOLD_DURING_EIDLE",
            offset       =  0x19D,
            bitSize      =  1,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXBUF_EIDLE_LO_CNT",
            offset       =  0x19C,
            bitSize      =  4,
            bitOffset    =  4,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXBUF_RESET_ON_EIDLE",
            offset       =  0x19C,
            bitSize      =  1,
            bitOffset    =  3,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXCDR_FR_RESET_ON_EIDLE",
            offset       =  0x19C,
            bitSize      =  1,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXCDR_PH_RESET_ON_EIDLE",
            offset       =  0x19C,
            bitSize      =  1,
            bitOffset    =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXBUF_THRESH_OVRD",
            offset       =  0x199,
            bitSize      =  1,
            bitOffset    =  7,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXBUF_RESET_ON_COMMAALIGN",
            offset       =  0x199,
            bitSize      =  1,
            bitOffset    =  6,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXBUF_RESET_ON_RATE_CHANGE",
            offset       =  0x199,
            bitSize      =  1,
            bitOffset    =  5,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXBUF_RESET_ON_CB_CHANGE",
            offset       =  0x199,
            bitSize      =  1,
            bitOffset    =  4,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXBUF_THRESH_UNDFLW",
            offset       =  0x198,
            bitSize      =  6,
            bitOffset    =  6,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_CLKMUX_EN",
            offset       =  0x198,
            bitSize      =  1,
            bitOffset    =  5,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_DISPERR_SEQ_MATCH",
            offset       =  0x198,
            bitSize      =  1,
            bitOffset    =  4,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXBUF_ADDR_MODE",
            offset       =  0x198,
            bitSize      =  1,
            bitOffset    =  3,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_WIDEMODE_CDR",
            offset       =  0x198,
            bitSize      =  1,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_INT_DATAWIDTH",
            offset       =  0x198,
            bitSize      =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXBUF_THRESH_OVFLW",
            offset       =  0x195,
            bitSize      =  6,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "DMONITOR_CFG0",
            offset       =  0x194,
            bitSize      =  10,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_SIG_VALID_DLY",
            offset       =  0x191,
            bitSize      =  5,
            bitOffset    =  3,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXSLIDE_MODE",
            offset       =  0x191,
            bitSize      =  2,
            bitOffset    =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXPRBS_ERR_LOOPBACK",
            offset       =  0x191,
            bitSize      =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXSLIDE_AUTO_WAIT",
            offset       =  0x190,
            bitSize      =  4,
            bitOffset    =  4,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXBUF_EN",
            offset       =  0x190,
            bitSize      =  1,
            bitOffset    =  3,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_XCLK_SEL",
            offset       =  0x190,
            bitSize      =  2,
            bitOffset    =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXGEARBOX_EN",
            offset       =  0x190,
            bitSize      =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "CBCC_DATA_SOURCE_SEL",
            offset       =  0x18D,
            bitSize      =  1,
            bitOffset    =  7,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "OOB_PWRUP",
            offset       =  0x18D,
            bitSize      =  1,
            bitOffset    =  6,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXOOB_CFG",
            offset       =  0x18C,
            bitSize      =  9,
            bitOffset    =  5,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXOUT_DIV",
            offset       =  0x18C,
            bitSize      =  3,
            mode         = "RW",
            # enum = {
                # 0: '1',
                # 4: '16',
                # 1: '2',
                # 2: '4',
                # 3: '8'},
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_SUM_DFETAPREP_EN",
            offset       =  0x189,
            bitSize      =  1,
            bitOffset    =  6,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_SUM_VCM_OVWR",
            offset       =  0x189,
            bitSize      =  1,
            bitOffset    =  5,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_SUM_IREF_TUNE",
            offset       =  0x189,
            bitSize      =  4,
            bitOffset    =  1,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_SUM_RES_CTRL",
            offset       =  0x188,
            bitSize      =  2,
            bitOffset    =  7,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_SUM_VCMTUNE",
            offset       =  0x188,
            bitSize      =  4,
            bitOffset    =  3,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_SUM_VREF_TUNE",
            offset       =  0x188,
            bitSize      =  3,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXPH_MONITOR_SEL",
            offset       =  0x185,
            bitSize      =  5,
            bitOffset    =  3,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_CM_BUF_PD",
            offset       =  0x185,
            bitSize      =  1,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_CM_BUF_CFG",
            offset       =  0x184,
            bitSize      =  4,
            bitOffset    =  6,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_CM_TRIM",
            offset       =  0x184,
            bitSize      =  4,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_CM_SEL",
            offset       =  0x184,
            bitSize      =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PCS_RSVD0",
            offset       =  0x180,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_BIAS_CFG0",
            offset       =  0x17C,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFE_HD_CFG0",
            offset       =  0x178,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFE_HF_CFG0",
            offset       =  0x174,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDLY_LCFG",
            offset       =  0x170,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDLY_CFG",
            offset       =  0x16C,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFE_OS_CFG1",
            offset       =  0x168,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXPHDLY_CFG",
            offset       =  0x164,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFE_OS_CFG0",
            offset       =  0x160,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "TXDLY_LCFG",
            offset       =  0x15C,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "ALIGN_PCOMMA_DET",
            offset       =  0x159,
            bitSize      =  1,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "ALIGN_PCOMMA_VALUE",
            offset       =  0x158,
            bitSize      =  10,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "LOCAL_MASTER",
            offset       =  0x155,
            bitSize      =  1,
            bitOffset    =  5,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "PCS_PCIE_EN",
            offset       =  0x155,
            bitSize      =  1,
            bitOffset    =  4,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "ALIGN_MCOMMA_DET",
            offset       =  0x155,
            bitSize      =  1,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "ALIGN_MCOMMA_VALUE",
            offset       =  0x154,
            bitSize      =  10,
            mode         = "RW",
        ))

        self.addRemoteVariables(
            name         = "RXDFE_CFG",
            offset       =  0x14C,
            bitSize      =  16,
            mode         = "RW",
            number       =  2,
            stride       =  4,
        )

        self.add(pr.RemoteVariable(
            name         = "RX_EN_HI_LR",
            offset       =  0x149,
            bitSize      =  1,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_DFE_AGC_CFG1",
            offset       =  0x148,
            bitSize      =  3,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RX_DFE_AGC_CFG0",
            offset       =  0x148,
            bitSize      =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "ES_PMA_CFG",
            offset       =  0x144,
            bitSize      =  10,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFE_HC_CFG1",
            offset       =  0x140,
            bitSize      =  16,
            mode         = "RW",
        ))

        # self.add(pr.RemoteVariable(
            # name         = "ES_HORZ_OFFSET",
            # offset       =  0x13C,
            # bitSize      =  12,
            # bitOffset    =  4,
            # mode         = "RW",
        # ))

        # self.add(pr.RemoteVariable(
            # name         = "FTS_LANE_DESKEW_CFG",
            # offset       =  0x13C,
            # bitSize      =  1,
            # bitOffset    =  4,
            # mode         = "RW",
        # ))

        self.add(pr.RemoteVariable(
            name         = "FTS_LANE_DESKEW_EN",
            offset       =  0x138,
            bitSize      =  1,
            bitOffset    =  4,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "FTS_DESKEW_SEQ_ENABLE",
            offset       =  0x138,
            bitSize      =  4,
            mode         = "RW",
        ))

        self.addRemoteVariables(
            name         = "ES_SDATA_MASK",
            offset       =  0x124,
            bitSize      =  16,
            mode         = "RW",
            number       =  5,
            stride       =  4,
        )

        self.addRemoteVariables(
            name         = "ES_QUAL_MASK",
            offset       =  0x110,
            bitSize      =  16,
            mode         = "RW",
            number       =  5,
            stride       =  4,
        )

        self.addRemoteVariables(
            name         = "ES_QUALIFIER",
            offset       =  0xFC,
            bitSize      =  16,
            mode         = "RW",
            number       =  5,
            stride       =  4,
        )

        self.add(pr.RemoteVariable(
            name         = "TX_PROGDIV_CFG",
            offset       =  0xF8,
            bitSize      =  16,
            mode         = "RW",
            # enum         = {
                # 0 : '-',
                # 32768 : '0.0' ,
                # 57744 : '4.0' ,
                # 49648 : '5.0' ,
                # 57728 : '8.0' ,
                # 57760 : '10.0' ,
                # 57730 : '16.0' ,
                # 49672 : '16.5' ,
                # 57762 : '20.0' ,
                # 57734 : '32.0' ,
                # 49800 : '33.0' ,
                # 57766 : '40.0' ,
                # 57742 : '64.0' ,
                # 50056 : '66.0' ,
                # 57743 : '80.0' ,
                # 57775 : '100.0' }
        ))

        self.add(pr.RemoteVariable(
            name         = "RXDFE_HC_CFG0",
            offset       =  0xF4,
            bitSize      =  16,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "ES_CONTROL",
            offset       =  0xF1,
            bitSize      =  6,
            bitOffset    =  2,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = "ES_ERRDET_EN",
            offset       =  0xF1,
            bitSize      =  1,
            bitOffset    =  1,
            mode         = "RW",
        ))
