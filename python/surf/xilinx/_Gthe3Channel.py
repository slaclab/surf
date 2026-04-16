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

        def addVar(description='', **kwargs):
            kwargs['offset'] = kwargs['offset'] << 2
            self.add(pr.RemoteVariable(description=description, **kwargs))

        self.add(pr.RemoteVariable(
            name        = "CDR_SWAP_MODE_EN",
            description = "Enable CDR swap mode for channel bonding",
            offset      =  0x02 << 2,
            bitSize     =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXCDRFREQRESET_TIME",
            description = "RX CDR frequency reset duration timer",
            offset      =  0x03 << 2,
            bitSize     =  5,
            bitOffset   =  0,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "EYE_SCAN_SWAP_EN",
            description = "Enable eye scan data path swap",
            offset      = 0x3 << 2,
            bitSize     =  1,
            bitOffset   =  9,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_DATA_WIDTH",
            description = "RX internal data path width selection",
            offset      =  0x03 << 2,
            bitSize     =  4,
            bitOffset   =  5,
            mode        = "RW",
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
            name        = "RXBUFRESET_TIME",
            description = "RX buffer reset duration timer",
            offset      =  0x0D,
            bitSize     =  5,
            bitOffset   =  3,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_FABINT_USRCLK_FLOP",
            description = "Enable flop on RX fabric interface user clock",
            offset      =  0x10,
            bitSize     =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFELPMRESET_TIME",
            description = "RX DFE LPM reset duration timer",
            offset      =  0x10,
            bitSize     =  7,
            bitOffset   =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PCI3_RX_ELECIDLE_H2L_DISABLE",
            description = "PCIe Gen3 RX electrical idle high-to-low detection disable",
            offset      =  0x11,
            bitSize     =  3,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXCDRPHRESET_TIME",
            description = "RX CDR phase reset duration timer",
            offset      =  0x11,
            bitSize     =  5,
            bitOffset   =  3,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXELECIDLE_CFG",
            description = "RX electrical idle detection configuration",
            offset      =  0x14,
            bitSize     =  3,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXPCSRESET_TIME",
            description = "RX PCS reset duration timer",
            offset      =  0x14,
            bitSize     =  5,
            bitOffset   =  3,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PCI3_RX_FIFO_DISABLE",
            description = "PCIe Gen3 RX FIFO disable control",
            offset      =  0x15,
            bitSize     =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PCI3_RX_ELECIDLE_EI2_ENABLE",
            description = "PCIe Gen3 RX electrical idle EI2 detection enable",
            offset      =  0x15,
            bitSize     =  1,
            bitOffset   =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PCI3_RX_ELECIDLE_LP4_DISABLE",
            description = "PCIe Gen3 RX electrical idle LP4 detection disable",
            offset      =  0x15,
            bitSize     =  1,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXPMARESET_TIME",
            description = "RX PMA reset duration timer",
            offset      =  0x15,
            bitSize     =  5,
            bitOffset   =  3,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFE_HB_CFG1",
            description = "RX DFE HB equalization configuration register 1",
            offset      =  0x18,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXPCSRESET_TIME",
            description = "TX PCS reset duration timer",
            offset      =  0x24,
            bitSize     =  5,
            bitOffset   =  3,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_PMA_POWER_SAVE",
            description = "Enable TX PMA power save mode",
            offset      =  0x25,
            bitSize     =  1,
            bitOffset   =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_PMA_POWER_SAVE",
            description = "Enable RX PMA power save mode",
            offset      =  0x25,
            bitSize     =  1,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXPMARESET_TIME",
            description = "TX PMA reset duration timer",
            offset      =  0x25,
            bitSize     =  5,
            bitOffset   =  3,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_FABINT_USRCLK_FLOP",
            description = "Enable flop on TX fabric interface user clock",
            offset      =  0x2C,
            bitSize     =  1,
            bitOffset   =  4,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXPMACLK_SEL",
            description = "RX PMA clock source selection",
            offset      =  0x2B,
            bitSize     =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "WB_MODE",
            description = "Widebus mode selection",
            offset      =  0x2B,
            bitSize     =  2,
            bitOffset   =  6,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXISCANRESET_TIME",
            description = "RX input scan reset duration timer",
            offset      =  0x30,
            bitSize     =  5,
            bitOffset   =  5,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_PROGCLK_SEL",
            description = "TX programmable clock source selection",
            offset      =  0x31,
            bitSize     =  2,
            bitOffset   =  2,
            mode        = "RW",
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
            name        = "RXCDR_LOCK_CFG0",
            description = "RX CDR lock detection configuration register 0",
            offset      =  0x4C,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CHAN_BOND_SEQ_1_1",
            description = "Channel bonding sequence 1 pattern word 1",
            offset      =  0x50,
            bitSize     =  10,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CHAN_BOND_SEQ_LEN",
            description = "Channel bonding sequence length setting",
            offset      =  0x51,
            bitSize     =  2,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CHAN_BOND_MAX_SKEW",
            description = "Maximum lane skew for channel bonding",
            offset      =  0x51,
            bitSize     =  4,
            bitOffset   =  4,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CHAN_BOND_SEQ_1_3",
            description = "Channel bonding sequence 1 pattern word 3",
            offset      =  0x54,
            bitSize     =  10,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PCI3_RX_ELECIDLE_HI_COUNT",
            description = "PCIe Gen3 RX electrical idle high-level count threshold",
            offset      =  0x55,
            bitSize     =  5,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CHAN_BOND_SEQ_1_4",
            description = "Channel bonding sequence 1 pattern word 4",
            offset      =  0x58,
            bitSize     =  10,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PCI3_RX_ELECIDLE_H2L_COUNT",
            description = "PCIe Gen3 RX electrical idle high-to-low transition count",
            offset      =  0x59,
            bitSize     =  5,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PCI3_PIPE_RX_ELECIDLE",
            description = "PCIe Gen3 PIPE RX electrical idle override",
            offset      =  0x5C,
            bitSize     =  1,
            bitOffset   =  4,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PCI3_AUTO_REALIGN",
            description = "PCIe Gen3 automatic symbol realignment mode",
            offset      =  0x5C,
            bitSize     =  2,
            bitOffset   =  5,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "OOBDIVCTL",
            description = "OOB clock divider control setting",
            offset      =  0x5C,
            bitSize     =  2,
            bitOffset   =  7,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_DEFER_RESET_BUF_EN",
            description = "Enable deferred reset of RX buffer",
            offset      =  0x5D,
            bitSize     =  1,
            bitOffset   =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_BUFFER_CFG",
            description = "RX elastic buffer configuration setting",
            offset      =  0x5D,
            bitSize     =  6,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CHAN_BOND_SEQ_2_1",
            description = "Channel bonding sequence 2 pattern word 1",
            offset      =  0x60,
            bitSize     =  10,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PCI3_RX_ASYNC_EBUF_BYPASS",
            description = "PCIe Gen3 RX asynchronous elastic buffer bypass",
            offset      =  0x61,
            bitSize     =  2,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CHAN_BOND_SEQ_1_ENABLE",
            description = "Enable mask for channel bonding sequence 1 words",
            offset      =  0x61,
            bitSize     =  4,
            bitOffset   =  4,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CHAN_BOND_SEQ_2_2",
            description = "Channel bonding sequence 2 pattern word 2",
            offset      =  0x64,
            bitSize     =  10,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CHAN_BOND_SEQ_2_3",
            description = "Channel bonding sequence 2 pattern word 3",
            offset      =  0x68,
            bitSize     =  10,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CHAN_BOND_SEQ_2_4",
            description = "Channel bonding sequence 2 pattern word 4",
            offset      =  0x6C,
            bitSize     =  10,
            mode        = "RW",
        ))


        self.add(pr.RemoteVariable(
            name        = "CHAN_BOND_SEQ_2_USE",
            description = "Enable use of channel bonding sequence 2",
            offset      =  0x71,
            bitSize     =  1,
            bitOffset   =  3,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CHAN_BOND_SEQ_2_ENABLE",
            description = "Enable mask for channel bonding sequence 2 words",
            offset      =  0x71,
            bitSize     =  4,
            bitOffset   =  4,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CHAN_BOND_KEEP_ALIGN",
            description = "Keep channel bonding alignment after initial bond",
            offset      =  0x74,
            bitSize     =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CLK_CORRECT_USE",
            description = "Enable clock correction functionality",
            offset      =  0x91,
            bitSize     =  1,
            bitOffset   =  2,
            mode        = "RW",
        ))


        self.add(pr.RemoteVariable(
            name        = "CLK_COR_MIN_LAT",
            description = "Minimum latency for clock correction buffer",
            offset      =  0x70,
            bitSize     =  6,
            mode        = "RW",
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        = "CLK_COR_MAX_LAT",
            description = "Maximum latency for clock correction buffer",
            offset      =  0x75,
            bitSize     =  6,
            bitOffset   =  2,
            mode        = "RW",
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        = "CLK_COR_KEEP_IDLE",
            description = "Keep idle during clock correction",
            offset      =  0x70,
            bitSize     =  1,
            bitOffset   =  6,
            mode        = "RW",
        ))


        self.add(pr.RemoteVariable(
            name        = "CLK_COR_SEQ_LEN",
            description = "Clock correction sequence length setting",
            offset      =  0x74,
            bitSize     =  2,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CLK_COR_REPEAT_WAIT",
            description = "Clock correction repeat wait cycles",
            offset      =  0x74,
            bitSize     =  5,
            bitOffset   =  4,
            mode        = "RW",
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        = "CLK_COR_PRECEDENCE",
            description = "Clock correction precedence over channel bonding",
            offset      =  0x75,
            bitSize     =  1,
            bitOffset   =  1,
            mode        = "RW",
        ))



        self.add(pr.RemoteVariable(
            name        = "CLK_COR_SEQ_1_ENABLE",
            description = "Enable mask for clock correction sequence 1 words",
            offset      =  0x89,
            bitSize     =  4,
            bitOffset   =  4,
            mode        = "RW",
            disp        = '0b{:04b}',
        ))

        self.add(pr.RemoteVariable(
            name        = "CLK_COR_SEQ_1_1",
            description = "Clock correction sequence 1 pattern word 1",
            offset      =  0x78,
            bitSize     =  10,
            mode        = "RW",
            disp        = '0b{:010b}',
        ))

        self.add(pr.RemoteVariable(
            name        = "CLK_COR_SEQ_1_2",
            description = "Clock correction sequence 1 pattern word 2",
            offset      =  0x7C,
            bitSize     =  10,
            mode        = "RW",
            disp        = '0b{:010b}',
        ))

        self.add(pr.RemoteVariable(
            name        = "CLK_COR_SEQ_1_3",
            description = "Clock correction sequence 1 pattern word 3",
            offset      =  0x80,
            bitSize     =  10,
            mode        = "RW",
            disp        = '0b{:010b}',
        ))

        self.add(pr.RemoteVariable(
            name        = "CLK_COR_SEQ_1_4",
            description = "Clock correction sequence 1 pattern word 4",
            offset      =  0x84,
            bitSize     =  10,
            mode        = "RW",
            disp        = '0b{:010b}',
        ))

        self.add(pr.RemoteVariable(
            name        = "CLK_COR_SEQ_2_ENABLE",
            description = "Enable mask for clock correction sequence 2 words",
            offset      =  0x91,
            bitSize     =  4,
            bitOffset   =  4,
            mode        = "RW",
            disp        = '0b{:04b}',
        ))

        self.add(pr.RemoteVariable(
            name        = "CLK_COR_SEQ_2_USE",
            description = "Enable use of clock correction sequence 2",
            offset      =  0x91,
            bitSize     =  1,
            bitOffset   =  3,
            base        = pr.Bool,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CLK_COR_SEQ_2_1",
            description = "Clock correction sequence 2 pattern word 1",
            offset      =  0x88,
            bitSize     =  10,
            mode        = "RW",
            disp        = '0b{:010b}',
        ))



        self.add(pr.RemoteVariable(
            name        = "CLK_COR_SEQ_2_2",
            description = "Clock correction sequence 2 pattern word 2",
            offset      =  0x8C,
            bitSize     =  10,
            mode        = "RW",
            disp        = '0b{:010b}',
        ))

        self.add(pr.RemoteVariable(
            name        = "CLK_COR_SEQ_2_3",
            description = "Clock correction sequence 2 pattern word 3",
            offset      =  0x90,
            bitSize     =  10,
            mode        = "RW",
            disp        = '0b{:010b}',
        ))

        self.add(pr.RemoteVariable(
            name        = "CLK_COR_SEQ_2_4",
            description = "Clock correction sequence 2 pattern word 4",
            offset      =  0x94,
            bitSize     =  10,
            mode        = "RW",
            disp        = '0b{:010b}',
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFE_HE_CFG0",
            description = "RX DFE HE equalization configuration register 0",
            offset      =  0x98,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ALIGN_COMMA_ENABLE",
            description = "Comma alignment enable bit mask",
            offset      =  0x9C,
            bitSize     =  10,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "SHOW_REALIGN_COMMA",
            description = "Show comma during realignment to user logic",
            offset      =  0x9D,
            bitSize     =  1,
            bitOffset   =  3,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ALIGN_COMMA_DOUBLE",
            description = "Enable double-symbol comma alignment",
            offset      =  0x9D,
            bitSize     =  1,
            bitOffset   =  4,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ALIGN_COMMA_WORD",
            description = "Comma alignment word width selection",
            offset      =  0x9D,
            bitSize     =  3,
            bitOffset   =  5,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXDRVBIAS_N",
            description = "TX driver bias negative current setting",
            offset      =  0xA0,
            bitSize     =  4,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CPLL_FBDIV_45",
            description = "CPLL feedback divider 4 or 5 selection",
            offset      =  0xA0,
            bitSize     =  1,
            bitOffset   =  7,
            mode        = "RW",
            enum        = {
                0: '4',
                1: '5'}
        ))

        self.add(pr.RemoteVariable(
            name        = "CPLL_FBDIV",
            description = "CPLL feedback divider value",
            offset      =  0xA0,
            bitSize     =  8,
            bitOffset   =  8,
            mode        = "RW",
            # enum         = DIV_ENU,
        ))

        self.add(pr.RemoteVariable(
            name        = "CPLL_LOCK_CFG",
            description = "CPLL lock detection configuration",
            offset      =  0xA4,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXDRVBIAS_P",
            description = "TX driver bias positive current setting",
            offset      =  0xA8,
            bitSize     =  4,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "SATA_CPLL_CFG",
            description = "SATA CPLL configuration setting",
            offset      =  0xA8,
            bitSize     =  2,
            bitOffset   =  5,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CPLL_REFCLK_DIV",
            description = "CPLL reference clock input divider",
            offset      =  0xA9,
            bitSize     =  5,
            bitOffset   =  3,
            mode        = "RW",
            # enum         = DIV_ENU,
        ))

        self.add(pr.RemoteVariable(
            name        = "CPLL_INIT_CFG0",
            description = "CPLL initialization configuration register 0",
            offset      =  0xAC,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "A_RXPROGDIVRESET",
            description = "Asynchronous RX programmable divider reset",
            offset      =  0xB0,
            bitSize     =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "A_TXPROGDIVRESET",
            description = "Asynchronous TX programmable divider reset",
            offset      =  0xB0,
            bitSize     =  1,
            bitOffset   =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_DIVRESET_TIME",
            description = "RX divider reset duration timer",
            offset      =  0xB0,
            bitSize     =  5,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_DIVRESET_TIME",
            description = "TX divider reset duration timer",
            offset      =  0xB0,
            bitSize     =  5,
            bitOffset   =  7,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "DEC_PCOMMA_DETECT",
            description = "Enable positive comma detection in 8b10b decoder",
            offset      =  0xB1,
            bitSize     =  1,
            bitOffset   =  7,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXCDR_LOCK_CFG1",
            description = "RX CDR lock detection configuration register 1",
            offset      =  0xB4,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXCFOK_CFG1",
            description = "RX channel frequency offset correction configuration register 1",
            offset      =  0xB8,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFE_H2_CFG0",
            description = "RX DFE H2 equalization configuration register 0",
            offset      =  0xBC,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFE_H2_CFG1",
            description = "RX DFE H2 equalization configuration register 1",
            offset      =  0xC0,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXCFOK_CFG2",
            description = "RX channel frequency offset correction configuration register 2",
            offset      =  0xC4,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXLPM_CFG",
            description = "RX linear phase measurement configuration",
            offset      =  0xC8,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXLPM_KH_CFG0",
            description = "RX LPM KH loop filter configuration register 0",
            offset      =  0xCC,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXLPM_KH_CFG1",
            description = "RX LPM KH loop filter configuration register 1",
            offset      =  0xD0,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFELPM_KL_CFG0",
            description = "RX DFE LPM KL loop filter configuration register 0",
            offset      =  0xD4,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFELPM_KL_CFG1",
            description = "RX DFE LPM KL loop filter configuration register 1",
            offset      =  0xD8,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXLPM_OS_CFG0",
            description = "RX LPM offset correction configuration register 0",
            offset      =  0xDC,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXLPM_OS_CFG1",
            description = "RX LPM offset correction configuration register 1",
            offset      =  0xE0,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXLPM_GC_CFG",
            description = "RX LPM gain control configuration",
            offset      =  0xE4,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "DMONITOR_CFG1",
            description = "Digital monitor configuration register 1",
            offset      =  0xE9,
            bitSize     =  8,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ES_PRESCALE",
            description = "Eye scan prescale factor for error counting",
            offset      =  0xF0,
            bitSize     =  5,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ES_EYE_SCAN_EN",
            description = "Enable eye scan functionality",
            offset      =  0xF1,
            bitSize     =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFE_HB_CFG0",
            description = "RX DFE HB equalization configuration register 0",
            offset      =  0x33C,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFE_HA_CFG1",
            description = "RX DFE HA equalization configuration register 1",
            offset      =  0x338,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CPLL_INIT_CFG1",
            description = "CPLL initialization configuration register 1",
            offset      =  0x335,
            bitSize     =  8,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_DDI_SEL",
            description = "RX data-dependent input selection",
            offset      =  0x334,
            bitSize     =  6,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "DEC_VALID_COMMA_ONLY",
            description = "Restrict 8b10b alignment to valid comma characters only",
            offset      =  0x334,
            bitSize     =  1,
            bitOffset   =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "DEC_MCOMMA_DETECT",
            description = "Enable negative comma detection in 8b10b decoder",
            offset      =  0x334,
            bitSize     =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CPLL_CFG1",
            description = "CPLL configuration register 1",
            offset      =  0x330,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CPLL_CFG0",
            description = "CPLL configuration register 0",
            offset      =  0x32C,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CHAN_BOND_SEQ_1_2",
            description = "Channel bonding sequence 1 pattern word 2",
            offset      =  0x328,
            bitSize     =  10,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFE_HA_CFG0",
            description = "RX DFE HA equalization configuration register 0",
            offset      =  0x320,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFE_H9_CFG1",
            description = "RX DFE H9 equalization configuration register 1",
            offset      =  0x31C,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_PROGDIV_CFG",
            description = "RX programmable divider configuration",
            offset      =  0x318,
            bitSize     =  16,
            mode        = "RW",
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
            name        = "RXDFE_H9_CFG0",
            description = "RX DFE H9 equalization configuration register 0",
            offset      =  0x314,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PCIE_RXPCS_CFG_GEN3",
            description = "PCIe Gen3 RX PCS configuration",
            offset      =  0x310,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PCIE_BUFG_DIV_CTRL",
            description = "PCIe BUFG clock divider control",
            offset      =  0x30C,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFE_H8_CFG1",
            description = "RX DFE H8 equalization configuration register 1",
            offset      =  0x308,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFE_H8_CFG0",
            description = "RX DFE H8 equalization configuration register 0",
            offset      =  0x304,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFE_H7_CFG1",
            description = "RX DFE H7 equalization configuration register 1",
            offset      =  0x300,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXPHBEACON_CFG",
            description = "RX phase beacon configuration",
            offset      =  0x2FC,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXPHSLIP_CFG",
            description = "RX phase slip configuration",
            offset      =  0x2F8,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXPHSAMP_CFG",
            description = "RX phase sample configuration",
            offset      =  0x2F4,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CPLL_CFG2",
            description = "CPLL configuration register 2",
            offset      =  0x2F0,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXGBOX_FIFO_INIT_RD_ADDR",
            description = "TX gearbox FIFO initial read address",
            offset      =  0x2ED,
            bitSize     =  3,
            bitOffset   =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_SAMPLE_PERIOD",
            description = "TX sample period selection",
            offset      =  0x2EC,
            bitSize     =  3,
            bitOffset   =  6,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXGBOX_FIFO_INIT_RD_ADDR",
            description = "RX gearbox FIFO initial read address",
            offset      =  0x2EC,
            bitSize     =  3,
            bitOffset   =  3,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_SAMPLE_PERIOD",
            description = "RX sample period selection",
            offset      =  0x2EC,
            bitSize     =  3,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "DDI_REALIGN_WAIT",
            description = "DDI realignment wait cycles",
            offset      =  0x2E8,
            bitSize     =  5,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "DDI_CTRL",
            description = "Data-dependent input control setting",
            offset      =  0x2E8,
            bitSize     =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFE_H7_CFG0",
            description = "RX DFE H7 equalization configuration register 0",
            offset      =  0x2E4,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFE_H6_CFG1",
            description = "RX DFE H6 equalization configuration register 1",
            offset      =  0x2E0,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFE_H6_CFG0",
            description = "RX DFE H6 equalization configuration register 0",
            offset      =  0x2DC,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_DCD_CFG",
            description = "TX duty cycle distortion correction configuration",
            offset      =  0x2D9,
            bitSize     =  6,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_DCD_EN",
            description = "Enable TX duty cycle distortion correction",
            offset      =  0x2D9,
            bitSize     =  1,
            bitOffset   =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_EML_PHI_TUNE",
            description = "TX electro-absorption modulator phi tuning",
            offset      =  0x2D9,
            bitSize     =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CPLL_CFG3",
            description = "CPLL configuration register 3",
            offset      =  0x2D8,
            bitSize     =  6,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFE_H5_CFG1",
            description = "RX DFE H5 equalization configuration register 1",
            offset      =  0x2D4,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PROCESS_PAR",
            description = "Process parameter setting for PMA tuning",
            offset      =  0x2D1,
            bitSize     =  3,
            bitOffset   =  5,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TEMPERATUR_PAR",
            description = "Temperature parameter setting for PMA tuning",
            offset      =  0x2D1,
            bitSize     =  4,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_MODE_SEL",
            description = "TX operating mode selection",
            offset      =  0x2D0,
            bitSize     =  3,
            bitOffset   =  5,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_SARC_LPBK_ENB",
            description = "TX SARC loopback enable",
            offset      =  0x2D0,
            bitSize     =  1,
            bitOffset   =  4,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFE_H5_CFG0",
            description = "RX DFE H5 equalization configuration register 0",
            offset      =  0x2CC,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFE_H4_CFG1",
            description = "RX DFE H4 equalization configuration register 1",
            offset      =  0x2C8,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFE_H4_CFG0",
            description = "RX DFE H4 equalization configuration register 0",
            offset      =  0x2C4,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFE_H3_CFG1",
            description = "RX DFE H3 equalization configuration register 1",
            offset      =  0x2C0,
            bitSize     =  16,
            mode        = "RW",
        ))

        # self.add(pr.RemoteVariable(
            # name         = "DFE_D_X_REL_POS",
            # description  = "DFE decision position relative setting",
            # offset       =  0x2BD,
            # bitSize      =  1,
            # bitOffset    =  6,
            # mode         = "RW",
        # ))

        # self.add(pr.RemoteVariable(
            # name         = "DFE_VCM_COMP_EN",
            # description  = "Enable DFE VCM compensation",
            # offset       =  0x2BD,
            # bitSize      =  1,
            # bitOffset    =  6,
            # mode         = "RW",
        # ))

        # self.add(pr.RemoteVariable(
            # name         = "GM_BIAS_SELECT",
            # description  = "Transconductance amplifier bias selection",
            # offset       =  0x2BD,
            # bitSize      =  1,
            # bitOffset    =  5,
            # mode         = "RW",
        # ))

        self.add(pr.RemoteVariable(
            name        = "EVODD_PHI_CFG",
            description = "Even/odd phase interpolator configuration",
            offset      =  0x2BC,
            bitSize     =  11,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFE_H3_CFG0",
            description = "RX DFE H3 equalization configuration register 0",
            offset      =  0x2B8,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PLL_SEL_MODE_GEN3",
            description = "PLL selection mode for PCIe Gen3",
            offset      =  0x2B5,
            bitSize     =  2,
            bitOffset   =  3,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PLL_SEL_MODE_GEN12",
            description = "PLL selection mode for PCIe Gen1/Gen2",
            offset      =  0x2B5,
            bitSize     =  2,
            bitOffset   =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RATE_SW_USE_DRP",
            description = "Use DRP for rate switching control",
            offset      =  0x2B5,
            bitSize     =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXPI_LPM",
            description = "RX phase interpolator low power mode enable",
            offset      =  0x2B4,
            bitSize     =  1,
            bitOffset   =  3,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXPI_VREFSEL",
            description = "RX phase interpolator voltage reference selection",
            offset      =  0x2B4,
            bitSize     =  1,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_CLK_SLIP_OVRD",
            description = "RX clock slip override value",
            offset      =  0x2B0,
            bitSize     =  5,
            bitOffset   =  3,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PCS_RSVD1",
            description = "PCS reserved register 1",
            offset      =  0x2B0,
            bitSize     =  3,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PCIE_TXPMA_CFG",
            description = "PCIe TX PMA configuration",
            offset      =  0x2AC,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PCIE_TXPCS_CFG_GEN3",
            description = "PCIe Gen3 TX PCS configuration",
            offset      =  0x2A8,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PCIE_RXPMA_CFG",
            description = "PCIe RX PMA configuration",
            offset      =  0x2A4,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXCDR_CFG5",
            description = "RX CDR configuration register 5",
            offset      =  0x2A0,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXCDR_CFG5_GEN3",
            description = "RX CDR configuration register 5 for PCIe Gen3",
            offset      =  0x29C,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXCDR_CFG4_GEN3",
            description = "RX CDR configuration register 4 for PCIe Gen3",
            offset      =  0x298,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXCDR_CFG3_GEN3",
            description = "RX CDR configuration register 3 for PCIe Gen3",
            offset      =  0x294,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXCDR_CFG2_GEN3",
            description = "RX CDR configuration register 2 for PCIe Gen3",
            offset      =  0x290,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXCDR_CFG1_GEN3",
            description = "RX CDR configuration register 1 for PCIe Gen3",
            offset      =  0x28C,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXCDR_CFG0_GEN3",
            description = "RX CDR configuration register 0 for PCIe Gen3",
            offset      =  0x288,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFE_GC_CFG2",
            description = "RX DFE gain control configuration register 2",
            offset      =  0x284,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFE_GC_CFG1",
            description = "RX DFE gain control configuration register 1",
            offset      =  0x280,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFE_GC_CFG0",
            description = "RX DFE gain control configuration register 0",
            offset      =  0x27C,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFE_UT_CFG0",
            description = "RX DFE UT tap configuration register 0",
            offset      =  0x278,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXPI_CFG1",
            description = "RX phase interpolator configuration register 1",
            offset      =  0x275,
            bitSize     =  2,
            bitOffset   =  6,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXPI_CFG2",
            description = "RX phase interpolator configuration register 2",
            offset      =  0x275,
            bitSize     =  2,
            bitOffset   =  4,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXPI_CFG3",
            description = "RX phase interpolator configuration register 3",
            offset      =  0x275,
            bitSize     =  2,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXPI_CFG4",
            description = "RX phase interpolator configuration register 4",
            offset      =  0x275,
            bitSize     =  1,
            bitOffset   =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXPI_CFG5",
            description = "RX phase interpolator configuration register 5",
            offset      =  0x275,
            bitSize     =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXPI_CFG6",
            description = "RX phase interpolator configuration register 6",
            offset      =  0x274,
            bitSize     =  3,
            bitOffset   =  5,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXPI_CFG0",
            description = "RX phase interpolator configuration register 0",
            offset      =  0x274,
            bitSize     =  2,
            bitOffset   =  3,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXPI_CFG0",
            description = "TX phase interpolator configuration register 0",
            offset      =  0x271,
            bitSize     =  2,
            bitOffset   =  3,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXPI_CFG1",
            description = "TX phase interpolator configuration register 1",
            offset      =  0x271,
            bitSize     =  2,
            bitOffset   =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXPI_CFG2",
            description = "TX phase interpolator configuration register 2",
            offset      =  0x270,
            bitSize     =  2,
            bitOffset   =  7,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXPI_CFG3",
            description = "TX phase interpolator configuration register 3",
            offset      =  0x270,
            bitSize     =  1,
            bitOffset   =  6,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXPI_CFG4",
            description = "TX phase interpolator configuration register 4",
            offset      =  0x270,
            bitSize     =  1,
            bitOffset   =  5,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXPI_CFG5",
            description = "TX phase interpolator configuration register 5",
            offset      =  0x270,
            bitSize     =  3,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_DFELPM_KLKH_AGC_STUP_EN",
            description = "Enable RX DFE LPM KLKH AGC startup",
            offset      =  0x26D,
            bitSize     =  1,
            bitOffset   =  7,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_DFELPM_CFG0",
            description = "RX DFE LPM configuration register 0",
            offset      =  0x26D,
            bitSize     =  4,
            bitOffset   =  3,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_DFELPM_CFG1",
            description = "RX DFE LPM configuration register 1",
            offset      =  0x26D,
            bitSize     =  1,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_DFE_KL_LPM_KH_CFG0",
            description = "RX DFE KL LPM KH loop filter configuration register 0",
            offset      =  0x26D,
            bitSize     =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_DFE_KL_LPM_KH_CFG1",
            description = "RX DFE KL LPM KH loop filter configuration register 1",
            offset      =  0x26C,
            bitSize     =  3,
            bitOffset   =  5,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXPI_PPM_CFG",
            description = "TX phase interpolator PPM offset configuration",
            offset      =  0x268,
            bitSize     =  8,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "GEARBOX_MODE",
            description = "Gearbox operating mode selection",
            offset      =  0x265,
            bitSize     =  5,
            bitOffset   =  3,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXPI_SYNFREQ_PPM",
            description = "TX phase interpolator synchronization frequency PPM",
            offset      =  0x265,
            bitSize     =  3,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXPI_PPMCLK_SEL",
            description = "TX phase interpolator PPM clock selection",
            offset      =  0x264,
            bitSize     =  1,
            bitOffset   =  7,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXPI_INVSTROBE_SEL",
            description = "TX phase interpolator inverted strobe selection",
            offset      =  0x264,
            bitSize     =  1,
            bitOffset   =  6,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXPI_GRAY_SEL",
            description = "TX phase interpolator Gray code selection",
            offset      =  0x264,
            bitSize     =  1,
            bitOffset   =  5,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXPI_LPM",
            description = "TX phase interpolator low power mode enable",
            offset      =  0x264,
            bitSize     =  1,
            bitOffset   =  3,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXPI_VREFSEL",
            description = "TX phase interpolator voltage reference selection",
            offset      =  0x264,
            bitSize     =  1,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFE_HE_CFG1",
            description = "RX DFE HE equalization configuration register 1",
            offset      =  0x260,
            bitSize     =  16,
            mode        = "RW",
        ))

        # self.add(pr.RemoteVariable(
            # name         = "RX_AFE_CM_EN",
            # description  = "Enable RX AFE common-mode detection",
            # offset       =  0x25D,
            # bitSize      =  1,
            # bitOffset    =  2,
            # mode         = "RW",
        # ))

        # self.add(pr.RemoteVariable(
            # name         = "RX_CAPFF_SARC_ENB",
            # description  = "Disable RX capture feedforward SARC",
            # offset       =  0x25D,
            # bitSize      =  1,
            # bitOffset    =  3,
            # mode         = "RW",
        # ))

        # self.add(pr.RemoteVariable(
            # name         = "RX_EYESCAN_VS_NEG_DIR",
            # description  = "Eye scan vertical scan negative direction enable",
            # offset       =  0x25D,
            # bitSize      =  1,
            # bitOffset    =  2,
            # mode         = "RW",
        # ))

        # self.add(pr.RemoteVariable(
            # name         = "RX_EYESCAN_VS_UT_SIGN",
            # description  = "Eye scan vertical scan UT sign selection",
            # offset       =  0x25D,
            # bitSize      =  1,
            # bitOffset    =  1,
            # mode         = "RW",
        # ))

        # self.add(pr.RemoteVariable(
            # name         = "RX_EYESCAN_VS_CODE",
            # description  = "Eye scan vertical scan voltage code",
            # offset       =  0x25C,
            # bitSize      =  7,
            # bitOffset    =  2,
            # mode         = "RW",
        # ))

        # self.add(pr.RemoteVariable(
            # name         = "RX_EYESCAN_VS_RANGE",
            # description  = "Eye scan vertical scan voltage range",
            # offset       =  0x25C,
            # bitSize      =  2,
            # mode         = "RW",
        # ))

        self.add(pr.RemoteVariable(
            name        = "PMA_RSV1",
            description = "PMA reserved configuration register 1",
            offset      =  0x254,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ES_CLK_PHASE_SEL",
            description = "Eye scan clock phase selection",
            offset      =  0x251,
            bitSize     =  1,
            bitOffset   =  3,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "USE_PCS_CLK_PHASE_SEL",
            description = "Use PCS clock for phase selection in eye scan",
            offset      =  0x251,
            bitSize     =  1,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXCFOK_CFG0",
            description = "RX channel frequency offset correction configuration register 0",
            offset      =  0x24C,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ADAPT_CFG1",
            description = "RX adaptation engine configuration register 1",
            offset      =  0x248,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ADAPT_CFG0",
            description = "RX adaptation engine configuration register 0",
            offset      =  0x244,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFE_UT_CFG1",
            description = "RX DFE UT tap configuration register 1",
            offset      =  0x240,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFE_VP_CFG1",
            description = "RX DFE VP tap configuration register 1",
            offset      =  0x23C,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFE_VP_CFG0",
            description = "RX DFE VP tap configuration register 0",
            offset      =  0x238,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFELPM_KL_CFG2",
            description = "RX DFE LPM KL loop filter configuration register 2",
            offset      =  0x234,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ACJTAG_MODE",
            description = "AC JTAG mode enable",
            offset      =  0x231,
            bitSize     =  1,
            bitOffset   =  7,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ACJTAG_DEBUG_MODE",
            description = "AC JTAG debug mode enable",
            offset      =  0x231,
            bitSize     =  1,
            bitOffset   =  6,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ACJTAG_RESET",
            description = "AC JTAG reset control",
            offset      =  0x231,
            bitSize     =  1,
            bitOffset   =  5,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RESET_POWERSAVE_DISABLE",
            description = "Disable power save during reset",
            offset      =  0x231,
            bitSize     =  1,
            bitOffset   =  4,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_TUNE_AFE_OS",
            description = "RX AFE offset tuning setting",
            offset      =  0x231,
            bitSize     =  2,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_DFE_KL_LPM_KL_CFG0",
            description = "RX DFE KL LPM KL loop filter configuration register 0",
            offset      =  0x231,
            bitSize     =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_DFE_KL_LPM_KL_CFG1",
            description = "RX DFE KL LPM KL loop filter configuration register 1",
            offset      =  0x230,
            bitSize     =  3,
            bitOffset   =  5,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXSYNC_MULTILANE",
            description = "Enable TX multi-lane synchronization",
            offset      =  0x22D,
            bitSize     =  1,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXSYNC_MULTILANE",
            description = "Enable RX multi-lane synchronization",
            offset      =  0x22D,
            bitSize     =  1,
            bitOffset   =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_CTLE3_LPF",
            description = "RX CTLE3 low-pass filter setting",
            offset      =  0x22C,
            bitSize     =  8,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_PMADATA_OPT",
            description = "TX PMA data optimization option",
            offset      =  0x229,
            bitSize     =  1,
            bitOffset   =  7,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXSYNC_OVRD",
            description = "RX synchronization override enable",
            offset      =  0x229,
            bitSize     =  1,
            bitOffset   =  6,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXSYNC_OVRD",
            description = "TX synchronization override enable",
            offset      =  0x229,
            bitSize     =  1,
            bitOffset   =  5,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_IDLE_DATA_ZERO",
            description = "Force TX data to zero during electrical idle",
            offset      =  0x229,
            bitSize     =  1,
            bitOffset   =  4,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "A_RXOSCALRESET",
            description = "Asynchronous RX oscillation calibration reset",
            offset      =  0x229,
            bitSize     =  1,
            bitOffset   =  3,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXOOB_CLK_CFG",
            description = "RX out-of-band clock configuration",
            offset      =  0x229,
            bitSize     =  1,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXSYNC_SKIP_DA",
            description = "Skip TX sync deskew alignment",
            offset      =  0x229,
            bitSize     =  1,
            bitOffset   =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXSYNC_SKIP_DA",
            description = "Skip RX sync deskew alignment",
            offset      =  0x229,
            bitSize     =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXOSCALRESET_TIME",
            description = "RX oscillation calibration reset duration timer",
            offset      =  0x228,
            bitSize     =  5,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXPRBS_LINKACQ_CNT",
            description = "RX PRBS link acquisition counter threshold",
            offset      =  0x224,
            bitSize     =  8,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_QPI_STATUS_EN",
            description = "Enable TX QPI status reporting",
            offset      =  0x215,
            bitSize     =  1,
            bitOffset   =  5,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_INT_DATAWIDTH",
            description = "TX internal data path width selection",
            offset      =  0x215,
            bitSize     =  2,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFE_HD_CFG1",
            description = "RX DFE HD tap configuration register 1",
            offset      =  0x210,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_MARGIN_LOW_3",
            description = "TX voltage margin low setting 3",
            offset      =  0x20D,
            bitSize     =  7,
            bitOffset   =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_MARGIN_LOW_4",
            description = "TX voltage margin low setting 4",
            offset      =  0x20C,
            bitSize     =  7,
            bitOffset   =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_MARGIN_LOW_1",
            description = "TX voltage margin low setting 1",
            offset      =  0x209,
            bitSize     =  7,
            bitOffset   =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_MARGIN_LOW_2",
            description = "TX voltage margin low setting 2",
            offset      =  0x208,
            bitSize     =  7,
            bitOffset   =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_MARGIN_FULL_4",
            description = "TX voltage margin full swing setting 4",
            offset      =  0x205,
            bitSize     =  7,
            bitOffset   =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_MARGIN_LOW_0",
            description = "TX voltage margin low setting 0",
            offset      =  0x204,
            bitSize     =  7,
            bitOffset   =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_MARGIN_FULL_2",
            description = "TX voltage margin full swing setting 2",
            offset      =  0x201,
            bitSize     =  7,
            bitOffset   =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_MARGIN_FULL_3",
            description = "TX voltage margin full swing setting 3",
            offset      =  0x200,
            bitSize     =  7,
            bitOffset   =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_MARGIN_FULL_0",
            description = "TX voltage margin full swing setting 0",
            offset      =  0x1FD,
            bitSize     =  7,
            bitOffset   =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_MARGIN_FULL_1",
            description = "TX voltage margin full swing setting 1",
            offset      =  0x1FC,
            bitSize     =  7,
            bitOffset   =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_CLKMUX_EN",
            description = "Enable TX clock mux",
            offset      =  0x1F9,
            bitSize     =  1,
            bitOffset   =  7,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_LOOPBACK_DRIVE_HIZ",
            description = "Drive TX output to high impedance during loopback",
            offset      =  0x1F9,
            bitSize     =  1,
            bitOffset   =  6,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_DRIVE_MODE",
            description = "TX output driver mode selection",
            offset      =  0x1F9,
            bitSize     =  5,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_EIDLE_ASSERT_DELAY",
            description = "TX electrical idle assert delay setting",
            offset      =  0x1F8,
            bitSize     =  3,
            bitOffset   =  5,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_EIDLE_DEASSERT_DELAY",
            description = "TX electrical idle deassert delay setting",
            offset      =  0x1F8,
            bitSize     =  3,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_RXDETECT_CFG",
            description = "TX RX detect configuration",
            offset      =  0x1F4,
            bitSize     =  14,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_MAINCURSOR_SEL",
            description = "TX main cursor selection for pre/post emphasis",
            offset      =  0x1F1,
            bitSize     =  1,
            bitOffset   =  6,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXGEARBOX_EN",
            description = "Enable TX gearbox for width conversion",
            offset      =  0x1F1,
            bitSize     =  1,
            bitOffset   =  5,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXOUT_DIV",
            description = "TX output clock divider value",
            offset      =  0x1F1,
            bitSize     =  3,
            mode        = "RW",
            # enum = {
                # 0: '1',
                # 4: '16',
                # 1: '2',
                # 2: '4',
                # 3: '8'},
        ))

        self.add(pr.RemoteVariable(
            name        = "TXBUF_EN",
            description = "Enable TX elastic buffer",
            offset      =  0x1F0,
            bitSize     =  1,
            bitOffset   =  7,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXBUF_RESET_ON_RATE_CHANGE",
            description = "Reset TX buffer on rate change",
            offset      =  0x1F0,
            bitSize     =  1,
            bitOffset   =  6,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_RXDETECT_REF",
            description = "TX RX detect reference voltage setting",
            offset      =  0x1F0,
            bitSize     =  3,
            bitOffset   =  3,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXFIFO_ADDR_CFG",
            description = "TX FIFO address configuration",
            offset      =  0x1F0,
            bitSize     =  1,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_DEEMPH0",
            description = "TX de-emphasis level 0 setting",
            offset      =  0x1ED,
            bitSize     =  8,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_DEEMPH1",
            description = "TX de-emphasis level 1 setting",
            offset      =  0x1EC,
            bitSize     =  8,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_CLK25_DIV",
            description = "TX 25 MHz clock divider value",
            offset      =  0x1E9,
            bitSize     =  5,
            bitOffset   =  3,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_XCLK_SEL",
            description = "TX transmit clock selection (TXUSR or TXOUT)",
            offset      =  0x1E9,
            bitSize     =  1,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_DATA_WIDTH",
            description = "TX internal data path width selection",
            offset      =  0x1E8,
            bitSize     =  4,
            mode        = "RW",
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
            name        = "TST_RSV0",
            description = "Test reserved register 0",
            offset      =  0x1E5,
            bitSize     =  8,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TST_RSV1",
            description = "Test reserved register 1",
            offset      =  0x1E4,
            bitSize     =  8,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TRANS_TIME_RATE",
            description = "Power state transition time rate setting",
            offset      =  0x1E1,
            bitSize     =  8,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PD_TRANS_TIME_NONE_P2",
            description = "Power down transition time from none to P2 state",
            offset      =  0x1DD,
            bitSize     =  8,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PD_TRANS_TIME_TO_P2",
            description = "Power down transition time to P2 state",
            offset      =  0x1DC,
            bitSize     =  8,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PD_TRANS_TIME_FROM_P2",
            description = "Power down transition time from P2 state",
            offset      =  0x1D8,
            bitSize     =  12,
            bitOffset   =  4,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TERM_RCAL_OVRD",
            description = "Termination resistance calibration override",
            offset      =  0x1D8,
            bitSize     =  2,
            bitOffset   =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFE_HF_CFG1",
            description = "RX DFE HF equalization configuration register 1",
            offset      =  0x1D4,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TERM_RCAL_CFG",
            description = "Termination resistance calibration configuration",
            offset      =  0x1D0,
            bitSize     =  15,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXPH_CFG",
            description = "TX phase configuration",
            offset      =  0x1CC,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXCDR_LOCK_CFG2",
            description = "RX CDR lock detection configuration register 2",
            offset      =  0x1C8,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXPH_MONITOR_SEL",
            description = "TX phase monitor selection",
            offset      =  0x1C4,
            bitSize     =  5,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TAPDLY_SET_TX",
            description = "TX tap delay setting",
            offset      =  0x1C4,
            bitSize     =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXDLY_CFG",
            description = "TX delay line configuration",
            offset      =  0x1C0,
            bitSize     =  16,
            mode        = "RW",
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
            name        = "RX_CLK25_DIV",
            description = "RX 25 MHz clock divider value",
            offset      =  0x1B4,
            bitSize     =  5,
            bitOffset   =  3,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "SATA_MAX_INIT",
            description = "SATA maximum COMINIT burst count",
            offset      =  0x1B1,
            bitSize     =  6,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "SATA_MAX_WAKE",
            description = "SATA maximum COMWAKE burst count",
            offset      =  0x1B0,
            bitSize     =  6,
            bitOffset   =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "SATA_MAX_BURST",
            description = "SATA maximum burst spacing count",
            offset      =  0x1AD,
            bitSize     =  6,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "SAS_MAX_COM",
            description = "SAS maximum COMSAS burst count",
            offset      =  0x1AC,
            bitSize     =  6,
            bitOffset   =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "SATA_MIN_INIT",
            description = "SATA minimum COMINIT burst count",
            offset      =  0x1A9,
            bitSize     =  6,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "SATA_MIN_WAKE",
            description = "SATA minimum COMWAKE burst count",
            offset      =  0x1A8,
            bitSize     =  6,
            bitOffset   =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "SATA_MIN_BURST",
            description = "SATA minimum burst spacing count",
            offset      =  0x1A5,
            bitSize     =  6,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "SAS_MIN_COM",
            description = "SAS minimum COMSAS burst count",
            offset      =  0x1A4,
            bitSize     =  6,
            bitOffset   =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "SATA_BURST_VAL",
            description = "SATA OOB burst value pattern",
            offset      =  0x1A1,
            bitSize     =  3,
            bitOffset   =  5,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "SATA_BURST_SEQ_LEN",
            description = "SATA OOB burst sequence length",
            offset      =  0x1A0,
            bitSize     =  4,
            bitOffset   =  4,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "SATA_EIDLE_VAL",
            description = "SATA electrical idle value pattern",
            offset      =  0x1A0,
            bitSize     =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXBUF_EIDLE_HI_CNT",
            description = "RX buffer high threshold count during electrical idle",
            offset      =  0x19D,
            bitSize     =  4,
            bitOffset   =  4,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXCDR_HOLD_DURING_EIDLE",
            description = "Hold RX CDR frequency during electrical idle",
            offset      =  0x19D,
            bitSize     =  1,
            bitOffset   =  3,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_DFE_LPM_HOLD_DURING_EIDLE",
            description = "Hold RX DFE LPM coefficients during electrical idle",
            offset      =  0x19D,
            bitSize     =  1,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXBUF_EIDLE_LO_CNT",
            description = "RX buffer low threshold count during electrical idle",
            offset      =  0x19C,
            bitSize     =  4,
            bitOffset   =  4,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXBUF_RESET_ON_EIDLE",
            description = "Reset RX buffer on electrical idle detection",
            offset      =  0x19C,
            bitSize     =  1,
            bitOffset   =  3,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXCDR_FR_RESET_ON_EIDLE",
            description = "Reset RX CDR frequency on electrical idle",
            offset      =  0x19C,
            bitSize     =  1,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXCDR_PH_RESET_ON_EIDLE",
            description = "Reset RX CDR phase on electrical idle",
            offset      =  0x19C,
            bitSize     =  1,
            bitOffset   =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXBUF_THRESH_OVRD",
            description = "Override RX buffer threshold values",
            offset      =  0x199,
            bitSize     =  1,
            bitOffset   =  7,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXBUF_RESET_ON_COMMAALIGN",
            description = "Reset RX buffer on comma alignment event",
            offset      =  0x199,
            bitSize     =  1,
            bitOffset   =  6,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXBUF_RESET_ON_RATE_CHANGE",
            description = "Reset RX buffer on rate change",
            offset      =  0x199,
            bitSize     =  1,
            bitOffset   =  5,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXBUF_RESET_ON_CB_CHANGE",
            description = "Reset RX buffer on channel bonding change",
            offset      =  0x199,
            bitSize     =  1,
            bitOffset   =  4,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXBUF_THRESH_UNDFLW",
            description = "RX buffer underflow threshold value",
            offset      =  0x198,
            bitSize     =  6,
            bitOffset   =  6,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_CLKMUX_EN",
            description = "Enable RX clock mux",
            offset      =  0x198,
            bitSize     =  1,
            bitOffset   =  5,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_DISPERR_SEQ_MATCH",
            description = "Enable disparity error sequence matching",
            offset      =  0x198,
            bitSize     =  1,
            bitOffset   =  4,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXBUF_ADDR_MODE",
            description = "RX buffer address mode selection",
            offset      =  0x198,
            bitSize     =  1,
            bitOffset   =  3,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_WIDEMODE_CDR",
            description = "Enable RX widebus CDR mode",
            offset      =  0x198,
            bitSize     =  1,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_INT_DATAWIDTH",
            description = "RX internal data path width selection",
            offset      =  0x198,
            bitSize     =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXBUF_THRESH_OVFLW",
            description = "RX buffer overflow threshold value",
            offset      =  0x195,
            bitSize     =  6,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "DMONITOR_CFG0",
            description = "Digital monitor configuration register 0",
            offset      =  0x194,
            bitSize     =  10,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_SIG_VALID_DLY",
            description = "RX signal valid delay cycles",
            offset      =  0x191,
            bitSize     =  5,
            bitOffset   =  3,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXSLIDE_MODE",
            description = "RX bit slide mode selection",
            offset      =  0x191,
            bitSize     =  2,
            bitOffset   =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXPRBS_ERR_LOOPBACK",
            description = "Loopback RX PRBS error to TX",
            offset      =  0x191,
            bitSize     =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXSLIDE_AUTO_WAIT",
            description = "RX automatic bit slide wait cycles",
            offset      =  0x190,
            bitSize     =  4,
            bitOffset   =  4,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXBUF_EN",
            description = "Enable RX elastic buffer",
            offset      =  0x190,
            bitSize     =  1,
            bitOffset   =  3,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_XCLK_SEL",
            description = "RX receive clock selection (RXREC or RXUSR)",
            offset      =  0x190,
            bitSize     =  2,
            bitOffset   =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXGEARBOX_EN",
            description = "Enable RX gearbox for width conversion",
            offset      =  0x190,
            bitSize     =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CBCC_DATA_SOURCE_SEL",
            description = "Channel bonding/clock correction data source selection",
            offset      =  0x18D,
            bitSize     =  1,
            bitOffset   =  7,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "OOB_PWRUP",
            description = "Power up OOB circuitry",
            offset      =  0x18D,
            bitSize     =  1,
            bitOffset   =  6,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXOOB_CFG",
            description = "RX out-of-band detection configuration",
            offset      =  0x18C,
            bitSize     =  9,
            bitOffset   =  5,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXOUT_DIV",
            description = "RX output clock divider value",
            offset      =  0x18C,
            bitSize     =  3,
            mode        = "RW",
            # enum = {
                # 0: '1',
                # 4: '16',
                # 1: '2',
                # 2: '4',
                # 3: '8'},
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_SUM_DFETAPREP_EN",
            description = "Enable RX summing amplifier DFE tap preparation",
            offset      =  0x189,
            bitSize     =  1,
            bitOffset   =  6,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_SUM_VCM_OVWR",
            description = "Override RX summing amplifier VCM level",
            offset      =  0x189,
            bitSize     =  1,
            bitOffset   =  5,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_SUM_IREF_TUNE",
            description = "RX summing amplifier reference current tuning",
            offset      =  0x189,
            bitSize     =  4,
            bitOffset   =  1,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_SUM_RES_CTRL",
            description = "RX summing amplifier load resistance control",
            offset      =  0x188,
            bitSize     =  2,
            bitOffset   =  7,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_SUM_VCMTUNE",
            description = "RX summing amplifier common-mode voltage tuning",
            offset      =  0x188,
            bitSize     =  4,
            bitOffset   =  3,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_SUM_VREF_TUNE",
            description = "RX summing amplifier reference voltage tuning",
            offset      =  0x188,
            bitSize     =  3,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXPH_MONITOR_SEL",
            description = "RX phase monitor selection",
            offset      =  0x185,
            bitSize     =  5,
            bitOffset   =  3,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_CM_BUF_PD",
            description = "Power down RX common-mode buffer",
            offset      =  0x185,
            bitSize     =  1,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_CM_BUF_CFG",
            description = "RX common-mode buffer configuration",
            offset      =  0x184,
            bitSize     =  4,
            bitOffset   =  6,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_CM_TRIM",
            description = "RX common-mode trim setting",
            offset      =  0x184,
            bitSize     =  4,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_CM_SEL",
            description = "RX common-mode termination selection",
            offset      =  0x184,
            bitSize     =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PCS_RSVD0",
            description = "PCS reserved register 0",
            offset      =  0x180,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_BIAS_CFG0",
            description = "RX bias configuration register 0",
            offset      =  0x17C,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFE_HD_CFG0",
            description = "RX DFE HD tap configuration register 0",
            offset      =  0x178,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFE_HF_CFG0",
            description = "RX DFE HF equalization configuration register 0",
            offset      =  0x174,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDLY_LCFG",
            description = "RX delay line loop configuration",
            offset      =  0x170,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDLY_CFG",
            description = "RX delay line configuration",
            offset      =  0x16C,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFE_OS_CFG1",
            description = "RX DFE offset correction configuration register 1",
            offset      =  0x168,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXPHDLY_CFG",
            description = "RX phase delay line configuration",
            offset      =  0x164,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFE_OS_CFG0",
            description = "RX DFE offset correction configuration register 0",
            offset      =  0x160,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXDLY_LCFG",
            description = "TX delay line loop configuration",
            offset      =  0x15C,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ALIGN_PCOMMA_DET",
            description = "Enable positive comma detection for byte alignment",
            offset      =  0x159,
            bitSize     =  1,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ALIGN_PCOMMA_VALUE",
            description = "Positive comma pattern value for byte alignment",
            offset      =  0x158,
            bitSize     =  10,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "LOCAL_MASTER",
            description = "Set this channel as local master for channel bonding",
            offset      =  0x155,
            bitSize     =  1,
            bitOffset   =  5,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PCS_PCIE_EN",
            description = "Enable PCS PCIe mode",
            offset      =  0x155,
            bitSize     =  1,
            bitOffset   =  4,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ALIGN_MCOMMA_DET",
            description = "Enable negative comma detection for byte alignment",
            offset      =  0x155,
            bitSize     =  1,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ALIGN_MCOMMA_VALUE",
            description = "Negative comma pattern value for byte alignment",
            offset      =  0x154,
            bitSize     =  10,
            mode        = "RW",
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
            name        = "RX_EN_HI_LR",
            description = "Enable RX high/low rate switching",
            offset      =  0x149,
            bitSize     =  1,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_DFE_AGC_CFG1",
            description = "RX DFE AGC configuration register 1",
            offset      =  0x148,
            bitSize     =  3,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_DFE_AGC_CFG0",
            description = "RX DFE AGC configuration register 0",
            offset      =  0x148,
            bitSize     =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ES_PMA_CFG",
            description = "Eye scan PMA configuration",
            offset      =  0x144,
            bitSize     =  10,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDFE_HC_CFG1",
            description = "RX DFE HC equalization configuration register 1",
            offset      =  0x140,
            bitSize     =  16,
            mode        = "RW",
        ))

        # self.add(pr.RemoteVariable(
            # name         = "ES_HORZ_OFFSET",
            # description  = "Eye scan horizontal offset setting",
            # offset       =  0x13C,
            # bitSize      =  12,
            # bitOffset    =  4,
            # mode         = "RW",
        # ))

        # self.add(pr.RemoteVariable(
            # name         = "FTS_LANE_DESKEW_CFG",
            # description  = "FTS lane deskew configuration setting",
            # offset       =  0x13C,
            # bitSize      =  1,
            # bitOffset    =  4,
            # mode         = "RW",
        # ))

        self.add(pr.RemoteVariable(
            name        = "FTS_LANE_DESKEW_EN",
            description = "Enable FTS lane deskew",
            offset      =  0x138,
            bitSize     =  1,
            bitOffset   =  4,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "FTS_DESKEW_SEQ_ENABLE",
            description = "Enable FTS deskew sequence detection",
            offset      =  0x138,
            bitSize     =  4,
            mode        = "RW",
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
            name        = "TX_PROGDIV_CFG",
            description = "TX programmable divider configuration",
            offset      =  0xF8,
            bitSize     =  16,
            mode        = "RW",
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
            name        = "RXDFE_HC_CFG0",
            description = "RX DFE HC equalization configuration register 0",
            offset      =  0xF4,
            bitSize     =  16,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ES_CONTROL",
            description = "Eye scan control register",
            offset      =  0xF1,
            bitSize     =  6,
            bitOffset   =  2,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ES_ERRDET_EN",
            description = "Enable eye scan error detection",
            offset      =  0xF1,
            bitSize     =  1,
            bitOffset   =  1,
            mode        = "RW",
        ))
