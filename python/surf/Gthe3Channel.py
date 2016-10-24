#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Device Gthe3Channel
#-----------------------------------------------------------------------------
# File       : Gthe3Channel.py
# Author     : Ryan Herbst, rherbst@slac.stanford.edu
# Created    : 2016-10-24
# Last update: 2016-10-24
#-----------------------------------------------------------------------------
# Description:
# Device creator for Gthe3Channel
# Auto created from ../surf/xilinx/UltraScale/gthUs/yaml/Gthe3Channel.yaml
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
                         hidden=hidden,size=0x400,
                         description='Gthe3Channel')

    dev.add(pyrogue.Variable(name='CDR_SWAP_MODE_EN',
                             description='',
                             hidden=False, enum=None, offset=0x8, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXCDRFREQRESET_TIME',
                             description='',
                             hidden=False, enum=None, offset=0xc, bitSize=5, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_DATA_WIDTH',
                             description='',
                             hidden=False, enum=None, offset=0xc, bitSize=4, bitOffset=5, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='EYE_SCAN_SWAP_EN',
                             description='',
                             hidden=False, enum=None, offset=0x3, bitSize=1, bitOffset=25, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXBUFRESET_TIME',
                             description='',
                             hidden=False, enum=None, offset=0x3, bitSize=5, bitOffset=27, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_FABINT_USRCLK_FLOP',
                             description='',
                             hidden=False, enum=None, offset=0x10, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFELPMRESET_TIME',
                             description='',
                             hidden=False, enum=None, offset=0x10, bitSize=7, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='PCI3_RX_ELECIDLE_H2L_DISABLE',
                             description='',
                             hidden=False, enum=None, offset=0x4, bitSize=3, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXCDRPHRESET_TIME',
                             description='',
                             hidden=False, enum=None, offset=0x4, bitSize=5, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXELECIDLE_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x14, bitSize=3, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXPCSRESET_TIME',
                             description='',
                             hidden=False, enum=None, offset=0x14, bitSize=5, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='PCI3_RX_FIFO_DISABLE',
                             description='',
                             hidden=False, enum=None, offset=0x5, bitSize=1, bitOffset=8, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='PCI3_RX_ELECIDLE_EI2_ENABLE',
                             description='',
                             hidden=False, enum=None, offset=0x5, bitSize=1, bitOffset=9, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='PCI3_RX_ELECIDLE_LP4_DISABLE',
                             description='',
                             hidden=False, enum=None, offset=0x5, bitSize=1, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXPMARESET_TIME',
                             description='',
                             hidden=False, enum=None, offset=0x5, bitSize=5, bitOffset=11, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_HB_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x18, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TXPCSRESET_TIME',
                             description='',
                             hidden=False, enum=None, offset=0x24, bitSize=5, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_PMA_POWER_SAVE',
                             description='',
                             hidden=False, enum=None, offset=0x9, bitSize=1, bitOffset=9, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_PMA_POWER_SAVE',
                             description='',
                             hidden=False, enum=None, offset=0x9, bitSize=1, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TXPMARESET_TIME',
                             description='',
                             hidden=False, enum=None, offset=0x9, bitSize=5, bitOffset=11, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_FABINT_USRCLK_FLOP',
                             description='',
                             hidden=False, enum=None, offset=0x2c, bitSize=1, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXPMACLK_SEL',
                             description='',
                             hidden=False, enum=None, offset=0xa, bitSize=2, bitOffset=16, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='WB_MODE',
                             description='',
                             hidden=False, enum=None, offset=0xa, bitSize=2, bitOffset=22, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXISCANRESET_TIME',
                             description='',
                             hidden=False, enum=None, offset=0x30, bitSize=5, bitOffset=5, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_PROGCLK_SEL',
                             description='',
                             hidden=False, enum=None, offset=0xc, bitSize=2, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXCDR_CFG_0',
                             description='',
                             hidden=False, enum=None, offset=0x38, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXCDR_CFG_1',
                             description='',
                             hidden=False, enum=None, offset=0x3c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXCDR_CFG_2',
                             description='',
                             hidden=False, enum=None, offset=0x40, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXCDR_CFG_3',
                             description='',
                             hidden=False, enum=None, offset=0x44, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXCDR_CFG_4',
                             description='',
                             hidden=False, enum=None, offset=0x48, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXCDR_LOCK_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x4c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CHAN_BOND_SEQ_1_1',
                             description='',
                             hidden=False, enum=None, offset=0x50, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CHAN_BOND_SEQ_LEN',
                             description='',
                             hidden=False, enum=None, offset=0x14, bitSize=2, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CHAN_BOND_MAX_SKEW',
                             description='',
                             hidden=False, enum=None, offset=0x14, bitSize=4, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CHAN_BOND_SEQ_1_3',
                             description='',
                             hidden=False, enum=None, offset=0x54, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='PCI3_RX_ELECIDLE_HI_COUNT',
                             description='',
                             hidden=False, enum=None, offset=0x15, bitSize=5, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CHAN_BOND_SEQ_1_4',
                             description='',
                             hidden=False, enum=None, offset=0x58, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='PCI3_RX_ELECIDLE_H2L_COUNT',
                             description='',
                             hidden=False, enum=None, offset=0x16, bitSize=5, bitOffset=18, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='PCI3_PIPE_RX_ELECIDLE',
                             description='',
                             hidden=False, enum=None, offset=0x5c, bitSize=1, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='PCI3_AUTO_REALIGN',
                             description='',
                             hidden=False, enum=None, offset=0x5c, bitSize=2, bitOffset=5, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='OOBDIVCTL',
                             description='',
                             hidden=False, enum=None, offset=0x5c, bitSize=2, bitOffset=7, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_DEFER_RESET_BUF_EN',
                             description='',
                             hidden=False, enum=None, offset=0x17, bitSize=1, bitOffset=25, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_BUFFER_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x17, bitSize=6, bitOffset=26, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CHAN_BOND_SEQ_2_1',
                             description='',
                             hidden=False, enum=None, offset=0x60, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='PCI3_RX_ASYNC_EBUF_BYPASS',
                             description='',
                             hidden=False, enum=None, offset=0x18, bitSize=2, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CHAN_BOND_SEQ_1_ENABLE',
                             description='',
                             hidden=False, enum=None, offset=0x18, bitSize=4, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CHAN_BOND_SEQ_2_2',
                             description='',
                             hidden=False, enum=None, offset=0x64, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CHAN_BOND_SEQ_2_3',
                             description='',
                             hidden=False, enum=None, offset=0x68, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CHAN_BOND_SEQ_2_4',
                             description='',
                             hidden=False, enum=None, offset=0x6c, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CLK_COR_MIN_LAT',
                             description='',
                             hidden=False, enum=None, offset=0x70, bitSize=6, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CLK_COR_KEEP_IDLE',
                             description='',
                             hidden=False, enum=None, offset=0x70, bitSize=1, bitOffset=6, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CHAN_BOND_SEQ_2_USE',
                             description='',
                             hidden=False, enum=None, offset=0x1c, bitSize=1, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CHAN_BOND_SEQ_2_ENABLE',
                             description='',
                             hidden=False, enum=None, offset=0x1c, bitSize=4, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CHAN_BOND_KEEP_ALIGN',
                             description='',
                             hidden=False, enum=None, offset=0x74, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CLK_COR_SEQ_LEN',
                             description='',
                             hidden=False, enum=None, offset=0x74, bitSize=2, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CLK_COR_REPEAT_WAIT',
                             description='',
                             hidden=False, enum=None, offset=0x74, bitSize=5, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CLK_COR_PRECEDENCE',
                             description='',
                             hidden=False, enum=None, offset=0x1d, bitSize=1, bitOffset=9, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CLK_COR_MAX_LAT',
                             description='',
                             hidden=False, enum=None, offset=0x1d, bitSize=6, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CLK_COR_SEQ_1_1',
                             description='',
                             hidden=False, enum=None, offset=0x78, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CLK_COR_SEQ_1_2',
                             description='',
                             hidden=False, enum=None, offset=0x7c, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CLK_COR_SEQ_1_3',
                             description='',
                             hidden=False, enum=None, offset=0x80, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CLK_COR_SEQ_1_4',
                             description='',
                             hidden=False, enum=None, offset=0x84, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CLK_COR_SEQ_2_1',
                             description='',
                             hidden=False, enum=None, offset=0x88, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CLK_COR_SEQ_1_ENABLE',
                             description='',
                             hidden=False, enum=None, offset=0x22, bitSize=4, bitOffset=20, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CLK_COR_SEQ_2_2',
                             description='',
                             hidden=False, enum=None, offset=0x8c, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CLK_COR_SEQ_2_3',
                             description='',
                             hidden=False, enum=None, offset=0x90, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CLK_CORRECT_USE',
                             description='',
                             hidden=False, enum=None, offset=0x24, bitSize=1, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CLK_COR_SEQ_2_USE',
                             description='',
                             hidden=False, enum=None, offset=0x24, bitSize=1, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CLK_COR_SEQ_2_ENABLE',
                             description='',
                             hidden=False, enum=None, offset=0x24, bitSize=4, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CLK_COR_SEQ_2_4',
                             description='',
                             hidden=False, enum=None, offset=0x94, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_HE_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x98, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ALIGN_COMMA_ENABLE',
                             description='',
                             hidden=False, enum=None, offset=0x9c, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='SHOW_REALIGN_COMMA',
                             description='',
                             hidden=False, enum=None, offset=0x27, bitSize=1, bitOffset=27, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ALIGN_COMMA_DOUBLE',
                             description='',
                             hidden=False, enum=None, offset=0x27, bitSize=1, bitOffset=28, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ALIGN_COMMA_WORD',
                             description='',
                             hidden=False, enum=None, offset=0x27, bitSize=3, bitOffset=29, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TXDRVBIAS_N',
                             description='',
                             hidden=False, enum=None, offset=0xa0, bitSize=4, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CPLL_FBDIV_45',
                             description='',
                             hidden=False, enum=None, offset=0xa0, bitSize=1, bitOffset=7, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CPLL_FBDIV',
                             description='',
                             hidden=False, enum=None, offset=0x28, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CPLL_LOCK_CFG',
                             description='',
                             hidden=False, enum=None, offset=0xa4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TXDRVBIAS_P',
                             description='',
                             hidden=False, enum=None, offset=0xa8, bitSize=4, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='SATA_CPLL_CFG',
                             description='',
                             hidden=False, enum=None, offset=0xa8, bitSize=2, bitOffset=5, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CPLL_REFCLK_DIV',
                             description='',
                             hidden=False, enum=None, offset=0x2a, bitSize=5, bitOffset=19, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CPLL_INIT_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0xac, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='A_RXPROGDIVRESET',
                             description='',
                             hidden=False, enum=None, offset=0xb0, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='A_TXPROGDIVRESET',
                             description='',
                             hidden=False, enum=None, offset=0xb0, bitSize=1, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_DIVRESET_TIME',
                             description='',
                             hidden=False, enum=None, offset=0xb0, bitSize=5, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_DIVRESET_TIME',
                             description='',
                             hidden=False, enum=None, offset=0xb0, bitSize=5, bitOffset=7, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DEC_PCOMMA_DETECT',
                             description='',
                             hidden=False, enum=None, offset=0x2c, bitSize=1, bitOffset=7, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXCDR_LOCK_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0xb4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXCFOK_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0xb8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_H2_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0xbc, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_H2_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0xc0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXCFOK_CFG2',
                             description='',
                             hidden=False, enum=None, offset=0xc4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXLPM_CFG',
                             description='',
                             hidden=False, enum=None, offset=0xc8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXLPM_KH_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0xcc, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXLPM_KH_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0xd0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFELPM_KL_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0xd4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFELPM_KL_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0xd8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXLPM_OS_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0xdc, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXLPM_OS_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0xe0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXLPM_GC_CFG',
                             description='',
                             hidden=False, enum=None, offset=0xe4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DMONITOR_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x3a, bitSize=8, bitOffset=16, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ES_PRESCALE',
                             description='',
                             hidden=False, enum=None, offset=0xf0, bitSize=5, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ES_EYE_SCAN_EN',
                             description='',
                             hidden=False, enum=None, offset=0x3c, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_HB_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x33c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_HA_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x338, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CPLL_INIT_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0xcd, bitSize=8, bitOffset=8, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_DDI_SEL',
                             description='',
                             hidden=False, enum=None, offset=0x334, bitSize=6, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DEC_VALID_COMMA_ONLY',
                             description='',
                             hidden=False, enum=None, offset=0x334, bitSize=1, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DEC_MCOMMA_DETECT',
                             description='',
                             hidden=False, enum=None, offset=0x334, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CPLL_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x330, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CPLL_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x32c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CHAN_BOND_SEQ_1_2',
                             description='',
                             hidden=False, enum=None, offset=0x328, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_HA_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x320, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_H9_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x31c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_PROGDIV_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x318, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_H9_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x314, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='PCIE_RXPCS_CFG_GEN3',
                             description='',
                             hidden=False, enum=None, offset=0x310, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='PCIE_BUFG_DIV_CTRL',
                             description='',
                             hidden=False, enum=None, offset=0x30c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_H8_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x308, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_H8_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x304, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_H7_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x300, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXPHBEACON_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x2fc, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXPHSLIP_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x2f8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXPHSAMP_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x2f4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CPLL_CFG2',
                             description='',
                             hidden=False, enum=None, offset=0x2f0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TXGBOX_FIFO_INIT_RD_ADDR',
                             description='',
                             hidden=False, enum=None, offset=0xbb, bitSize=3, bitOffset=25, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_SAMPLE_PERIOD',
                             description='',
                             hidden=False, enum=None, offset=0x2ec, bitSize=3, bitOffset=6, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXGBOX_FIFO_INIT_RD_ADDR',
                             description='',
                             hidden=False, enum=None, offset=0x2ec, bitSize=3, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_SAMPLE_PERIOD',
                             description='',
                             hidden=False, enum=None, offset=0x2ec, bitSize=3, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DDI_REALIGN_WAIT',
                             description='',
                             hidden=False, enum=None, offset=0x2e8, bitSize=5, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DDI_CTRL',
                             description='',
                             hidden=False, enum=None, offset=0x2e8, bitSize=2, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_H7_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x2e4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_H6_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x2e0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_H6_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x2dc, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_DCD_CFG',
                             description='',
                             hidden=False, enum=None, offset=0xb6, bitSize=6, bitOffset=18, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_DCD_EN',
                             description='',
                             hidden=False, enum=None, offset=0xb6, bitSize=1, bitOffset=17, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_EML_PHI_TUNE',
                             description='',
                             hidden=False, enum=None, offset=0xb6, bitSize=1, bitOffset=16, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CPLL_CFG3',
                             description='',
                             hidden=False, enum=None, offset=0x2d8, bitSize=6, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_H5_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x2d4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='PROCESS_PAR',
                             description='',
                             hidden=False, enum=None, offset=0xb4, bitSize=3, bitOffset=5, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TEMPERATUR_PAR',
                             description='',
                             hidden=False, enum=None, offset=0xb4, bitSize=4, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_MODE_SEL',
                             description='',
                             hidden=False, enum=None, offset=0x2d0, bitSize=3, bitOffset=5, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_SARC_LPBK_ENB',
                             description='',
                             hidden=False, enum=None, offset=0x2d0, bitSize=1, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_H5_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x2cc, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_H4_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x2c8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_H4_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x2c4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_H3_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x2c0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DFE_D_X_REL_POS',
                             description='',
                             hidden=False, enum=None, offset=0xaf, bitSize=1, bitOffset=30, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DFE_VCM_COMP_EN',
                             description='',
                             hidden=False, enum=None, offset=0xaf, bitSize=1, bitOffset=30, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='GM_BIAS_SELECT',
                             description='',
                             hidden=False, enum=None, offset=0xaf, bitSize=1, bitOffset=29, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='EVODD_PHI_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x2bc, bitSize=11, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_H3_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x2b8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='PLL_SEL_MODE_GEN3',
                             description='',
                             hidden=False, enum=None, offset=0xad, bitSize=2, bitOffset=11, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='PLL_SEL_MODE_GEN12',
                             description='',
                             hidden=False, enum=None, offset=0xad, bitSize=2, bitOffset=9, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RATE_SW_USE_DRP',
                             description='',
                             hidden=False, enum=None, offset=0xad, bitSize=1, bitOffset=8, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXPI_LPM',
                             description='',
                             hidden=False, enum=None, offset=0x2b4, bitSize=1, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXPI_VREFSEL',
                             description='',
                             hidden=False, enum=None, offset=0x2b4, bitSize=1, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_CLK_SLIP_OVRD',
                             description='',
                             hidden=False, enum=None, offset=0x2b0, bitSize=5, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='PCS_RSVD1',
                             description='',
                             hidden=False, enum=None, offset=0x2b0, bitSize=3, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='PCIE_TXPMA_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x2ac, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='PCIE_TXPCS_CFG_GEN3',
                             description='',
                             hidden=False, enum=None, offset=0x2a8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='PCIE_RXPMA_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x2a4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXCDR_CFG5',
                             description='',
                             hidden=False, enum=None, offset=0x2a0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXCDR_CFG5_GEN3',
                             description='',
                             hidden=False, enum=None, offset=0x29c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXCDR_CFG4_GEN3',
                             description='',
                             hidden=False, enum=None, offset=0x298, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXCDR_CFG3_GEN3',
                             description='',
                             hidden=False, enum=None, offset=0x294, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXCDR_CFG2_GEN3',
                             description='',
                             hidden=False, enum=None, offset=0x290, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXCDR_CFG1_GEN3',
                             description='',
                             hidden=False, enum=None, offset=0x28c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXCDR_CFG0_GEN3',
                             description='',
                             hidden=False, enum=None, offset=0x288, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_GC_CFG2',
                             description='',
                             hidden=False, enum=None, offset=0x284, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_GC_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x280, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_GC_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x27c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_UT_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x278, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXPI_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x9d, bitSize=2, bitOffset=14, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXPI_CFG2',
                             description='',
                             hidden=False, enum=None, offset=0x9d, bitSize=2, bitOffset=12, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXPI_CFG3',
                             description='',
                             hidden=False, enum=None, offset=0x9d, bitSize=2, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXPI_CFG4',
                             description='',
                             hidden=False, enum=None, offset=0x9d, bitSize=1, bitOffset=9, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXPI_CFG5',
                             description='',
                             hidden=False, enum=None, offset=0x9d, bitSize=1, bitOffset=8, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXPI_CFG6',
                             description='',
                             hidden=False, enum=None, offset=0x274, bitSize=3, bitOffset=5, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXPI_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x274, bitSize=2, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TXPI_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x9c, bitSize=2, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TXPI_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x9c, bitSize=2, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TXPI_CFG2',
                             description='',
                             hidden=False, enum=None, offset=0x270, bitSize=2, bitOffset=7, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TXPI_CFG3',
                             description='',
                             hidden=False, enum=None, offset=0x270, bitSize=1, bitOffset=6, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TXPI_CFG4',
                             description='',
                             hidden=False, enum=None, offset=0x270, bitSize=1, bitOffset=5, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TXPI_CFG5',
                             description='',
                             hidden=False, enum=None, offset=0x270, bitSize=3, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_DFELPM_KLKH_AGC_STUP_EN',
                             description='',
                             hidden=False, enum=None, offset=0x9b, bitSize=1, bitOffset=31, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_DFELPM_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x9b, bitSize=4, bitOffset=27, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_DFELPM_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x9b, bitSize=1, bitOffset=26, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_DFE_KL_LPM_KH_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x9b, bitSize=2, bitOffset=24, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_DFE_KL_LPM_KH_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x26c, bitSize=3, bitOffset=5, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TXPI_PPM_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x268, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='GEARBOX_MODE',
                             description='',
                             hidden=False, enum=None, offset=0x99, bitSize=5, bitOffset=11, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TXPI_SYNFREQ_PPM',
                             description='',
                             hidden=False, enum=None, offset=0x99, bitSize=3, bitOffset=8, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TXPI_PPMCLK_SEL',
                             description='',
                             hidden=False, enum=None, offset=0x264, bitSize=1, bitOffset=7, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TXPI_INVSTROBE_SEL',
                             description='',
                             hidden=False, enum=None, offset=0x264, bitSize=1, bitOffset=6, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TXPI_GRAY_SEL',
                             description='',
                             hidden=False, enum=None, offset=0x264, bitSize=1, bitOffset=5, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TXPI_LPM',
                             description='',
                             hidden=False, enum=None, offset=0x264, bitSize=1, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TXPI_VREFSEL',
                             description='',
                             hidden=False, enum=None, offset=0x264, bitSize=1, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_HE_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x260, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_AFE_CM_EN',
                             description='',
                             hidden=False, enum=None, offset=0x97, bitSize=1, bitOffset=26, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_CAPFF_SARC_ENB',
                             description='',
                             hidden=False, enum=None, offset=0x97, bitSize=1, bitOffset=27, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_EYESCAN_VS_NEG_DIR',
                             description='',
                             hidden=False, enum=None, offset=0x97, bitSize=1, bitOffset=26, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_EYESCAN_VS_UT_SIGN',
                             description='',
                             hidden=False, enum=None, offset=0x97, bitSize=1, bitOffset=25, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_EYESCAN_VS_CODE',
                             description='',
                             hidden=False, enum=None, offset=0x25c, bitSize=7, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_EYESCAN_VS_RANGE',
                             description='',
                             hidden=False, enum=None, offset=0x25c, bitSize=2, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='PMA_RSV1',
                             description='',
                             hidden=False, enum=None, offset=0x254, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ES_CLK_PHASE_SEL',
                             description='',
                             hidden=False, enum=None, offset=0x94, bitSize=1, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='USE_PCS_CLK_PHASE_SEL',
                             description='',
                             hidden=False, enum=None, offset=0x94, bitSize=1, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXCFOK_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x24c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ADAPT_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x248, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ADAPT_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x244, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_UT_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x240, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_VP_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x23c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_VP_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x238, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFELPM_KL_CFG2',
                             description='',
                             hidden=False, enum=None, offset=0x234, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ACJTAG_MODE',
                             description='',
                             hidden=False, enum=None, offset=0x8c, bitSize=1, bitOffset=7, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ACJTAG_DEBUG_MODE',
                             description='',
                             hidden=False, enum=None, offset=0x8c, bitSize=1, bitOffset=6, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ACJTAG_RESET',
                             description='',
                             hidden=False, enum=None, offset=0x8c, bitSize=1, bitOffset=5, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RESET_POWERSAVE_DISABLE',
                             description='',
                             hidden=False, enum=None, offset=0x8c, bitSize=1, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_TUNE_AFE_OS',
                             description='',
                             hidden=False, enum=None, offset=0x8c, bitSize=2, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_DFE_KL_LPM_KL_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x8c, bitSize=2, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_DFE_KL_LPM_KL_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x230, bitSize=3, bitOffset=5, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TXSYNC_MULTILANE',
                             description='',
                             hidden=False, enum=None, offset=0x8b, bitSize=1, bitOffset=26, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXSYNC_MULTILANE',
                             description='',
                             hidden=False, enum=None, offset=0x8b, bitSize=1, bitOffset=25, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_CTLE3_LPF',
                             description='',
                             hidden=False, enum=None, offset=0x22c, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_PMADATA_OPT',
                             description='',
                             hidden=False, enum=None, offset=0x8a, bitSize=1, bitOffset=23, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXSYNC_OVRD',
                             description='',
                             hidden=False, enum=None, offset=0x8a, bitSize=1, bitOffset=22, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TXSYNC_OVRD',
                             description='',
                             hidden=False, enum=None, offset=0x8a, bitSize=1, bitOffset=21, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_IDLE_DATA_ZERO',
                             description='',
                             hidden=False, enum=None, offset=0x8a, bitSize=1, bitOffset=20, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='A_RXOSCALRESET',
                             description='',
                             hidden=False, enum=None, offset=0x8a, bitSize=1, bitOffset=19, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXOOB_CLK_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x8a, bitSize=1, bitOffset=18, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TXSYNC_SKIP_DA',
                             description='',
                             hidden=False, enum=None, offset=0x8a, bitSize=1, bitOffset=17, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXSYNC_SKIP_DA',
                             description='',
                             hidden=False, enum=None, offset=0x8a, bitSize=1, bitOffset=16, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXOSCALRESET_TIME',
                             description='',
                             hidden=False, enum=None, offset=0x228, bitSize=5, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXPRBS_LINKACQ_CNT',
                             description='',
                             hidden=False, enum=None, offset=0x224, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_QPI_STATUS_EN',
                             description='',
                             hidden=False, enum=None, offset=0x85, bitSize=1, bitOffset=13, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_INT_DATAWIDTH',
                             description='',
                             hidden=False, enum=None, offset=0x85, bitSize=2, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_HD_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x210, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_MARGIN_LOW_3',
                             description='',
                             hidden=False, enum=None, offset=0x83, bitSize=7, bitOffset=25, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_MARGIN_LOW_4',
                             description='',
                             hidden=False, enum=None, offset=0x20c, bitSize=7, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_MARGIN_LOW_1',
                             description='',
                             hidden=False, enum=None, offset=0x82, bitSize=7, bitOffset=17, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_MARGIN_LOW_2',
                             description='',
                             hidden=False, enum=None, offset=0x208, bitSize=7, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_MARGIN_FULL_4',
                             description='',
                             hidden=False, enum=None, offset=0x81, bitSize=7, bitOffset=9, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_MARGIN_LOW_0',
                             description='',
                             hidden=False, enum=None, offset=0x204, bitSize=7, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_MARGIN_FULL_2',
                             description='',
                             hidden=False, enum=None, offset=0x80, bitSize=7, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_MARGIN_FULL_3',
                             description='',
                             hidden=False, enum=None, offset=0x200, bitSize=7, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_MARGIN_FULL_0',
                             description='',
                             hidden=False, enum=None, offset=0x7f, bitSize=7, bitOffset=25, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_MARGIN_FULL_1',
                             description='',
                             hidden=False, enum=None, offset=0x1fc, bitSize=7, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_CLKMUX_EN',
                             description='',
                             hidden=False, enum=None, offset=0x7e, bitSize=1, bitOffset=23, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_LOOPBACK_DRIVE_HIZ',
                             description='',
                             hidden=False, enum=None, offset=0x7e, bitSize=1, bitOffset=22, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_DRIVE_MODE',
                             description='',
                             hidden=False, enum=None, offset=0x7e, bitSize=5, bitOffset=16, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_EIDLE_ASSERT_DELAY',
                             description='',
                             hidden=False, enum=None, offset=0x1f8, bitSize=3, bitOffset=5, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_EIDLE_DEASSERT_DELAY',
                             description='',
                             hidden=False, enum=None, offset=0x1f8, bitSize=3, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_RXDETECT_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x1f4, bitSize=14, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_MAINCURSOR_SEL',
                             description='',
                             hidden=False, enum=None, offset=0x7c, bitSize=1, bitOffset=6, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TXGEARBOX_EN',
                             description='',
                             hidden=False, enum=None, offset=0x7c, bitSize=1, bitOffset=5, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TXOUT_DIV',
                             description='',
                             hidden=False, enum=None, offset=0x7c, bitSize=3, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TXBUF_EN',
                             description='',
                             hidden=False, enum=None, offset=0x1f0, bitSize=1, bitOffset=7, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TXBUF_RESET_ON_RATE_CHANGE',
                             description='',
                             hidden=False, enum=None, offset=0x1f0, bitSize=1, bitOffset=6, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_RXDETECT_REF',
                             description='',
                             hidden=False, enum=None, offset=0x1f0, bitSize=3, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TXFIFO_ADDR_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x1f0, bitSize=1, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_DEEMPH0',
                             description='',
                             hidden=False, enum=None, offset=0x7b, bitSize=8, bitOffset=24, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_DEEMPH1',
                             description='',
                             hidden=False, enum=None, offset=0x1ec, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_CLK25_DIV',
                             description='',
                             hidden=False, enum=None, offset=0x7a, bitSize=5, bitOffset=19, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_XCLK_SEL',
                             description='',
                             hidden=False, enum=None, offset=0x7a, bitSize=1, bitOffset=18, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_DATA_WIDTH',
                             description='',
                             hidden=False, enum=None, offset=0x1e8, bitSize=4, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TST_RSV0',
                             description='',
                             hidden=False, enum=None, offset=0x79, bitSize=8, bitOffset=8, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TST_RSV1',
                             description='',
                             hidden=False, enum=None, offset=0x1e4, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TRANS_TIME_RATE',
                             description='',
                             hidden=False, enum=None, offset=0x78, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='PD_TRANS_TIME_NONE_P2',
                             description='',
                             hidden=False, enum=None, offset=0x77, bitSize=8, bitOffset=24, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='PD_TRANS_TIME_TO_P2',
                             description='',
                             hidden=False, enum=None, offset=0x1dc, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='PD_TRANS_TIME_FROM_P2',
                             description='',
                             hidden=False, enum=None, offset=0x1d8, bitSize=12, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TERM_RCAL_OVRD',
                             description='',
                             hidden=False, enum=None, offset=0x1d8, bitSize=2, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_HF_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x1d4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TERM_RCAL_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x1d0, bitSize=15, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TXPH_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x1cc, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXCDR_LOCK_CFG2',
                             description='',
                             hidden=False, enum=None, offset=0x1c8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TXPH_MONITOR_SEL',
                             description='',
                             hidden=False, enum=None, offset=0x1c4, bitSize=5, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TAPDLY_SET_TX',
                             description='',
                             hidden=False, enum=None, offset=0x1c4, bitSize=2, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TXDLY_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x1c0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TXPHDLY_CFG_0',
                             description='',
                             hidden=False, enum=None, offset=0x1b8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TXPHDLY_CFG_1',
                             description='',
                             hidden=False, enum=None, offset=0x1bc, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_CLK25_DIV',
                             description='',
                             hidden=False, enum=None, offset=0x1b4, bitSize=5, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='SATA_MAX_INIT',
                             description='',
                             hidden=False, enum=None, offset=0x6c, bitSize=6, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='SATA_MAX_WAKE',
                             description='',
                             hidden=False, enum=None, offset=0x1b0, bitSize=6, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='SATA_MAX_BURST',
                             description='',
                             hidden=False, enum=None, offset=0x6b, bitSize=6, bitOffset=26, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='SAS_MAX_COM',
                             description='',
                             hidden=False, enum=None, offset=0x1ac, bitSize=6, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='SATA_MIN_INIT',
                             description='',
                             hidden=False, enum=None, offset=0x6a, bitSize=6, bitOffset=18, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='SATA_MIN_WAKE',
                             description='',
                             hidden=False, enum=None, offset=0x1a8, bitSize=6, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='SATA_MIN_BURST',
                             description='',
                             hidden=False, enum=None, offset=0x69, bitSize=6, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='SAS_MIN_COM',
                             description='',
                             hidden=False, enum=None, offset=0x1a4, bitSize=6, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='SATA_BURST_VAL',
                             description='',
                             hidden=False, enum=None, offset=0x68, bitSize=3, bitOffset=5, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='SATA_BURST_SEQ_LEN',
                             description='',
                             hidden=False, enum=None, offset=0x1a0, bitSize=4, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='SATA_EIDLE_VAL',
                             description='',
                             hidden=False, enum=None, offset=0x1a0, bitSize=2, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXBUF_EIDLE_HI_CNT',
                             description='',
                             hidden=False, enum=None, offset=0x67, bitSize=4, bitOffset=28, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXCDR_HOLD_DURING_EIDLE',
                             description='',
                             hidden=False, enum=None, offset=0x67, bitSize=1, bitOffset=27, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_DFE_LPM_HOLD_DURING_EIDLE',
                             description='',
                             hidden=False, enum=None, offset=0x67, bitSize=1, bitOffset=26, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXBUF_EIDLE_LO_CNT',
                             description='',
                             hidden=False, enum=None, offset=0x19c, bitSize=4, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXBUF_RESET_ON_EIDLE',
                             description='',
                             hidden=False, enum=None, offset=0x19c, bitSize=1, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXCDR_FR_RESET_ON_EIDLE',
                             description='',
                             hidden=False, enum=None, offset=0x19c, bitSize=1, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXCDR_PH_RESET_ON_EIDLE',
                             description='',
                             hidden=False, enum=None, offset=0x19c, bitSize=1, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXBUF_THRESH_OVRD',
                             description='',
                             hidden=False, enum=None, offset=0x66, bitSize=1, bitOffset=23, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXBUF_RESET_ON_COMMAALIGN',
                             description='',
                             hidden=False, enum=None, offset=0x66, bitSize=1, bitOffset=22, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXBUF_RESET_ON_RATE_CHANGE',
                             description='',
                             hidden=False, enum=None, offset=0x66, bitSize=1, bitOffset=21, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXBUF_RESET_ON_CB_CHANGE',
                             description='',
                             hidden=False, enum=None, offset=0x66, bitSize=1, bitOffset=20, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXBUF_THRESH_UNDFLW',
                             description='',
                             hidden=False, enum=None, offset=0x198, bitSize=6, bitOffset=6, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_CLKMUX_EN',
                             description='',
                             hidden=False, enum=None, offset=0x198, bitSize=1, bitOffset=5, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_DISPERR_SEQ_MATCH',
                             description='',
                             hidden=False, enum=None, offset=0x198, bitSize=1, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXBUF_ADDR_MODE',
                             description='',
                             hidden=False, enum=None, offset=0x198, bitSize=1, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_WIDEMODE_CDR',
                             description='',
                             hidden=False, enum=None, offset=0x198, bitSize=1, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_INT_DATAWIDTH',
                             description='',
                             hidden=False, enum=None, offset=0x198, bitSize=2, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXBUF_THRESH_OVFLW',
                             description='',
                             hidden=False, enum=None, offset=0x65, bitSize=6, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='DMONITOR_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x194, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_SIG_VALID_DLY',
                             description='',
                             hidden=False, enum=None, offset=0x64, bitSize=5, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXSLIDE_MODE',
                             description='',
                             hidden=False, enum=None, offset=0x64, bitSize=2, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXPRBS_ERR_LOOPBACK',
                             description='',
                             hidden=False, enum=None, offset=0x64, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXSLIDE_AUTO_WAIT',
                             description='',
                             hidden=False, enum=None, offset=0x190, bitSize=4, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXBUF_EN',
                             description='',
                             hidden=False, enum=None, offset=0x190, bitSize=1, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_XCLK_SEL',
                             description='',
                             hidden=False, enum=None, offset=0x190, bitSize=2, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXGEARBOX_EN',
                             description='',
                             hidden=False, enum=None, offset=0x190, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='CBCC_DATA_SOURCE_SEL',
                             description='',
                             hidden=False, enum=None, offset=0x63, bitSize=1, bitOffset=31, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='OOB_PWRUP',
                             description='',
                             hidden=False, enum=None, offset=0x63, bitSize=1, bitOffset=30, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXOOB_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x18c, bitSize=9, bitOffset=5, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXOUT_DIV',
                             description='',
                             hidden=False, enum=None, offset=0x18c, bitSize=3, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_SUM_DFETAPREP_EN',
                             description='',
                             hidden=False, enum=None, offset=0x62, bitSize=1, bitOffset=22, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_SUM_VCM_OVWR',
                             description='',
                             hidden=False, enum=None, offset=0x62, bitSize=1, bitOffset=21, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_SUM_IREF_TUNE',
                             description='',
                             hidden=False, enum=None, offset=0x62, bitSize=4, bitOffset=17, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_SUM_RES_CTRL',
                             description='',
                             hidden=False, enum=None, offset=0x188, bitSize=2, bitOffset=7, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_SUM_VCMTUNE',
                             description='',
                             hidden=False, enum=None, offset=0x188, bitSize=4, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_SUM_VREF_TUNE',
                             description='',
                             hidden=False, enum=None, offset=0x188, bitSize=3, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXPH_MONITOR_SEL',
                             description='',
                             hidden=False, enum=None, offset=0x61, bitSize=5, bitOffset=11, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_CM_BUF_PD',
                             description='',
                             hidden=False, enum=None, offset=0x61, bitSize=1, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_CM_BUF_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x184, bitSize=4, bitOffset=6, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_CM_TRIM',
                             description='',
                             hidden=False, enum=None, offset=0x184, bitSize=4, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_CM_SEL',
                             description='',
                             hidden=False, enum=None, offset=0x184, bitSize=2, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='PCS_RSVD0',
                             description='',
                             hidden=False, enum=None, offset=0x180, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_BIAS_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x17c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_HD_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x178, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_HF_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x174, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDLY_LCFG',
                             description='',
                             hidden=False, enum=None, offset=0x170, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDLY_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x16c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_OS_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x168, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXPHDLY_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x164, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_OS_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x160, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TXDLY_LCFG',
                             description='',
                             hidden=False, enum=None, offset=0x15c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ALIGN_PCOMMA_DET',
                             description='',
                             hidden=False, enum=None, offset=0x56, bitSize=1, bitOffset=18, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ALIGN_PCOMMA_VALUE',
                             description='',
                             hidden=False, enum=None, offset=0x158, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='LOCAL_MASTER',
                             description='',
                             hidden=False, enum=None, offset=0x55, bitSize=1, bitOffset=13, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='PCS_PCIE_EN',
                             description='',
                             hidden=False, enum=None, offset=0x55, bitSize=1, bitOffset=12, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ALIGN_MCOMMA_DET',
                             description='',
                             hidden=False, enum=None, offset=0x55, bitSize=1, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ALIGN_MCOMMA_VALUE',
                             description='',
                             hidden=False, enum=None, offset=0x154, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_CFG_0',
                             description='',
                             hidden=False, enum=None, offset=0x14c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_CFG_1',
                             description='',
                             hidden=False, enum=None, offset=0x150, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_EN_HI_LR',
                             description='',
                             hidden=False, enum=None, offset=0x52, bitSize=1, bitOffset=18, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_DFE_AGC_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x148, bitSize=3, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RX_DFE_AGC_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x148, bitSize=2, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ES_PMA_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x144, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_HC_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x140, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ES_HORZ_OFFSET',
                             description='',
                             hidden=False, enum=None, offset=0x13c, bitSize=12, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='FTS_LANE_DESKEW_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x13c, bitSize=1, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='FTS_LANE_DESKEW_EN',
                             description='',
                             hidden=False, enum=None, offset=0x138, bitSize=1, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='FTS_DESKEW_SEQ_ENABLE',
                             description='',
                             hidden=False, enum=None, offset=0x138, bitSize=4, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ES_SDATA_MASK_0',
                             description='',
                             hidden=False, enum=None, offset=0x124, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ES_SDATA_MASK_1',
                             description='',
                             hidden=False, enum=None, offset=0x128, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ES_SDATA_MASK_2',
                             description='',
                             hidden=False, enum=None, offset=0x12c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ES_SDATA_MASK_3',
                             description='',
                             hidden=False, enum=None, offset=0x130, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ES_SDATA_MASK_4',
                             description='',
                             hidden=False, enum=None, offset=0x134, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ES_QUAL_MASK_0',
                             description='',
                             hidden=False, enum=None, offset=0x110, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ES_QUAL_MASK_1',
                             description='',
                             hidden=False, enum=None, offset=0x114, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ES_QUAL_MASK_2',
                             description='',
                             hidden=False, enum=None, offset=0x118, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ES_QUAL_MASK_3',
                             description='',
                             hidden=False, enum=None, offset=0x11c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ES_QUAL_MASK_4',
                             description='',
                             hidden=False, enum=None, offset=0x120, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ES_QUALIFIER_0',
                             description='',
                             hidden=False, enum=None, offset=0xfc, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ES_QUALIFIER_1',
                             description='',
                             hidden=False, enum=None, offset=0x100, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ES_QUALIFIER_2',
                             description='',
                             hidden=False, enum=None, offset=0x104, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ES_QUALIFIER_3',
                             description='',
                             hidden=False, enum=None, offset=0x108, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ES_QUALIFIER_4',
                             description='',
                             hidden=False, enum=None, offset=0x10c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='TX_PROGDIV_CFG',
                             description='',
                             hidden=False, enum=None, offset=0xf8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='RXDFE_HC_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0xf4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ES_CONTROL',
                             description='',
                             hidden=False, enum=None, offset=0x3c, bitSize=6, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='ES_ERRDET_EN',
                             description='',
                             hidden=False, enum=None, offset=0x3c, bitSize=1, bitOffset=1, base='uint', mode='RW'))

