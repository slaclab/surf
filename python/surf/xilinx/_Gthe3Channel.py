#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Gthe3Channel
#-----------------------------------------------------------------------------
# File       : Gthe3Channel.py
# Created    : 2017-04-12
#-----------------------------------------------------------------------------
# Description:
# PyRogue Gthe3Channel
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

class Gthe3Channel(pr.Device):
    def __init__(   self,       
        name        = "Gthe3Channel",
        description = "Gthe3Channel",
        memBase     =  None,
        offset      =  0x00,
        hidden      =  False,
        expand      =  True,
    ):
        super().__init__(
            name        = name,
            description = description,
            memBase     = memBase,
            offset      = offset,
            hidden      = hidden,
            expand      = expand,
        ) 

        ##############################
        # Variables
        ##############################

        self.addVariable(   
            name         = "CDR_SWAP_MODE_EN",
            description  = "",
            offset       =  0x08,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXCDRFREQRESET_TIME",
            description  = "",
            offset       =  0x0C,
            bitSize      =  5,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_DATA_WIDTH",
            description  = "",
            offset       =  0x0C,
            bitSize      =  4,
            bitOffset    =  0x05,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "EYE_SCAN_SWAP_EN",
            description  = "",
            offset       =  0x0D,
            bitSize      =  1,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXBUFRESET_TIME",
            description  = "",
            offset       =  0x0D,
            bitSize      =  5,
            bitOffset    =  0x03,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_FABINT_USRCLK_FLOP",
            description  = "",
            offset       =  0x10,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFELPMRESET_TIME",
            description  = "",
            offset       =  0x10,
            bitSize      =  7,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "PCI3_RX_ELECIDLE_H2L_DISABLE",
            description  = "",
            offset       =  0x11,
            bitSize      =  3,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXCDRPHRESET_TIME",
            description  = "",
            offset       =  0x11,
            bitSize      =  5,
            bitOffset    =  0x03,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXELECIDLE_CFG",
            description  = "",
            offset       =  0x14,
            bitSize      =  3,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXPCSRESET_TIME",
            description  = "",
            offset       =  0x14,
            bitSize      =  5,
            bitOffset    =  0x03,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "PCI3_RX_FIFO_DISABLE",
            description  = "",
            offset       =  0x15,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "PCI3_RX_ELECIDLE_EI2_ENABLE",
            description  = "",
            offset       =  0x15,
            bitSize      =  1,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "PCI3_RX_ELECIDLE_LP4_DISABLE",
            description  = "",
            offset       =  0x15,
            bitSize      =  1,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXPMARESET_TIME",
            description  = "",
            offset       =  0x15,
            bitSize      =  5,
            bitOffset    =  0x03,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFE_HB_CFG1",
            description  = "",
            offset       =  0x18,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TXPCSRESET_TIME",
            description  = "",
            offset       =  0x24,
            bitSize      =  5,
            bitOffset    =  0x03,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TX_PMA_POWER_SAVE",
            description  = "",
            offset       =  0x25,
            bitSize      =  1,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_PMA_POWER_SAVE",
            description  = "",
            offset       =  0x25,
            bitSize      =  1,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TXPMARESET_TIME",
            description  = "",
            offset       =  0x25,
            bitSize      =  5,
            bitOffset    =  0x03,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TX_FABINT_USRCLK_FLOP",
            description  = "",
            offset       =  0x2C,
            bitSize      =  1,
            bitOffset    =  0x04,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXPMACLK_SEL",
            description  = "",
            offset       =  0x2B,
            bitSize      =  2,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "WB_MODE",
            description  = "",
            offset       =  0x2B,
            bitSize      =  2,
            bitOffset    =  0x06,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXISCANRESET_TIME",
            description  = "",
            offset       =  0x30,
            bitSize      =  5,
            bitOffset    =  0x05,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TX_PROGCLK_SEL",
            description  = "",
            offset       =  0x31,
            bitSize      =  2,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariables(  
            name         = "RXCDR_CFG",
            description  = "",
            offset       =  0x38,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
            number       =  5,
            stride       =  4,
        )

        self.addVariable(   
            name         = "RXCDR_LOCK_CFG0",
            description  = "",
            offset       =  0x4C,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CHAN_BOND_SEQ_1_1",
            description  = "",
            offset       =  0x50,
            bitSize      =  10,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CHAN_BOND_SEQ_LEN",
            description  = "",
            offset       =  0x51,
            bitSize      =  2,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CHAN_BOND_MAX_SKEW",
            description  = "",
            offset       =  0x51,
            bitSize      =  4,
            bitOffset    =  0x04,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CHAN_BOND_SEQ_1_3",
            description  = "",
            offset       =  0x54,
            bitSize      =  10,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "PCI3_RX_ELECIDLE_HI_COUNT",
            description  = "",
            offset       =  0x55,
            bitSize      =  5,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CHAN_BOND_SEQ_1_4",
            description  = "",
            offset       =  0x58,
            bitSize      =  10,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "PCI3_RX_ELECIDLE_H2L_COUNT",
            description  = "",
            offset       =  0x59,
            bitSize      =  5,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "PCI3_PIPE_RX_ELECIDLE",
            description  = "",
            offset       =  0x5C,
            bitSize      =  1,
            bitOffset    =  0x04,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "PCI3_AUTO_REALIGN",
            description  = "",
            offset       =  0x5C,
            bitSize      =  2,
            bitOffset    =  0x05,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "OOBDIVCTL",
            description  = "",
            offset       =  0x5C,
            bitSize      =  2,
            bitOffset    =  0x07,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_DEFER_RESET_BUF_EN",
            description  = "",
            offset       =  0x5D,
            bitSize      =  1,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_BUFFER_CFG",
            description  = "",
            offset       =  0x5D,
            bitSize      =  6,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CHAN_BOND_SEQ_2_1",
            description  = "",
            offset       =  0x60,
            bitSize      =  10,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "PCI3_RX_ASYNC_EBUF_BYPASS",
            description  = "",
            offset       =  0x61,
            bitSize      =  2,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CHAN_BOND_SEQ_1_ENABLE",
            description  = "",
            offset       =  0x61,
            bitSize      =  4,
            bitOffset    =  0x04,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CHAN_BOND_SEQ_2_2",
            description  = "",
            offset       =  0x64,
            bitSize      =  10,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CHAN_BOND_SEQ_2_3",
            description  = "",
            offset       =  0x68,
            bitSize      =  10,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CHAN_BOND_SEQ_2_4",
            description  = "",
            offset       =  0x6C,
            bitSize      =  10,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CLK_COR_MIN_LAT",
            description  = "",
            offset       =  0x70,
            bitSize      =  6,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CLK_COR_KEEP_IDLE",
            description  = "",
            offset       =  0x70,
            bitSize      =  1,
            bitOffset    =  0x06,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CHAN_BOND_SEQ_2_USE",
            description  = "",
            offset       =  0x71,
            bitSize      =  1,
            bitOffset    =  0x03,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CHAN_BOND_SEQ_2_ENABLE",
            description  = "",
            offset       =  0x71,
            bitSize      =  4,
            bitOffset    =  0x04,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CHAN_BOND_KEEP_ALIGN",
            description  = "",
            offset       =  0x74,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CLK_COR_SEQ_LEN",
            description  = "",
            offset       =  0x74,
            bitSize      =  2,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CLK_COR_REPEAT_WAIT",
            description  = "",
            offset       =  0x74,
            bitSize      =  5,
            bitOffset    =  0x04,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CLK_COR_PRECEDENCE",
            description  = "",
            offset       =  0x75,
            bitSize      =  1,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CLK_COR_MAX_LAT",
            description  = "",
            offset       =  0x75,
            bitSize      =  6,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CLK_COR_SEQ_1_1",
            description  = "",
            offset       =  0x78,
            bitSize      =  10,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CLK_COR_SEQ_1_2",
            description  = "",
            offset       =  0x7C,
            bitSize      =  10,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CLK_COR_SEQ_1_3",
            description  = "",
            offset       =  0x80,
            bitSize      =  10,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CLK_COR_SEQ_1_4",
            description  = "",
            offset       =  0x84,
            bitSize      =  10,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CLK_COR_SEQ_2_1",
            description  = "",
            offset       =  0x88,
            bitSize      =  10,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CLK_COR_SEQ_1_ENABLE",
            description  = "",
            offset       =  0x89,
            bitSize      =  4,
            bitOffset    =  0x04,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CLK_COR_SEQ_2_2",
            description  = "",
            offset       =  0x8C,
            bitSize      =  10,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CLK_COR_SEQ_2_3",
            description  = "",
            offset       =  0x90,
            bitSize      =  10,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CLK_CORRECT_USE",
            description  = "",
            offset       =  0x91,
            bitSize      =  1,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CLK_COR_SEQ_2_USE",
            description  = "",
            offset       =  0x91,
            bitSize      =  1,
            bitOffset    =  0x03,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CLK_COR_SEQ_2_ENABLE",
            description  = "",
            offset       =  0x91,
            bitSize      =  4,
            bitOffset    =  0x04,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CLK_COR_SEQ_2_4",
            description  = "",
            offset       =  0x94,
            bitSize      =  10,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFE_HE_CFG0",
            description  = "",
            offset       =  0x98,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "ALIGN_COMMA_ENABLE",
            description  = "",
            offset       =  0x9C,
            bitSize      =  10,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "SHOW_REALIGN_COMMA",
            description  = "",
            offset       =  0x9D,
            bitSize      =  1,
            bitOffset    =  0x03,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "ALIGN_COMMA_DOUBLE",
            description  = "",
            offset       =  0x9D,
            bitSize      =  1,
            bitOffset    =  0x04,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "ALIGN_COMMA_WORD",
            description  = "",
            offset       =  0x9D,
            bitSize      =  3,
            bitOffset    =  0x05,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TXDRVBIAS_N",
            description  = "",
            offset       =  0xA0,
            bitSize      =  4,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CPLL_FBDIV_45",
            description  = "",
            offset       =  0xA0,
            bitSize      =  1,
            bitOffset    =  0x07,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CPLL_FBDIV",
            description  = "",
            offset       =  0xA1,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CPLL_LOCK_CFG",
            description  = "",
            offset       =  0xA4,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TXDRVBIAS_P",
            description  = "",
            offset       =  0xA8,
            bitSize      =  4,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "SATA_CPLL_CFG",
            description  = "",
            offset       =  0xA8,
            bitSize      =  2,
            bitOffset    =  0x05,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CPLL_REFCLK_DIV",
            description  = "",
            offset       =  0xA9,
            bitSize      =  5,
            bitOffset    =  0x03,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CPLL_INIT_CFG0",
            description  = "",
            offset       =  0xAC,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "A_RXPROGDIVRESET",
            description  = "",
            offset       =  0xB0,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "A_TXPROGDIVRESET",
            description  = "",
            offset       =  0xB0,
            bitSize      =  1,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_DIVRESET_TIME",
            description  = "",
            offset       =  0xB0,
            bitSize      =  5,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TX_DIVRESET_TIME",
            description  = "",
            offset       =  0xB0,
            bitSize      =  5,
            bitOffset    =  0x07,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "DEC_PCOMMA_DETECT",
            description  = "",
            offset       =  0xB1,
            bitSize      =  1,
            bitOffset    =  0x07,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXCDR_LOCK_CFG1",
            description  = "",
            offset       =  0xB4,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXCFOK_CFG1",
            description  = "",
            offset       =  0xB8,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFE_H2_CFG0",
            description  = "",
            offset       =  0xBC,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFE_H2_CFG1",
            description  = "",
            offset       =  0xC0,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXCFOK_CFG2",
            description  = "",
            offset       =  0xC4,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXLPM_CFG",
            description  = "",
            offset       =  0xC8,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXLPM_KH_CFG0",
            description  = "",
            offset       =  0xCC,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXLPM_KH_CFG1",
            description  = "",
            offset       =  0xD0,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFELPM_KL_CFG0",
            description  = "",
            offset       =  0xD4,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFELPM_KL_CFG1",
            description  = "",
            offset       =  0xD8,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXLPM_OS_CFG0",
            description  = "",
            offset       =  0xDC,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXLPM_OS_CFG1",
            description  = "",
            offset       =  0xE0,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXLPM_GC_CFG",
            description  = "",
            offset       =  0xE4,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "DMONITOR_CFG1",
            description  = "",
            offset       =  0xE9,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "ES_PRESCALE",
            description  = "",
            offset       =  0xF0,
            bitSize      =  5,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "ES_EYE_SCAN_EN",
            description  = "",
            offset       =  0xF1,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFE_HB_CFG0",
            description  = "",
            offset       =  0x33C,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFE_HA_CFG1",
            description  = "",
            offset       =  0x338,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CPLL_INIT_CFG1",
            description  = "",
            offset       =  0x335,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_DDI_SEL",
            description  = "",
            offset       =  0x334,
            bitSize      =  6,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "DEC_VALID_COMMA_ONLY",
            description  = "",
            offset       =  0x334,
            bitSize      =  1,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "DEC_MCOMMA_DETECT",
            description  = "",
            offset       =  0x334,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CPLL_CFG1",
            description  = "",
            offset       =  0x330,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CPLL_CFG0",
            description  = "",
            offset       =  0x32C,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CHAN_BOND_SEQ_1_2",
            description  = "",
            offset       =  0x328,
            bitSize      =  10,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFE_HA_CFG0",
            description  = "",
            offset       =  0x320,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFE_H9_CFG1",
            description  = "",
            offset       =  0x31C,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_PROGDIV_CFG",
            description  = "",
            offset       =  0x318,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFE_H9_CFG0",
            description  = "",
            offset       =  0x314,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "PCIE_RXPCS_CFG_GEN3",
            description  = "",
            offset       =  0x310,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "PCIE_BUFG_DIV_CTRL",
            description  = "",
            offset       =  0x30C,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFE_H8_CFG1",
            description  = "",
            offset       =  0x308,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFE_H8_CFG0",
            description  = "",
            offset       =  0x304,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFE_H7_CFG1",
            description  = "",
            offset       =  0x300,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXPHBEACON_CFG",
            description  = "",
            offset       =  0x2FC,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXPHSLIP_CFG",
            description  = "",
            offset       =  0x2F8,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXPHSAMP_CFG",
            description  = "",
            offset       =  0x2F4,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CPLL_CFG2",
            description  = "",
            offset       =  0x2F0,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TXGBOX_FIFO_INIT_RD_ADDR",
            description  = "",
            offset       =  0x2ED,
            bitSize      =  3,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TX_SAMPLE_PERIOD",
            description  = "",
            offset       =  0x2EC,
            bitSize      =  3,
            bitOffset    =  0x06,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXGBOX_FIFO_INIT_RD_ADDR",
            description  = "",
            offset       =  0x2EC,
            bitSize      =  3,
            bitOffset    =  0x03,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_SAMPLE_PERIOD",
            description  = "",
            offset       =  0x2EC,
            bitSize      =  3,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "DDI_REALIGN_WAIT",
            description  = "",
            offset       =  0x2E8,
            bitSize      =  5,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "DDI_CTRL",
            description  = "",
            offset       =  0x2E8,
            bitSize      =  2,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFE_H7_CFG0",
            description  = "",
            offset       =  0x2E4,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFE_H6_CFG1",
            description  = "",
            offset       =  0x2E0,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFE_H6_CFG0",
            description  = "",
            offset       =  0x2DC,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TX_DCD_CFG",
            description  = "",
            offset       =  0x2D9,
            bitSize      =  6,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TX_DCD_EN",
            description  = "",
            offset       =  0x2D9,
            bitSize      =  1,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TX_EML_PHI_TUNE",
            description  = "",
            offset       =  0x2D9,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CPLL_CFG3",
            description  = "",
            offset       =  0x2D8,
            bitSize      =  6,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFE_H5_CFG1",
            description  = "",
            offset       =  0x2D4,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "PROCESS_PAR",
            description  = "",
            offset       =  0x2D1,
            bitSize      =  3,
            bitOffset    =  0x05,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TEMPERATUR_PAR",
            description  = "",
            offset       =  0x2D1,
            bitSize      =  4,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TX_MODE_SEL",
            description  = "",
            offset       =  0x2D0,
            bitSize      =  3,
            bitOffset    =  0x05,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TX_SARC_LPBK_ENB",
            description  = "",
            offset       =  0x2D0,
            bitSize      =  1,
            bitOffset    =  0x04,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFE_H5_CFG0",
            description  = "",
            offset       =  0x2CC,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFE_H4_CFG1",
            description  = "",
            offset       =  0x2C8,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFE_H4_CFG0",
            description  = "",
            offset       =  0x2C4,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFE_H3_CFG1",
            description  = "",
            offset       =  0x2C0,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "DFE_D_X_REL_POS",
            description  = "",
            offset       =  0x2BD,
            bitSize      =  1,
            bitOffset    =  0x06,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "DFE_VCM_COMP_EN",
            description  = "",
            offset       =  0x2BD,
            bitSize      =  1,
            bitOffset    =  0x06,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "GM_BIAS_SELECT",
            description  = "",
            offset       =  0x2BD,
            bitSize      =  1,
            bitOffset    =  0x05,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "EVODD_PHI_CFG",
            description  = "",
            offset       =  0x2BC,
            bitSize      =  11,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFE_H3_CFG0",
            description  = "",
            offset       =  0x2B8,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "PLL_SEL_MODE_GEN3",
            description  = "",
            offset       =  0x2B5,
            bitSize      =  2,
            bitOffset    =  0x03,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "PLL_SEL_MODE_GEN12",
            description  = "",
            offset       =  0x2B5,
            bitSize      =  2,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RATE_SW_USE_DRP",
            description  = "",
            offset       =  0x2B5,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXPI_LPM",
            description  = "",
            offset       =  0x2B4,
            bitSize      =  1,
            bitOffset    =  0x03,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXPI_VREFSEL",
            description  = "",
            offset       =  0x2B4,
            bitSize      =  1,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_CLK_SLIP_OVRD",
            description  = "",
            offset       =  0x2B0,
            bitSize      =  5,
            bitOffset    =  0x03,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "PCS_RSVD1",
            description  = "",
            offset       =  0x2B0,
            bitSize      =  3,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "PCIE_TXPMA_CFG",
            description  = "",
            offset       =  0x2AC,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "PCIE_TXPCS_CFG_GEN3",
            description  = "",
            offset       =  0x2A8,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "PCIE_RXPMA_CFG",
            description  = "",
            offset       =  0x2A4,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXCDR_CFG5",
            description  = "",
            offset       =  0x2A0,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXCDR_CFG5_GEN3",
            description  = "",
            offset       =  0x29C,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXCDR_CFG4_GEN3",
            description  = "",
            offset       =  0x298,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXCDR_CFG3_GEN3",
            description  = "",
            offset       =  0x294,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXCDR_CFG2_GEN3",
            description  = "",
            offset       =  0x290,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXCDR_CFG1_GEN3",
            description  = "",
            offset       =  0x28C,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXCDR_CFG0_GEN3",
            description  = "",
            offset       =  0x288,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFE_GC_CFG2",
            description  = "",
            offset       =  0x284,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFE_GC_CFG1",
            description  = "",
            offset       =  0x280,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFE_GC_CFG0",
            description  = "",
            offset       =  0x27C,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFE_UT_CFG0",
            description  = "",
            offset       =  0x278,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXPI_CFG1",
            description  = "",
            offset       =  0x275,
            bitSize      =  2,
            bitOffset    =  0x06,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXPI_CFG2",
            description  = "",
            offset       =  0x275,
            bitSize      =  2,
            bitOffset    =  0x04,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXPI_CFG3",
            description  = "",
            offset       =  0x275,
            bitSize      =  2,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXPI_CFG4",
            description  = "",
            offset       =  0x275,
            bitSize      =  1,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXPI_CFG5",
            description  = "",
            offset       =  0x275,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXPI_CFG6",
            description  = "",
            offset       =  0x274,
            bitSize      =  3,
            bitOffset    =  0x05,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXPI_CFG0",
            description  = "",
            offset       =  0x274,
            bitSize      =  2,
            bitOffset    =  0x03,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TXPI_CFG0",
            description  = "",
            offset       =  0x271,
            bitSize      =  2,
            bitOffset    =  0x03,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TXPI_CFG1",
            description  = "",
            offset       =  0x271,
            bitSize      =  2,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TXPI_CFG2",
            description  = "",
            offset       =  0x270,
            bitSize      =  2,
            bitOffset    =  0x07,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TXPI_CFG3",
            description  = "",
            offset       =  0x270,
            bitSize      =  1,
            bitOffset    =  0x06,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TXPI_CFG4",
            description  = "",
            offset       =  0x270,
            bitSize      =  1,
            bitOffset    =  0x05,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TXPI_CFG5",
            description  = "",
            offset       =  0x270,
            bitSize      =  3,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_DFELPM_KLKH_AGC_STUP_EN",
            description  = "",
            offset       =  0x26D,
            bitSize      =  1,
            bitOffset    =  0x07,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_DFELPM_CFG0",
            description  = "",
            offset       =  0x26D,
            bitSize      =  4,
            bitOffset    =  0x03,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_DFELPM_CFG1",
            description  = "",
            offset       =  0x26D,
            bitSize      =  1,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_DFE_KL_LPM_KH_CFG0",
            description  = "",
            offset       =  0x26D,
            bitSize      =  2,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_DFE_KL_LPM_KH_CFG1",
            description  = "",
            offset       =  0x26C,
            bitSize      =  3,
            bitOffset    =  0x05,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TXPI_PPM_CFG",
            description  = "",
            offset       =  0x268,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "GEARBOX_MODE",
            description  = "",
            offset       =  0x265,
            bitSize      =  5,
            bitOffset    =  0x03,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TXPI_SYNFREQ_PPM",
            description  = "",
            offset       =  0x265,
            bitSize      =  3,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TXPI_PPMCLK_SEL",
            description  = "",
            offset       =  0x264,
            bitSize      =  1,
            bitOffset    =  0x07,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TXPI_INVSTROBE_SEL",
            description  = "",
            offset       =  0x264,
            bitSize      =  1,
            bitOffset    =  0x06,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TXPI_GRAY_SEL",
            description  = "",
            offset       =  0x264,
            bitSize      =  1,
            bitOffset    =  0x05,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TXPI_LPM",
            description  = "",
            offset       =  0x264,
            bitSize      =  1,
            bitOffset    =  0x03,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TXPI_VREFSEL",
            description  = "",
            offset       =  0x264,
            bitSize      =  1,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFE_HE_CFG1",
            description  = "",
            offset       =  0x260,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_AFE_CM_EN",
            description  = "",
            offset       =  0x25D,
            bitSize      =  1,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_CAPFF_SARC_ENB",
            description  = "",
            offset       =  0x25D,
            bitSize      =  1,
            bitOffset    =  0x03,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_EYESCAN_VS_NEG_DIR",
            description  = "",
            offset       =  0x25D,
            bitSize      =  1,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_EYESCAN_VS_UT_SIGN",
            description  = "",
            offset       =  0x25D,
            bitSize      =  1,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_EYESCAN_VS_CODE",
            description  = "",
            offset       =  0x25C,
            bitSize      =  7,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_EYESCAN_VS_RANGE",
            description  = "",
            offset       =  0x25C,
            bitSize      =  2,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "PMA_RSV1",
            description  = "",
            offset       =  0x254,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "ES_CLK_PHASE_SEL",
            description  = "",
            offset       =  0x251,
            bitSize      =  1,
            bitOffset    =  0x03,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "USE_PCS_CLK_PHASE_SEL",
            description  = "",
            offset       =  0x251,
            bitSize      =  1,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXCFOK_CFG0",
            description  = "",
            offset       =  0x24C,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "ADAPT_CFG1",
            description  = "",
            offset       =  0x248,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "ADAPT_CFG0",
            description  = "",
            offset       =  0x244,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFE_UT_CFG1",
            description  = "",
            offset       =  0x240,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFE_VP_CFG1",
            description  = "",
            offset       =  0x23C,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFE_VP_CFG0",
            description  = "",
            offset       =  0x238,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFELPM_KL_CFG2",
            description  = "",
            offset       =  0x234,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "ACJTAG_MODE",
            description  = "",
            offset       =  0x231,
            bitSize      =  1,
            bitOffset    =  0x07,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "ACJTAG_DEBUG_MODE",
            description  = "",
            offset       =  0x231,
            bitSize      =  1,
            bitOffset    =  0x06,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "ACJTAG_RESET",
            description  = "",
            offset       =  0x231,
            bitSize      =  1,
            bitOffset    =  0x05,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RESET_POWERSAVE_DISABLE",
            description  = "",
            offset       =  0x231,
            bitSize      =  1,
            bitOffset    =  0x04,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_TUNE_AFE_OS",
            description  = "",
            offset       =  0x231,
            bitSize      =  2,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_DFE_KL_LPM_KL_CFG0",
            description  = "",
            offset       =  0x231,
            bitSize      =  2,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_DFE_KL_LPM_KL_CFG1",
            description  = "",
            offset       =  0x230,
            bitSize      =  3,
            bitOffset    =  0x05,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TXSYNC_MULTILANE",
            description  = "",
            offset       =  0x22D,
            bitSize      =  1,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXSYNC_MULTILANE",
            description  = "",
            offset       =  0x22D,
            bitSize      =  1,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_CTLE3_LPF",
            description  = "",
            offset       =  0x22C,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TX_PMADATA_OPT",
            description  = "",
            offset       =  0x229,
            bitSize      =  1,
            bitOffset    =  0x07,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXSYNC_OVRD",
            description  = "",
            offset       =  0x229,
            bitSize      =  1,
            bitOffset    =  0x06,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TXSYNC_OVRD",
            description  = "",
            offset       =  0x229,
            bitSize      =  1,
            bitOffset    =  0x05,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TX_IDLE_DATA_ZERO",
            description  = "",
            offset       =  0x229,
            bitSize      =  1,
            bitOffset    =  0x04,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "A_RXOSCALRESET",
            description  = "",
            offset       =  0x229,
            bitSize      =  1,
            bitOffset    =  0x03,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXOOB_CLK_CFG",
            description  = "",
            offset       =  0x229,
            bitSize      =  1,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TXSYNC_SKIP_DA",
            description  = "",
            offset       =  0x229,
            bitSize      =  1,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXSYNC_SKIP_DA",
            description  = "",
            offset       =  0x229,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXOSCALRESET_TIME",
            description  = "",
            offset       =  0x228,
            bitSize      =  5,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXPRBS_LINKACQ_CNT",
            description  = "",
            offset       =  0x224,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TX_QPI_STATUS_EN",
            description  = "",
            offset       =  0x215,
            bitSize      =  1,
            bitOffset    =  0x05,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TX_INT_DATAWIDTH",
            description  = "",
            offset       =  0x215,
            bitSize      =  2,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFE_HD_CFG1",
            description  = "",
            offset       =  0x210,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TX_MARGIN_LOW_3",
            description  = "",
            offset       =  0x20D,
            bitSize      =  7,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TX_MARGIN_LOW_4",
            description  = "",
            offset       =  0x20C,
            bitSize      =  7,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TX_MARGIN_LOW_1",
            description  = "",
            offset       =  0x209,
            bitSize      =  7,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TX_MARGIN_LOW_2",
            description  = "",
            offset       =  0x208,
            bitSize      =  7,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TX_MARGIN_FULL_4",
            description  = "",
            offset       =  0x205,
            bitSize      =  7,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TX_MARGIN_LOW_0",
            description  = "",
            offset       =  0x204,
            bitSize      =  7,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TX_MARGIN_FULL_2",
            description  = "",
            offset       =  0x201,
            bitSize      =  7,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TX_MARGIN_FULL_3",
            description  = "",
            offset       =  0x200,
            bitSize      =  7,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TX_MARGIN_FULL_0",
            description  = "",
            offset       =  0x1FD,
            bitSize      =  7,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TX_MARGIN_FULL_1",
            description  = "",
            offset       =  0x1FC,
            bitSize      =  7,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TX_CLKMUX_EN",
            description  = "",
            offset       =  0x1F9,
            bitSize      =  1,
            bitOffset    =  0x07,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TX_LOOPBACK_DRIVE_HIZ",
            description  = "",
            offset       =  0x1F9,
            bitSize      =  1,
            bitOffset    =  0x06,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TX_DRIVE_MODE",
            description  = "",
            offset       =  0x1F9,
            bitSize      =  5,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TX_EIDLE_ASSERT_DELAY",
            description  = "",
            offset       =  0x1F8,
            bitSize      =  3,
            bitOffset    =  0x05,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TX_EIDLE_DEASSERT_DELAY",
            description  = "",
            offset       =  0x1F8,
            bitSize      =  3,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TX_RXDETECT_CFG",
            description  = "",
            offset       =  0x1F4,
            bitSize      =  14,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TX_MAINCURSOR_SEL",
            description  = "",
            offset       =  0x1F1,
            bitSize      =  1,
            bitOffset    =  0x06,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TXGEARBOX_EN",
            description  = "",
            offset       =  0x1F1,
            bitSize      =  1,
            bitOffset    =  0x05,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TXOUT_DIV",
            description  = "",
            offset       =  0x1F1,
            bitSize      =  3,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TXBUF_EN",
            description  = "",
            offset       =  0x1F0,
            bitSize      =  1,
            bitOffset    =  0x07,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TXBUF_RESET_ON_RATE_CHANGE",
            description  = "",
            offset       =  0x1F0,
            bitSize      =  1,
            bitOffset    =  0x06,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TX_RXDETECT_REF",
            description  = "",
            offset       =  0x1F0,
            bitSize      =  3,
            bitOffset    =  0x03,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TXFIFO_ADDR_CFG",
            description  = "",
            offset       =  0x1F0,
            bitSize      =  1,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TX_DEEMPH0",
            description  = "",
            offset       =  0x1ED,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TX_DEEMPH1",
            description  = "",
            offset       =  0x1EC,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TX_CLK25_DIV",
            description  = "",
            offset       =  0x1E9,
            bitSize      =  5,
            bitOffset    =  0x03,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TX_XCLK_SEL",
            description  = "",
            offset       =  0x1E9,
            bitSize      =  1,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TX_DATA_WIDTH",
            description  = "",
            offset       =  0x1E8,
            bitSize      =  4,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TST_RSV0",
            description  = "",
            offset       =  0x1E5,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TST_RSV1",
            description  = "",
            offset       =  0x1E4,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TRANS_TIME_RATE",
            description  = "",
            offset       =  0x1E1,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "PD_TRANS_TIME_NONE_P2",
            description  = "",
            offset       =  0x1DD,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "PD_TRANS_TIME_TO_P2",
            description  = "",
            offset       =  0x1DC,
            bitSize      =  8,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "PD_TRANS_TIME_FROM_P2",
            description  = "",
            offset       =  0x1D8,
            bitSize      =  12,
            bitOffset    =  0x04,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TERM_RCAL_OVRD",
            description  = "",
            offset       =  0x1D8,
            bitSize      =  2,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFE_HF_CFG1",
            description  = "",
            offset       =  0x1D4,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TERM_RCAL_CFG",
            description  = "",
            offset       =  0x1D0,
            bitSize      =  15,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TXPH_CFG",
            description  = "",
            offset       =  0x1CC,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXCDR_LOCK_CFG2",
            description  = "",
            offset       =  0x1C8,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TXPH_MONITOR_SEL",
            description  = "",
            offset       =  0x1C4,
            bitSize      =  5,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TAPDLY_SET_TX",
            description  = "",
            offset       =  0x1C4,
            bitSize      =  2,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TXDLY_CFG",
            description  = "",
            offset       =  0x1C0,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariables(  
            name         = "TXPHDLY_CFG",
            description  = "",
            offset       =  0x1B8,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
            number       =  2,
            stride       =  4,
        )

        self.addVariable(   
            name         = "RX_CLK25_DIV",
            description  = "",
            offset       =  0x1B4,
            bitSize      =  5,
            bitOffset    =  0x03,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "SATA_MAX_INIT",
            description  = "",
            offset       =  0x1B1,
            bitSize      =  6,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "SATA_MAX_WAKE",
            description  = "",
            offset       =  0x1B0,
            bitSize      =  6,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "SATA_MAX_BURST",
            description  = "",
            offset       =  0x1AD,
            bitSize      =  6,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "SAS_MAX_COM",
            description  = "",
            offset       =  0x1AC,
            bitSize      =  6,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "SATA_MIN_INIT",
            description  = "",
            offset       =  0x1A9,
            bitSize      =  6,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "SATA_MIN_WAKE",
            description  = "",
            offset       =  0x1A8,
            bitSize      =  6,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "SATA_MIN_BURST",
            description  = "",
            offset       =  0x1A5,
            bitSize      =  6,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "SAS_MIN_COM",
            description  = "",
            offset       =  0x1A4,
            bitSize      =  6,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "SATA_BURST_VAL",
            description  = "",
            offset       =  0x1A1,
            bitSize      =  3,
            bitOffset    =  0x05,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "SATA_BURST_SEQ_LEN",
            description  = "",
            offset       =  0x1A0,
            bitSize      =  4,
            bitOffset    =  0x04,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "SATA_EIDLE_VAL",
            description  = "",
            offset       =  0x1A0,
            bitSize      =  2,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXBUF_EIDLE_HI_CNT",
            description  = "",
            offset       =  0x19D,
            bitSize      =  4,
            bitOffset    =  0x04,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXCDR_HOLD_DURING_EIDLE",
            description  = "",
            offset       =  0x19D,
            bitSize      =  1,
            bitOffset    =  0x03,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_DFE_LPM_HOLD_DURING_EIDLE",
            description  = "",
            offset       =  0x19D,
            bitSize      =  1,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXBUF_EIDLE_LO_CNT",
            description  = "",
            offset       =  0x19C,
            bitSize      =  4,
            bitOffset    =  0x04,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXBUF_RESET_ON_EIDLE",
            description  = "",
            offset       =  0x19C,
            bitSize      =  1,
            bitOffset    =  0x03,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXCDR_FR_RESET_ON_EIDLE",
            description  = "",
            offset       =  0x19C,
            bitSize      =  1,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXCDR_PH_RESET_ON_EIDLE",
            description  = "",
            offset       =  0x19C,
            bitSize      =  1,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXBUF_THRESH_OVRD",
            description  = "",
            offset       =  0x199,
            bitSize      =  1,
            bitOffset    =  0x07,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXBUF_RESET_ON_COMMAALIGN",
            description  = "",
            offset       =  0x199,
            bitSize      =  1,
            bitOffset    =  0x06,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXBUF_RESET_ON_RATE_CHANGE",
            description  = "",
            offset       =  0x199,
            bitSize      =  1,
            bitOffset    =  0x05,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXBUF_RESET_ON_CB_CHANGE",
            description  = "",
            offset       =  0x199,
            bitSize      =  1,
            bitOffset    =  0x04,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXBUF_THRESH_UNDFLW",
            description  = "",
            offset       =  0x198,
            bitSize      =  6,
            bitOffset    =  0x06,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_CLKMUX_EN",
            description  = "",
            offset       =  0x198,
            bitSize      =  1,
            bitOffset    =  0x05,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_DISPERR_SEQ_MATCH",
            description  = "",
            offset       =  0x198,
            bitSize      =  1,
            bitOffset    =  0x04,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXBUF_ADDR_MODE",
            description  = "",
            offset       =  0x198,
            bitSize      =  1,
            bitOffset    =  0x03,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_WIDEMODE_CDR",
            description  = "",
            offset       =  0x198,
            bitSize      =  1,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_INT_DATAWIDTH",
            description  = "",
            offset       =  0x198,
            bitSize      =  2,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXBUF_THRESH_OVFLW",
            description  = "",
            offset       =  0x195,
            bitSize      =  6,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "DMONITOR_CFG0",
            description  = "",
            offset       =  0x194,
            bitSize      =  10,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_SIG_VALID_DLY",
            description  = "",
            offset       =  0x191,
            bitSize      =  5,
            bitOffset    =  0x03,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXSLIDE_MODE",
            description  = "",
            offset       =  0x191,
            bitSize      =  2,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXPRBS_ERR_LOOPBACK",
            description  = "",
            offset       =  0x191,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXSLIDE_AUTO_WAIT",
            description  = "",
            offset       =  0x190,
            bitSize      =  4,
            bitOffset    =  0x04,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXBUF_EN",
            description  = "",
            offset       =  0x190,
            bitSize      =  1,
            bitOffset    =  0x03,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_XCLK_SEL",
            description  = "",
            offset       =  0x190,
            bitSize      =  2,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXGEARBOX_EN",
            description  = "",
            offset       =  0x190,
            bitSize      =  1,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "CBCC_DATA_SOURCE_SEL",
            description  = "",
            offset       =  0x18D,
            bitSize      =  1,
            bitOffset    =  0x07,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "OOB_PWRUP",
            description  = "",
            offset       =  0x18D,
            bitSize      =  1,
            bitOffset    =  0x06,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXOOB_CFG",
            description  = "",
            offset       =  0x18C,
            bitSize      =  9,
            bitOffset    =  0x05,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXOUT_DIV",
            description  = "",
            offset       =  0x18C,
            bitSize      =  3,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_SUM_DFETAPREP_EN",
            description  = "",
            offset       =  0x189,
            bitSize      =  1,
            bitOffset    =  0x06,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_SUM_VCM_OVWR",
            description  = "",
            offset       =  0x189,
            bitSize      =  1,
            bitOffset    =  0x05,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_SUM_IREF_TUNE",
            description  = "",
            offset       =  0x189,
            bitSize      =  4,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_SUM_RES_CTRL",
            description  = "",
            offset       =  0x188,
            bitSize      =  2,
            bitOffset    =  0x07,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_SUM_VCMTUNE",
            description  = "",
            offset       =  0x188,
            bitSize      =  4,
            bitOffset    =  0x03,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_SUM_VREF_TUNE",
            description  = "",
            offset       =  0x188,
            bitSize      =  3,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXPH_MONITOR_SEL",
            description  = "",
            offset       =  0x185,
            bitSize      =  5,
            bitOffset    =  0x03,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_CM_BUF_PD",
            description  = "",
            offset       =  0x185,
            bitSize      =  1,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_CM_BUF_CFG",
            description  = "",
            offset       =  0x184,
            bitSize      =  4,
            bitOffset    =  0x06,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_CM_TRIM",
            description  = "",
            offset       =  0x184,
            bitSize      =  4,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_CM_SEL",
            description  = "",
            offset       =  0x184,
            bitSize      =  2,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "PCS_RSVD0",
            description  = "",
            offset       =  0x180,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_BIAS_CFG0",
            description  = "",
            offset       =  0x17C,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFE_HD_CFG0",
            description  = "",
            offset       =  0x178,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFE_HF_CFG0",
            description  = "",
            offset       =  0x174,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDLY_LCFG",
            description  = "",
            offset       =  0x170,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDLY_CFG",
            description  = "",
            offset       =  0x16C,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFE_OS_CFG1",
            description  = "",
            offset       =  0x168,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXPHDLY_CFG",
            description  = "",
            offset       =  0x164,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFE_OS_CFG0",
            description  = "",
            offset       =  0x160,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "TXDLY_LCFG",
            description  = "",
            offset       =  0x15C,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "ALIGN_PCOMMA_DET",
            description  = "",
            offset       =  0x159,
            bitSize      =  1,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "ALIGN_PCOMMA_VALUE",
            description  = "",
            offset       =  0x158,
            bitSize      =  10,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "LOCAL_MASTER",
            description  = "",
            offset       =  0x155,
            bitSize      =  1,
            bitOffset    =  0x05,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "PCS_PCIE_EN",
            description  = "",
            offset       =  0x155,
            bitSize      =  1,
            bitOffset    =  0x04,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "ALIGN_MCOMMA_DET",
            description  = "",
            offset       =  0x155,
            bitSize      =  1,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "ALIGN_MCOMMA_VALUE",
            description  = "",
            offset       =  0x154,
            bitSize      =  10,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariables(  
            name         = "RXDFE_CFG",
            description  = "",
            offset       =  0x14C,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
            number       =  2,
            stride       =  4,
        )

        self.addVariable(   
            name         = "RX_EN_HI_LR",
            description  = "",
            offset       =  0x149,
            bitSize      =  1,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_DFE_AGC_CFG1",
            description  = "",
            offset       =  0x148,
            bitSize      =  3,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RX_DFE_AGC_CFG0",
            description  = "",
            offset       =  0x148,
            bitSize      =  2,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "ES_PMA_CFG",
            description  = "",
            offset       =  0x144,
            bitSize      =  10,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFE_HC_CFG1",
            description  = "",
            offset       =  0x140,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "ES_HORZ_OFFSET",
            description  = "",
            offset       =  0x13C,
            bitSize      =  12,
            bitOffset    =  0x04,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "FTS_LANE_DESKEW_CFG",
            description  = "",
            offset       =  0x13C,
            bitSize      =  1,
            bitOffset    =  0x04,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "FTS_LANE_DESKEW_EN",
            description  = "",
            offset       =  0x138,
            bitSize      =  1,
            bitOffset    =  0x04,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "FTS_DESKEW_SEQ_ENABLE",
            description  = "",
            offset       =  0x138,
            bitSize      =  4,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariables(  
            name         = "ES_SDATA_MASK",
            description  = "",
            offset       =  0x124,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
            number       =  5,
            stride       =  4,
        )

        self.addVariables(  
            name         = "ES_QUAL_MASK",
            description  = "",
            offset       =  0x110,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
            number       =  5,
            stride       =  4,
        )

        self.addVariables(  
            name         = "ES_QUALIFIER",
            description  = "",
            offset       =  0xFC,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
            number       =  5,
            stride       =  4,
        )

        self.addVariable(   
            name         = "TX_PROGDIV_CFG",
            description  = "",
            offset       =  0xF8,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "RXDFE_HC_CFG0",
            description  = "",
            offset       =  0xF4,
            bitSize      =  16,
            bitOffset    =  0x00,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "ES_CONTROL",
            description  = "",
            offset       =  0xF1,
            bitSize      =  6,
            bitOffset    =  0x02,
            base         = "hex",
            mode         = "RW",
        )

        self.addVariable(   
            name         = "ES_ERRDET_EN",
            description  = "",
            offset       =  0xF1,
            bitSize      =  1,
            bitOffset    =  0x01,
            base         = "hex",
            mode         = "RW",
        )

