#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue Device Gthe3Channel
#-----------------------------------------------------------------------------
# File       : Gthe3Channel.py
# Created    : 2016-12-01
# Last update: 2016-12-01
#-----------------------------------------------------------------------------
# Description:
# Device creator for Gthe3Channel
# Auto created from ../surf/xilinx/UltraScale/gthUs/yaml/Gthe3Channel.yaml
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

def create(name='gthe3Channel', offset=0, memBase=None, hidden=False):

    dev = pyrogue.Device(name=name,memBase=memBase,offset=offset,
                         hidden=hidden,size=0x400,
                         description='Gthe3Channel')

    dev.add(pyrogue.Variable(name='cDR_SWAP_MODE_EN',
                             description='',
                             hidden=False, enum=None, offset=0x8, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXCDRFREQRESET_TIME',
                             description='',
                             hidden=False, enum=None, offset=0xc, bitSize=5, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_DATA_WIDTH',
                             description='',
                             hidden=False, enum=None, offset=0xc, bitSize=4, bitOffset=5, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='eYE_SCAN_SWAP_EN',
                             description='',
                             hidden=False, enum=None, offset=0xc, bitSize=1, bitOffset=9, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXBUFRESET_TIME',
                             description='',
                             hidden=False, enum=None, offset=0xc, bitSize=5, bitOffset=11, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_FABINT_USRCLK_FLOP',
                             description='',
                             hidden=False, enum=None, offset=0x10, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFELPMRESET_TIME',
                             description='',
                             hidden=False, enum=None, offset=0x10, bitSize=7, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='pCI3_RX_ELECIDLE_H2L_DISABLE',
                             description='',
                             hidden=False, enum=None, offset=0x10, bitSize=3, bitOffset=8, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXCDRPHRESET_TIME',
                             description='',
                             hidden=False, enum=None, offset=0x10, bitSize=5, bitOffset=11, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXELECIDLE_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x14, bitSize=3, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXPCSRESET_TIME',
                             description='',
                             hidden=False, enum=None, offset=0x14, bitSize=5, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='pCI3_RX_FIFO_DISABLE',
                             description='',
                             hidden=False, enum=None, offset=0x14, bitSize=1, bitOffset=8, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='pCI3_RX_ELECIDLE_EI2_ENABLE',
                             description='',
                             hidden=False, enum=None, offset=0x14, bitSize=1, bitOffset=9, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='pCI3_RX_ELECIDLE_LP4_DISABLE',
                             description='',
                             hidden=False, enum=None, offset=0x14, bitSize=1, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXPMARESET_TIME',
                             description='',
                             hidden=False, enum=None, offset=0x14, bitSize=5, bitOffset=11, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_HB_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x18, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tXPCSRESET_TIME',
                             description='',
                             hidden=False, enum=None, offset=0x24, bitSize=5, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_PMA_POWER_SAVE',
                             description='',
                             hidden=False, enum=None, offset=0x24, bitSize=1, bitOffset=9, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_PMA_POWER_SAVE',
                             description='',
                             hidden=False, enum=None, offset=0x24, bitSize=1, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tXPMARESET_TIME',
                             description='',
                             hidden=False, enum=None, offset=0x24, bitSize=5, bitOffset=11, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_FABINT_USRCLK_FLOP',
                             description='',
                             hidden=False, enum=None, offset=0x2c, bitSize=1, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXPMACLK_SEL',
                             description='',
                             hidden=False, enum=None, offset=0x28, bitSize=2, bitOffset=24, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='wB_MODE',
                             description='',
                             hidden=False, enum=None, offset=0x28, bitSize=2, bitOffset=30, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXISCANRESET_TIME',
                             description='',
                             hidden=False, enum=None, offset=0x30, bitSize=5, bitOffset=5, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_PROGCLK_SEL',
                             description='',
                             hidden=False, enum=None, offset=0x30, bitSize=2, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXCDR_CFG_0',
                             description='',
                             hidden=False, enum=None, offset=0x38, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXCDR_CFG_1',
                             description='',
                             hidden=False, enum=None, offset=0x3c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXCDR_CFG_2',
                             description='',
                             hidden=False, enum=None, offset=0x40, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXCDR_CFG_3',
                             description='',
                             hidden=False, enum=None, offset=0x44, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXCDR_CFG_4',
                             description='',
                             hidden=False, enum=None, offset=0x48, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXCDR_LOCK_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x4c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cHAN_BOND_SEQ_1_1',
                             description='',
                             hidden=False, enum=None, offset=0x50, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cHAN_BOND_SEQ_LEN',
                             description='',
                             hidden=False, enum=None, offset=0x50, bitSize=2, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cHAN_BOND_MAX_SKEW',
                             description='',
                             hidden=False, enum=None, offset=0x50, bitSize=4, bitOffset=12, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cHAN_BOND_SEQ_1_3',
                             description='',
                             hidden=False, enum=None, offset=0x54, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='pCI3_RX_ELECIDLE_HI_COUNT',
                             description='',
                             hidden=False, enum=None, offset=0x54, bitSize=5, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cHAN_BOND_SEQ_1_4',
                             description='',
                             hidden=False, enum=None, offset=0x58, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='pCI3_RX_ELECIDLE_H2L_COUNT',
                             description='',
                             hidden=False, enum=None, offset=0x58, bitSize=5, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='pCI3_PIPE_RX_ELECIDLE',
                             description='',
                             hidden=False, enum=None, offset=0x5c, bitSize=1, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='pCI3_AUTO_REALIGN',
                             description='',
                             hidden=False, enum=None, offset=0x5c, bitSize=2, bitOffset=5, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='oOBDIVCTL',
                             description='',
                             hidden=False, enum=None, offset=0x5c, bitSize=2, bitOffset=7, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_DEFER_RESET_BUF_EN',
                             description='',
                             hidden=False, enum=None, offset=0x5c, bitSize=1, bitOffset=9, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_BUFFER_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x5c, bitSize=6, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cHAN_BOND_SEQ_2_1',
                             description='',
                             hidden=False, enum=None, offset=0x60, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='pCI3_RX_ASYNC_EBUF_BYPASS',
                             description='',
                             hidden=False, enum=None, offset=0x60, bitSize=2, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cHAN_BOND_SEQ_1_ENABLE',
                             description='',
                             hidden=False, enum=None, offset=0x60, bitSize=4, bitOffset=12, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cHAN_BOND_SEQ_2_2',
                             description='',
                             hidden=False, enum=None, offset=0x64, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cHAN_BOND_SEQ_2_3',
                             description='',
                             hidden=False, enum=None, offset=0x68, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cHAN_BOND_SEQ_2_4',
                             description='',
                             hidden=False, enum=None, offset=0x6c, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cLK_COR_MIN_LAT',
                             description='',
                             hidden=False, enum=None, offset=0x70, bitSize=6, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cLK_COR_KEEP_IDLE',
                             description='',
                             hidden=False, enum=None, offset=0x70, bitSize=1, bitOffset=6, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cHAN_BOND_SEQ_2_USE',
                             description='',
                             hidden=False, enum=None, offset=0x70, bitSize=1, bitOffset=11, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cHAN_BOND_SEQ_2_ENABLE',
                             description='',
                             hidden=False, enum=None, offset=0x70, bitSize=4, bitOffset=12, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cHAN_BOND_KEEP_ALIGN',
                             description='',
                             hidden=False, enum=None, offset=0x74, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cLK_COR_SEQ_LEN',
                             description='',
                             hidden=False, enum=None, offset=0x74, bitSize=2, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cLK_COR_REPEAT_WAIT',
                             description='',
                             hidden=False, enum=None, offset=0x74, bitSize=5, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cLK_COR_PRECEDENCE',
                             description='',
                             hidden=False, enum=None, offset=0x74, bitSize=1, bitOffset=9, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cLK_COR_MAX_LAT',
                             description='',
                             hidden=False, enum=None, offset=0x74, bitSize=6, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cLK_COR_SEQ_1_1',
                             description='',
                             hidden=False, enum=None, offset=0x78, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cLK_COR_SEQ_1_2',
                             description='',
                             hidden=False, enum=None, offset=0x7c, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cLK_COR_SEQ_1_3',
                             description='',
                             hidden=False, enum=None, offset=0x80, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cLK_COR_SEQ_1_4',
                             description='',
                             hidden=False, enum=None, offset=0x84, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cLK_COR_SEQ_2_1',
                             description='',
                             hidden=False, enum=None, offset=0x88, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cLK_COR_SEQ_1_ENABLE',
                             description='',
                             hidden=False, enum=None, offset=0x88, bitSize=4, bitOffset=12, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cLK_COR_SEQ_2_2',
                             description='',
                             hidden=False, enum=None, offset=0x8c, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cLK_COR_SEQ_2_3',
                             description='',
                             hidden=False, enum=None, offset=0x90, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cLK_CORRECT_USE',
                             description='',
                             hidden=False, enum=None, offset=0x90, bitSize=1, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cLK_COR_SEQ_2_USE',
                             description='',
                             hidden=False, enum=None, offset=0x90, bitSize=1, bitOffset=11, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cLK_COR_SEQ_2_ENABLE',
                             description='',
                             hidden=False, enum=None, offset=0x90, bitSize=4, bitOffset=12, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cLK_COR_SEQ_2_4',
                             description='',
                             hidden=False, enum=None, offset=0x94, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_HE_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x98, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='aLIGN_COMMA_ENABLE',
                             description='',
                             hidden=False, enum=None, offset=0x9c, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='sHOW_REALIGN_COMMA',
                             description='',
                             hidden=False, enum=None, offset=0x9c, bitSize=1, bitOffset=11, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='aLIGN_COMMA_DOUBLE',
                             description='',
                             hidden=False, enum=None, offset=0x9c, bitSize=1, bitOffset=12, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='aLIGN_COMMA_WORD',
                             description='',
                             hidden=False, enum=None, offset=0x9c, bitSize=3, bitOffset=13, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tXDRVBIAS_N',
                             description='',
                             hidden=False, enum=None, offset=0xa0, bitSize=4, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cPLL_FBDIV_45',
                             description='',
                             hidden=False, enum=None, offset=0xa0, bitSize=1, bitOffset=7, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cPLL_FBDIV',
                             description='',
                             hidden=False, enum=None, offset=0xa0, bitSize=8, bitOffset=8, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cPLL_LOCK_CFG',
                             description='',
                             hidden=False, enum=None, offset=0xa4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tXDRVBIAS_P',
                             description='',
                             hidden=False, enum=None, offset=0xa8, bitSize=4, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='sATA_CPLL_CFG',
                             description='',
                             hidden=False, enum=None, offset=0xa8, bitSize=2, bitOffset=5, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cPLL_REFCLK_DIV',
                             description='',
                             hidden=False, enum=None, offset=0xa8, bitSize=5, bitOffset=11, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cPLL_INIT_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0xac, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='a_RXPROGDIVRESET',
                             description='',
                             hidden=False, enum=None, offset=0xb0, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='a_TXPROGDIVRESET',
                             description='',
                             hidden=False, enum=None, offset=0xb0, bitSize=1, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_DIVRESET_TIME',
                             description='',
                             hidden=False, enum=None, offset=0xb0, bitSize=5, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_DIVRESET_TIME',
                             description='',
                             hidden=False, enum=None, offset=0xb0, bitSize=5, bitOffset=7, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dEC_PCOMMA_DETECT',
                             description='',
                             hidden=False, enum=None, offset=0xb0, bitSize=1, bitOffset=15, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXCDR_LOCK_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0xb4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXCFOK_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0xb8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_H2_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0xbc, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_H2_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0xc0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXCFOK_CFG2',
                             description='',
                             hidden=False, enum=None, offset=0xc4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXLPM_CFG',
                             description='',
                             hidden=False, enum=None, offset=0xc8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXLPM_KH_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0xcc, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXLPM_KH_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0xd0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFELPM_KL_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0xd4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFELPM_KL_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0xd8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXLPM_OS_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0xdc, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXLPM_OS_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0xe0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXLPM_GC_CFG',
                             description='',
                             hidden=False, enum=None, offset=0xe4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dMONITOR_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0xe8, bitSize=8, bitOffset=8, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='eS_PRESCALE',
                             description='',
                             hidden=False, enum=None, offset=0xf0, bitSize=5, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='eS_EYE_SCAN_EN',
                             description='',
                             hidden=False, enum=None, offset=0xf0, bitSize=1, bitOffset=8, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_HB_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x33c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_HA_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x338, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cPLL_INIT_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x334, bitSize=8, bitOffset=8, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_DDI_SEL',
                             description='',
                             hidden=False, enum=None, offset=0x334, bitSize=6, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dEC_VALID_COMMA_ONLY',
                             description='',
                             hidden=False, enum=None, offset=0x334, bitSize=1, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dEC_MCOMMA_DETECT',
                             description='',
                             hidden=False, enum=None, offset=0x334, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cPLL_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x330, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cPLL_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x32c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cHAN_BOND_SEQ_1_2',
                             description='',
                             hidden=False, enum=None, offset=0x328, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_HA_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x320, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_H9_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x31c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_PROGDIV_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x318, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_H9_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x314, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='pCIE_RXPCS_CFG_GEN3',
                             description='',
                             hidden=False, enum=None, offset=0x310, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='pCIE_BUFG_DIV_CTRL',
                             description='',
                             hidden=False, enum=None, offset=0x30c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_H8_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x308, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_H8_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x304, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_H7_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x300, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXPHBEACON_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x2fc, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXPHSLIP_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x2f8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXPHSAMP_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x2f4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cPLL_CFG2',
                             description='',
                             hidden=False, enum=None, offset=0x2f0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tXGBOX_FIFO_INIT_RD_ADDR',
                             description='',
                             hidden=False, enum=None, offset=0x2ec, bitSize=3, bitOffset=9, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_SAMPLE_PERIOD',
                             description='',
                             hidden=False, enum=None, offset=0x2ec, bitSize=3, bitOffset=6, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXGBOX_FIFO_INIT_RD_ADDR',
                             description='',
                             hidden=False, enum=None, offset=0x2ec, bitSize=3, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_SAMPLE_PERIOD',
                             description='',
                             hidden=False, enum=None, offset=0x2ec, bitSize=3, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dDI_REALIGN_WAIT',
                             description='',
                             hidden=False, enum=None, offset=0x2e8, bitSize=5, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dDI_CTRL',
                             description='',
                             hidden=False, enum=None, offset=0x2e8, bitSize=2, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_H7_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x2e4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_H6_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x2e0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_H6_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x2dc, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_DCD_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x2d8, bitSize=6, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_DCD_EN',
                             description='',
                             hidden=False, enum=None, offset=0x2d8, bitSize=1, bitOffset=9, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_EML_PHI_TUNE',
                             description='',
                             hidden=False, enum=None, offset=0x2d8, bitSize=1, bitOffset=8, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cPLL_CFG3',
                             description='',
                             hidden=False, enum=None, offset=0x2d8, bitSize=6, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_H5_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x2d4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='pROCESS_PAR',
                             description='',
                             hidden=False, enum=None, offset=0x2d0, bitSize=3, bitOffset=13, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tEMPERATUR_PAR',
                             description='',
                             hidden=False, enum=None, offset=0x2d0, bitSize=4, bitOffset=8, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_MODE_SEL',
                             description='',
                             hidden=False, enum=None, offset=0x2d0, bitSize=3, bitOffset=5, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_SARC_LPBK_ENB',
                             description='',
                             hidden=False, enum=None, offset=0x2d0, bitSize=1, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_H5_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x2cc, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_H4_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x2c8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_H4_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x2c4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_H3_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x2c0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dFE_D_X_REL_POS',
                             description='',
                             hidden=False, enum=None, offset=0x2bc, bitSize=1, bitOffset=14, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dFE_VCM_COMP_EN',
                             description='',
                             hidden=False, enum=None, offset=0x2bc, bitSize=1, bitOffset=14, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='gM_BIAS_SELECT',
                             description='',
                             hidden=False, enum=None, offset=0x2bc, bitSize=1, bitOffset=13, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='eVODD_PHI_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x2bc, bitSize=11, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_H3_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x2b8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='pLL_SEL_MODE_GEN3',
                             description='',
                             hidden=False, enum=None, offset=0x2b4, bitSize=2, bitOffset=11, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='pLL_SEL_MODE_GEN12',
                             description='',
                             hidden=False, enum=None, offset=0x2b4, bitSize=2, bitOffset=9, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rATE_SW_USE_DRP',
                             description='',
                             hidden=False, enum=None, offset=0x2b4, bitSize=1, bitOffset=8, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXPI_LPM',
                             description='',
                             hidden=False, enum=None, offset=0x2b4, bitSize=1, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXPI_VREFSEL',
                             description='',
                             hidden=False, enum=None, offset=0x2b4, bitSize=1, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_CLK_SLIP_OVRD',
                             description='',
                             hidden=False, enum=None, offset=0x2b0, bitSize=5, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='pCS_RSVD1',
                             description='',
                             hidden=False, enum=None, offset=0x2b0, bitSize=3, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='pCIE_TXPMA_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x2ac, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='pCIE_TXPCS_CFG_GEN3',
                             description='',
                             hidden=False, enum=None, offset=0x2a8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='pCIE_RXPMA_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x2a4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXCDR_CFG5',
                             description='',
                             hidden=False, enum=None, offset=0x2a0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXCDR_CFG5_GEN3',
                             description='',
                             hidden=False, enum=None, offset=0x29c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXCDR_CFG4_GEN3',
                             description='',
                             hidden=False, enum=None, offset=0x298, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXCDR_CFG3_GEN3',
                             description='',
                             hidden=False, enum=None, offset=0x294, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXCDR_CFG2_GEN3',
                             description='',
                             hidden=False, enum=None, offset=0x290, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXCDR_CFG1_GEN3',
                             description='',
                             hidden=False, enum=None, offset=0x28c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXCDR_CFG0_GEN3',
                             description='',
                             hidden=False, enum=None, offset=0x288, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_GC_CFG2',
                             description='',
                             hidden=False, enum=None, offset=0x284, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_GC_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x280, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_GC_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x27c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_UT_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x278, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXPI_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x274, bitSize=2, bitOffset=14, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXPI_CFG2',
                             description='',
                             hidden=False, enum=None, offset=0x274, bitSize=2, bitOffset=12, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXPI_CFG3',
                             description='',
                             hidden=False, enum=None, offset=0x274, bitSize=2, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXPI_CFG4',
                             description='',
                             hidden=False, enum=None, offset=0x274, bitSize=1, bitOffset=9, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXPI_CFG5',
                             description='',
                             hidden=False, enum=None, offset=0x274, bitSize=1, bitOffset=8, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXPI_CFG6',
                             description='',
                             hidden=False, enum=None, offset=0x274, bitSize=3, bitOffset=5, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXPI_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x274, bitSize=2, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tXPI_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x270, bitSize=2, bitOffset=11, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tXPI_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x270, bitSize=2, bitOffset=9, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tXPI_CFG2',
                             description='',
                             hidden=False, enum=None, offset=0x270, bitSize=2, bitOffset=7, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tXPI_CFG3',
                             description='',
                             hidden=False, enum=None, offset=0x270, bitSize=1, bitOffset=6, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tXPI_CFG4',
                             description='',
                             hidden=False, enum=None, offset=0x270, bitSize=1, bitOffset=5, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tXPI_CFG5',
                             description='',
                             hidden=False, enum=None, offset=0x270, bitSize=3, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_DFELPM_KLKH_AGC_STUP_EN',
                             description='',
                             hidden=False, enum=None, offset=0x26c, bitSize=1, bitOffset=15, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_DFELPM_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x26c, bitSize=4, bitOffset=11, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_DFELPM_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x26c, bitSize=1, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_DFE_KL_LPM_KH_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x26c, bitSize=2, bitOffset=8, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_DFE_KL_LPM_KH_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x26c, bitSize=3, bitOffset=5, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tXPI_PPM_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x268, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='gEARBOX_MODE',
                             description='',
                             hidden=False, enum=None, offset=0x264, bitSize=5, bitOffset=11, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tXPI_SYNFREQ_PPM',
                             description='',
                             hidden=False, enum=None, offset=0x264, bitSize=3, bitOffset=8, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tXPI_PPMCLK_SEL',
                             description='',
                             hidden=False, enum=None, offset=0x264, bitSize=1, bitOffset=7, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tXPI_INVSTROBE_SEL',
                             description='',
                             hidden=False, enum=None, offset=0x264, bitSize=1, bitOffset=6, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tXPI_GRAY_SEL',
                             description='',
                             hidden=False, enum=None, offset=0x264, bitSize=1, bitOffset=5, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tXPI_LPM',
                             description='',
                             hidden=False, enum=None, offset=0x264, bitSize=1, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tXPI_VREFSEL',
                             description='',
                             hidden=False, enum=None, offset=0x264, bitSize=1, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_HE_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x260, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_AFE_CM_EN',
                             description='',
                             hidden=False, enum=None, offset=0x25c, bitSize=1, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_CAPFF_SARC_ENB',
                             description='',
                             hidden=False, enum=None, offset=0x25c, bitSize=1, bitOffset=11, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_EYESCAN_VS_NEG_DIR',
                             description='',
                             hidden=False, enum=None, offset=0x25c, bitSize=1, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_EYESCAN_VS_UT_SIGN',
                             description='',
                             hidden=False, enum=None, offset=0x25c, bitSize=1, bitOffset=9, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_EYESCAN_VS_CODE',
                             description='',
                             hidden=False, enum=None, offset=0x25c, bitSize=7, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_EYESCAN_VS_RANGE',
                             description='',
                             hidden=False, enum=None, offset=0x25c, bitSize=2, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='pMA_RSV1',
                             description='',
                             hidden=False, enum=None, offset=0x254, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='eS_CLK_PHASE_SEL',
                             description='',
                             hidden=False, enum=None, offset=0x250, bitSize=1, bitOffset=11, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='uSE_PCS_CLK_PHASE_SEL',
                             description='',
                             hidden=False, enum=None, offset=0x250, bitSize=1, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXCFOK_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x24c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='aDAPT_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x248, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='aDAPT_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x244, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_UT_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x240, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_VP_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x23c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_VP_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x238, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFELPM_KL_CFG2',
                             description='',
                             hidden=False, enum=None, offset=0x234, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='aCJTAG_MODE',
                             description='',
                             hidden=False, enum=None, offset=0x230, bitSize=1, bitOffset=15, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='aCJTAG_DEBUG_MODE',
                             description='',
                             hidden=False, enum=None, offset=0x230, bitSize=1, bitOffset=14, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='aCJTAG_RESET',
                             description='',
                             hidden=False, enum=None, offset=0x230, bitSize=1, bitOffset=13, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rESET_POWERSAVE_DISABLE',
                             description='',
                             hidden=False, enum=None, offset=0x230, bitSize=1, bitOffset=12, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_TUNE_AFE_OS',
                             description='',
                             hidden=False, enum=None, offset=0x230, bitSize=2, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_DFE_KL_LPM_KL_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x230, bitSize=2, bitOffset=8, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_DFE_KL_LPM_KL_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x230, bitSize=3, bitOffset=5, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tXSYNC_MULTILANE',
                             description='',
                             hidden=False, enum=None, offset=0x22c, bitSize=1, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXSYNC_MULTILANE',
                             description='',
                             hidden=False, enum=None, offset=0x22c, bitSize=1, bitOffset=9, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_CTLE3_LPF',
                             description='',
                             hidden=False, enum=None, offset=0x22c, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_PMADATA_OPT',
                             description='',
                             hidden=False, enum=None, offset=0x228, bitSize=1, bitOffset=15, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXSYNC_OVRD',
                             description='',
                             hidden=False, enum=None, offset=0x228, bitSize=1, bitOffset=14, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tXSYNC_OVRD',
                             description='',
                             hidden=False, enum=None, offset=0x228, bitSize=1, bitOffset=13, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_IDLE_DATA_ZERO',
                             description='',
                             hidden=False, enum=None, offset=0x228, bitSize=1, bitOffset=12, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='a_RXOSCALRESET',
                             description='',
                             hidden=False, enum=None, offset=0x228, bitSize=1, bitOffset=11, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXOOB_CLK_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x228, bitSize=1, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tXSYNC_SKIP_DA',
                             description='',
                             hidden=False, enum=None, offset=0x228, bitSize=1, bitOffset=9, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXSYNC_SKIP_DA',
                             description='',
                             hidden=False, enum=None, offset=0x228, bitSize=1, bitOffset=8, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXOSCALRESET_TIME',
                             description='',
                             hidden=False, enum=None, offset=0x228, bitSize=5, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXPRBS_LINKACQ_CNT',
                             description='',
                             hidden=False, enum=None, offset=0x224, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_QPI_STATUS_EN',
                             description='',
                             hidden=False, enum=None, offset=0x214, bitSize=1, bitOffset=13, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_INT_DATAWIDTH',
                             description='',
                             hidden=False, enum=None, offset=0x214, bitSize=2, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_HD_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x210, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_MARGIN_LOW_3',
                             description='',
                             hidden=False, enum=None, offset=0x20c, bitSize=7, bitOffset=9, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_MARGIN_LOW_4',
                             description='',
                             hidden=False, enum=None, offset=0x20c, bitSize=7, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_MARGIN_LOW_1',
                             description='',
                             hidden=False, enum=None, offset=0x208, bitSize=7, bitOffset=9, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_MARGIN_LOW_2',
                             description='',
                             hidden=False, enum=None, offset=0x208, bitSize=7, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_MARGIN_FULL_4',
                             description='',
                             hidden=False, enum=None, offset=0x204, bitSize=7, bitOffset=9, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_MARGIN_LOW_0',
                             description='',
                             hidden=False, enum=None, offset=0x204, bitSize=7, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_MARGIN_FULL_2',
                             description='',
                             hidden=False, enum=None, offset=0x200, bitSize=7, bitOffset=9, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_MARGIN_FULL_3',
                             description='',
                             hidden=False, enum=None, offset=0x200, bitSize=7, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_MARGIN_FULL_0',
                             description='',
                             hidden=False, enum=None, offset=0x1fc, bitSize=7, bitOffset=9, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_MARGIN_FULL_1',
                             description='',
                             hidden=False, enum=None, offset=0x1fc, bitSize=7, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_CLKMUX_EN',
                             description='',
                             hidden=False, enum=None, offset=0x1f8, bitSize=1, bitOffset=15, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_LOOPBACK_DRIVE_HIZ',
                             description='',
                             hidden=False, enum=None, offset=0x1f8, bitSize=1, bitOffset=14, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_DRIVE_MODE',
                             description='',
                             hidden=False, enum=None, offset=0x1f8, bitSize=5, bitOffset=8, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_EIDLE_ASSERT_DELAY',
                             description='',
                             hidden=False, enum=None, offset=0x1f8, bitSize=3, bitOffset=5, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_EIDLE_DEASSERT_DELAY',
                             description='',
                             hidden=False, enum=None, offset=0x1f8, bitSize=3, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_RXDETECT_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x1f4, bitSize=14, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_MAINCURSOR_SEL',
                             description='',
                             hidden=False, enum=None, offset=0x1f0, bitSize=1, bitOffset=14, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tXGEARBOX_EN',
                             description='',
                             hidden=False, enum=None, offset=0x1f0, bitSize=1, bitOffset=13, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tXOUT_DIV',
                             description='',
                             hidden=False, enum=None, offset=0x1f0, bitSize=3, bitOffset=8, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tXBUF_EN',
                             description='',
                             hidden=False, enum=None, offset=0x1f0, bitSize=1, bitOffset=7, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tXBUF_RESET_ON_RATE_CHANGE',
                             description='',
                             hidden=False, enum=None, offset=0x1f0, bitSize=1, bitOffset=6, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_RXDETECT_REF',
                             description='',
                             hidden=False, enum=None, offset=0x1f0, bitSize=3, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tXFIFO_ADDR_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x1f0, bitSize=1, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_DEEMPH0',
                             description='',
                             hidden=False, enum=None, offset=0x1ec, bitSize=8, bitOffset=8, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_DEEMPH1',
                             description='',
                             hidden=False, enum=None, offset=0x1ec, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_CLK25_DIV',
                             description='',
                             hidden=False, enum=None, offset=0x1e8, bitSize=5, bitOffset=11, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_XCLK_SEL',
                             description='',
                             hidden=False, enum=None, offset=0x1e8, bitSize=1, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_DATA_WIDTH',
                             description='',
                             hidden=False, enum=None, offset=0x1e8, bitSize=4, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tST_RSV0',
                             description='',
                             hidden=False, enum=None, offset=0x1e4, bitSize=8, bitOffset=8, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tST_RSV1',
                             description='',
                             hidden=False, enum=None, offset=0x1e4, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tRANS_TIME_RATE',
                             description='',
                             hidden=False, enum=None, offset=0x1e0, bitSize=8, bitOffset=8, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='pD_TRANS_TIME_NONE_P2',
                             description='',
                             hidden=False, enum=None, offset=0x1dc, bitSize=8, bitOffset=8, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='pD_TRANS_TIME_TO_P2',
                             description='',
                             hidden=False, enum=None, offset=0x1dc, bitSize=8, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='pD_TRANS_TIME_FROM_P2',
                             description='',
                             hidden=False, enum=None, offset=0x1d8, bitSize=12, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tERM_RCAL_OVRD',
                             description='',
                             hidden=False, enum=None, offset=0x1d8, bitSize=2, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_HF_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x1d4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tERM_RCAL_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x1d0, bitSize=15, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tXPH_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x1cc, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXCDR_LOCK_CFG2',
                             description='',
                             hidden=False, enum=None, offset=0x1c8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tXPH_MONITOR_SEL',
                             description='',
                             hidden=False, enum=None, offset=0x1c4, bitSize=5, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tAPDLY_SET_TX',
                             description='',
                             hidden=False, enum=None, offset=0x1c4, bitSize=2, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tXDLY_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x1c0, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tXPHDLY_CFG_0',
                             description='',
                             hidden=False, enum=None, offset=0x1b8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tXPHDLY_CFG_1',
                             description='',
                             hidden=False, enum=None, offset=0x1bc, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_CLK25_DIV',
                             description='',
                             hidden=False, enum=None, offset=0x1b4, bitSize=5, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='sATA_MAX_INIT',
                             description='',
                             hidden=False, enum=None, offset=0x1b0, bitSize=6, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='sATA_MAX_WAKE',
                             description='',
                             hidden=False, enum=None, offset=0x1b0, bitSize=6, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='sATA_MAX_BURST',
                             description='',
                             hidden=False, enum=None, offset=0x1ac, bitSize=6, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='sAS_MAX_COM',
                             description='',
                             hidden=False, enum=None, offset=0x1ac, bitSize=6, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='sATA_MIN_INIT',
                             description='',
                             hidden=False, enum=None, offset=0x1a8, bitSize=6, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='sATA_MIN_WAKE',
                             description='',
                             hidden=False, enum=None, offset=0x1a8, bitSize=6, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='sATA_MIN_BURST',
                             description='',
                             hidden=False, enum=None, offset=0x1a4, bitSize=6, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='sAS_MIN_COM',
                             description='',
                             hidden=False, enum=None, offset=0x1a4, bitSize=6, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='sATA_BURST_VAL',
                             description='',
                             hidden=False, enum=None, offset=0x1a0, bitSize=3, bitOffset=13, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='sATA_BURST_SEQ_LEN',
                             description='',
                             hidden=False, enum=None, offset=0x1a0, bitSize=4, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='sATA_EIDLE_VAL',
                             description='',
                             hidden=False, enum=None, offset=0x1a0, bitSize=2, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXBUF_EIDLE_HI_CNT',
                             description='',
                             hidden=False, enum=None, offset=0x19c, bitSize=4, bitOffset=12, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXCDR_HOLD_DURING_EIDLE',
                             description='',
                             hidden=False, enum=None, offset=0x19c, bitSize=1, bitOffset=11, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_DFE_LPM_HOLD_DURING_EIDLE',
                             description='',
                             hidden=False, enum=None, offset=0x19c, bitSize=1, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXBUF_EIDLE_LO_CNT',
                             description='',
                             hidden=False, enum=None, offset=0x19c, bitSize=4, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXBUF_RESET_ON_EIDLE',
                             description='',
                             hidden=False, enum=None, offset=0x19c, bitSize=1, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXCDR_FR_RESET_ON_EIDLE',
                             description='',
                             hidden=False, enum=None, offset=0x19c, bitSize=1, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXCDR_PH_RESET_ON_EIDLE',
                             description='',
                             hidden=False, enum=None, offset=0x19c, bitSize=1, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXBUF_THRESH_OVRD',
                             description='',
                             hidden=False, enum=None, offset=0x198, bitSize=1, bitOffset=15, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXBUF_RESET_ON_COMMAALIGN',
                             description='',
                             hidden=False, enum=None, offset=0x198, bitSize=1, bitOffset=14, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXBUF_RESET_ON_RATE_CHANGE',
                             description='',
                             hidden=False, enum=None, offset=0x198, bitSize=1, bitOffset=13, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXBUF_RESET_ON_CB_CHANGE',
                             description='',
                             hidden=False, enum=None, offset=0x198, bitSize=1, bitOffset=12, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXBUF_THRESH_UNDFLW',
                             description='',
                             hidden=False, enum=None, offset=0x198, bitSize=6, bitOffset=6, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_CLKMUX_EN',
                             description='',
                             hidden=False, enum=None, offset=0x198, bitSize=1, bitOffset=5, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_DISPERR_SEQ_MATCH',
                             description='',
                             hidden=False, enum=None, offset=0x198, bitSize=1, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXBUF_ADDR_MODE',
                             description='',
                             hidden=False, enum=None, offset=0x198, bitSize=1, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_WIDEMODE_CDR',
                             description='',
                             hidden=False, enum=None, offset=0x198, bitSize=1, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_INT_DATAWIDTH',
                             description='',
                             hidden=False, enum=None, offset=0x198, bitSize=2, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXBUF_THRESH_OVFLW',
                             description='',
                             hidden=False, enum=None, offset=0x194, bitSize=6, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='dMONITOR_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x194, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_SIG_VALID_DLY',
                             description='',
                             hidden=False, enum=None, offset=0x190, bitSize=5, bitOffset=11, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXSLIDE_MODE',
                             description='',
                             hidden=False, enum=None, offset=0x190, bitSize=2, bitOffset=9, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXPRBS_ERR_LOOPBACK',
                             description='',
                             hidden=False, enum=None, offset=0x190, bitSize=1, bitOffset=8, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXSLIDE_AUTO_WAIT',
                             description='',
                             hidden=False, enum=None, offset=0x190, bitSize=4, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXBUF_EN',
                             description='',
                             hidden=False, enum=None, offset=0x190, bitSize=1, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_XCLK_SEL',
                             description='',
                             hidden=False, enum=None, offset=0x190, bitSize=2, bitOffset=1, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXGEARBOX_EN',
                             description='',
                             hidden=False, enum=None, offset=0x190, bitSize=1, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='cBCC_DATA_SOURCE_SEL',
                             description='',
                             hidden=False, enum=None, offset=0x18c, bitSize=1, bitOffset=15, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='oOB_PWRUP',
                             description='',
                             hidden=False, enum=None, offset=0x18c, bitSize=1, bitOffset=14, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXOOB_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x18c, bitSize=9, bitOffset=5, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXOUT_DIV',
                             description='',
                             hidden=False, enum=None, offset=0x18c, bitSize=3, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_SUM_DFETAPREP_EN',
                             description='',
                             hidden=False, enum=None, offset=0x188, bitSize=1, bitOffset=14, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_SUM_VCM_OVWR',
                             description='',
                             hidden=False, enum=None, offset=0x188, bitSize=1, bitOffset=13, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_SUM_IREF_TUNE',
                             description='',
                             hidden=False, enum=None, offset=0x188, bitSize=4, bitOffset=9, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_SUM_RES_CTRL',
                             description='',
                             hidden=False, enum=None, offset=0x188, bitSize=2, bitOffset=7, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_SUM_VCMTUNE',
                             description='',
                             hidden=False, enum=None, offset=0x188, bitSize=4, bitOffset=3, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_SUM_VREF_TUNE',
                             description='',
                             hidden=False, enum=None, offset=0x188, bitSize=3, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXPH_MONITOR_SEL',
                             description='',
                             hidden=False, enum=None, offset=0x184, bitSize=5, bitOffset=11, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_CM_BUF_PD',
                             description='',
                             hidden=False, enum=None, offset=0x184, bitSize=1, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_CM_BUF_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x184, bitSize=4, bitOffset=6, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_CM_TRIM',
                             description='',
                             hidden=False, enum=None, offset=0x184, bitSize=4, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_CM_SEL',
                             description='',
                             hidden=False, enum=None, offset=0x184, bitSize=2, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='pCS_RSVD0',
                             description='',
                             hidden=False, enum=None, offset=0x180, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_BIAS_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x17c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_HD_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x178, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_HF_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x174, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDLY_LCFG',
                             description='',
                             hidden=False, enum=None, offset=0x170, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDLY_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x16c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_OS_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x168, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXPHDLY_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x164, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_OS_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x160, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tXDLY_LCFG',
                             description='',
                             hidden=False, enum=None, offset=0x15c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='aLIGN_PCOMMA_DET',
                             description='',
                             hidden=False, enum=None, offset=0x158, bitSize=1, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='aLIGN_PCOMMA_VALUE',
                             description='',
                             hidden=False, enum=None, offset=0x158, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='lOCAL_MASTER',
                             description='',
                             hidden=False, enum=None, offset=0x154, bitSize=1, bitOffset=13, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='pCS_PCIE_EN',
                             description='',
                             hidden=False, enum=None, offset=0x154, bitSize=1, bitOffset=12, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='aLIGN_MCOMMA_DET',
                             description='',
                             hidden=False, enum=None, offset=0x154, bitSize=1, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='aLIGN_MCOMMA_VALUE',
                             description='',
                             hidden=False, enum=None, offset=0x154, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_CFG_0',
                             description='',
                             hidden=False, enum=None, offset=0x14c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_CFG_1',
                             description='',
                             hidden=False, enum=None, offset=0x150, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_EN_HI_LR',
                             description='',
                             hidden=False, enum=None, offset=0x148, bitSize=1, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_DFE_AGC_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x148, bitSize=3, bitOffset=2, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rX_DFE_AGC_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0x148, bitSize=2, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='eS_PMA_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x144, bitSize=10, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_HC_CFG1',
                             description='',
                             hidden=False, enum=None, offset=0x140, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='eS_HORZ_OFFSET',
                             description='',
                             hidden=False, enum=None, offset=0x13c, bitSize=12, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='fTS_LANE_DESKEW_CFG',
                             description='',
                             hidden=False, enum=None, offset=0x13c, bitSize=1, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='fTS_LANE_DESKEW_EN',
                             description='',
                             hidden=False, enum=None, offset=0x138, bitSize=1, bitOffset=4, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='fTS_DESKEW_SEQ_ENABLE',
                             description='',
                             hidden=False, enum=None, offset=0x138, bitSize=4, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='eS_SDATA_MASK_0',
                             description='',
                             hidden=False, enum=None, offset=0x124, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='eS_SDATA_MASK_1',
                             description='',
                             hidden=False, enum=None, offset=0x128, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='eS_SDATA_MASK_2',
                             description='',
                             hidden=False, enum=None, offset=0x12c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='eS_SDATA_MASK_3',
                             description='',
                             hidden=False, enum=None, offset=0x130, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='eS_SDATA_MASK_4',
                             description='',
                             hidden=False, enum=None, offset=0x134, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='eS_QUAL_MASK_0',
                             description='',
                             hidden=False, enum=None, offset=0x110, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='eS_QUAL_MASK_1',
                             description='',
                             hidden=False, enum=None, offset=0x114, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='eS_QUAL_MASK_2',
                             description='',
                             hidden=False, enum=None, offset=0x118, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='eS_QUAL_MASK_3',
                             description='',
                             hidden=False, enum=None, offset=0x11c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='eS_QUAL_MASK_4',
                             description='',
                             hidden=False, enum=None, offset=0x120, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='eS_QUALIFIER_0',
                             description='',
                             hidden=False, enum=None, offset=0xfc, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='eS_QUALIFIER_1',
                             description='',
                             hidden=False, enum=None, offset=0x100, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='eS_QUALIFIER_2',
                             description='',
                             hidden=False, enum=None, offset=0x104, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='eS_QUALIFIER_3',
                             description='',
                             hidden=False, enum=None, offset=0x108, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='eS_QUALIFIER_4',
                             description='',
                             hidden=False, enum=None, offset=0x10c, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='tX_PROGDIV_CFG',
                             description='',
                             hidden=False, enum=None, offset=0xf8, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='rXDFE_HC_CFG0',
                             description='',
                             hidden=False, enum=None, offset=0xf4, bitSize=16, bitOffset=0, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='eS_CONTROL',
                             description='',
                             hidden=False, enum=None, offset=0xf0, bitSize=6, bitOffset=10, base='uint', mode='RW'))

    dev.add(pyrogue.Variable(name='eS_ERRDET_EN',
                             description='',
                             hidden=False, enum=None, offset=0xf0, bitSize=1, bitOffset=9, base='uint', mode='RW'))

    return dev
