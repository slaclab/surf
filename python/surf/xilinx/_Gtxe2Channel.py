#-----------------------------------------------------------------------------
# Description:
# PyRogue Gtpe2Channel
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

class Gtxe2Channel(pr.Device):
    def __init__(self, read_only=False, **kwargs):
        super().__init__(**kwargs)

        mode = 'RO' if read_only else 'RW'

        self.add(pr.RemoteVariable(
            offset = 0x000 << 2,
            bitOffset = 1,
            mode = mode,
            name = "UCODEER_CLR",
            bitSize = 1))

        self.add(pr.RemoteVariable(
            offset = [0x00D << 2, 0x00E <<2],
            bitOffset = [15, 0],
            bitSize = [1, 6],
            mode = mode,
            name = 'RXDFELPMRESET_TIME'))

        self.add(pr.RemoteVariable(
            offset = 0x00D << 2,
            bitOffset = 10,
            mode = mode,
            name = 'RXCDRPHRESET_TIME',
            bitSize = 5))

        self.add(pr.RemoteVariable(
            offset = 0x00D << 2,
            bitOffset = 5,
            mode = mode,
            name = 'RXCDRFREQRESET_TIME',
            bitSize = 5))

        self.add(pr.RemoteVariable(
            offset = 0x00D << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RXBUFRESET_TIME',
            bitSize = 5))

        self.add(pr.RemoteVariable(
            offset = 0x00E << 2,
            bitOffset = 11,
            mode = mode,
            name = 'RXPCSRESET_TIME',
            bitSize = 5))

        self.add(pr.RemoteVariable(
            offset = 0x00E << 2,
            bitOffset = 6,
            mode = mode,
            name = 'RXPMARESET_TIME',
            bitSize = 5))

        self.add(pr.RemoteVariable(
            offset = 0x00F << 2,
            bitOffset = 10,
            mode = mode,
            name = 'RXISCANRESET_TIME',
            bitSize = 5))

        self.add(pr.RemoteVariable(
            offset = 0x00F << 2,
            bitOffset = 5,
            mode = mode,
            name = 'TXPCSRESET_TIME',
            bitSize = 5))

        self.add(pr.RemoteVariable(
            offset = 0x00F << 2,
            bitOffset = 0,
            mode = mode,
            name = 'TXPMARESET_TIME',
            bitSize = 5))

        self.add(pr.RemoteVariable(
            offset = 0x011 << 2,
            bitOffset = 14,
            mode = mode,
            name = 'RX_INT_DATAWIDTH',
            bitSize = 1,
            enum = {
                0: '2-byte',
                1: '4-byte'}))

        self.add(pr.RemoteVariable(
            offset = 0x011 << 2,
            bitOffset = 11,
            mode = mode,
            name = 'RX_DATA_WIDTH',
            bitSize = 3,
            value = 2,
            enum = {
                2: '16',
                3: '20',
                4: '32',
                5: '40',
                6: '64',
                7: '80'}))

        self.add(pr.RemoteVariable(
            offset = 0x011 << 2,
            bitOffset = 6,
            mode = mode,
            name = 'RX_CLK25_DIV',
            bitSize = 5,
            enum = {x:f'{x+1}' for x in range(32)}))

        self.add(pr.RemoteVariable(
            offset = 0x011 << 2,
            bitOffset = 4,
            mode = mode,
            name = 'RX_CM_SEL',
            bitSize = 2))

        self.add(pr.RemoteVariable(
            offset = 0x011 << 2,
            bitOffset = 1,
            mode = mode,
            name = 'RX_CM_TRIM',
            bitSize = 3))

        self.add(pr.RemoteVariable(
            offset = 0x011 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RXPRBS_ERR_LOOPBACK',
            bitSize = 1))

        self.add(pr.RemoteVariable(
            offset = 0x012 << 2,
            bitOffset = 12,
            mode = mode,
            name = 'SATA_BURST_SEQ_LEN',
            bitSize = 4))

        self.add(pr.RemoteVariable(
            offset = 0x012 << 2,
            bitOffset = 10,
            mode = mode,
            name = 'OUTREFCLK_SEL_INV',
            bitSize = 2))

        self.add(pr.RemoteVariable(
            offset = 0x012 << 2,
            bitOffset = 7,
            mode = mode,
            name = 'SATA_BURST_VAL',
            bitSize = 3))

        self.add(pr.RemoteVariable(
            offset = 0x012 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RXOOB_CFG',
            bitSize = 7))

        self.add(pr.RemoteVariable(
            offset = 0x013 << 2,
            bitOffset = 9,
            mode = mode,
            name = 'SAS_MIN_COM',
            bitSize = 6))

        self.add(pr.RemoteVariable(
            offset = 0x013 << 2,
            bitOffset = 3,
            mode = mode,
            name = 'SATA_MIN_BURST',
            bitSize = 6))

        self.add(pr.RemoteVariable(
            offset = 0x013 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'SATA_EIDLE_VAL',
            bitSize = 3))

        self.add(pr.RemoteVariable(
            offset = 0x014 << 2,
            bitOffset = 6,
            mode = mode,
            name = 'SATA_MIN_WAKE',
            bitSize = 6))

        self.add(pr.RemoteVariable(
            offset = 0x014 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'SATA_MIN_INIT',
            bitSize = 6))

        self.add(pr.RemoteVariable(
            offset = 0x015 << 2,
            bitOffset = 6,
            mode = mode,
            name = 'SAS_MAX_COM',
            bitSize = 7))

        self.add(pr.RemoteVariable(
            offset = 0x015 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'SATA_MAX_BURST',
            bitSize = 6))

        self.add(pr.RemoteVariable(
            offset = 0x016 << 2,
            bitOffset = 6,
            mode = mode,
            name = 'SATA_MAX_WAKE',
            bitSize = 6))

        self.add(pr.RemoteVariable(
            offset = 0x016 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'SATA_MAX_INIT',
            bitSize = 6))

        self.add(pr.RemoteVariable(
            offset = 0x018 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'TRANS_TIME_RATE',
            bitSize = 8))

        self.add(pr.RemoteVariable(
            offset = 0x019 << 2,
            bitOffset = 12,
            mode = mode,
            name = 'TX_PREDRIVER_MODE',
            bitSize = 1))

        self.add(pr.RemoteVariable(
            offset = 0x019 << 2,
            bitOffset = 9,
            mode = mode,
            name = 'TX_EIDLE_DEASSERT_DELAY',
            bitSize = 3))

        self.add(pr.RemoteVariable(
            offset = 0x019 << 2,
            bitOffset = 6,
            mode = mode,
            name = 'TX_EIDLE_ASSERT_DELAY',
            bitSize = 3))

        self.add(pr.RemoteVariable(
            offset = 0x019 << 2,
            bitOffset = 5,
            mode = mode,
            name = 'TX_LOOPBACK_DRIVE_HIZ',
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x019 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'TX_DRIVE_MODE',
            bitSize = 5,
            enum = {
                0: 'DIRECT',
                1: 'PIPE',
                2: 'PIPEGEN3'}))

        self.add(pr.RemoteVariable(
            offset = 0x01A << 2,
            bitOffset = 8,
            mode = mode,
            name = 'PD_TRANS_TIME_TO_P2',
            bitSize = 8))

        self.add(pr.RemoteVariable(
            offset = 0x01A << 2,
            bitOffset = 0,
            mode = mode,
            name = 'PD_TRANS_TIME_NONE_P2',
            bitSize = 8))

        self.add(pr.RemoteVariable(
            offset = 0x01B << 2,
            bitOffset = 1,
            mode = mode,
            name = 'PD_TRANS_TIME_FROM_P2',
            bitSize = 12))

        self.add(pr.RemoteVariable(
            offset = 0x01B << 2,
            bitOffset = 0,
            mode = mode,
            name = 'PCS_PCIE_EN',
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x01C << 2,
            bitOffset = 15,
            mode = mode,
            name = 'TXBUF_RESET_ON_RATE_CHANGE',
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x01C << 2,
            bitOffset = 14,
            mode = mode,
            name = 'TXBUF_EN',
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x01C << 2,
            bitOffset = 5,
            mode = mode,
            name = 'TXGEARBOX_EN',
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x01C << 2,
            bitOffset = 0,
            mode = mode,
            name = 'GEARBOX_MODE',
            bitSize = 3))

        self.add(pr.RemoteVariable(
            offset = [0x01D << 2, 0x01E << 2],
            bitOffset = [0, 0],
            bitSize = [16, 7],
            mode = mode,
            name = 'RX_DFE_GAIN_CFG'))

        self.add(pr.RemoteVariable(
            offset = 0x01E << 2,
            bitOffset = 14,
            mode = mode,
            name = 'RX_DFE_LPM_HOLD_DURING_EIDLE',
            bitSize = 1))

        self.add(pr.RemoteVariable(
            offset = 0x01F << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RX_DFE_H2_CFG',
            bitSize = 12))

        self.add(pr.RemoteVariable(
            offset = 0x020 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RX_DFE_H3_CFG',
            bitSize = 12))

        self.add(pr.RemoteVariable(
            offset = 0x021 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RX_DFE_H4_CFG',
            bitSize = 11))

        self.add(pr.RemoteVariable(
            offset = 0x022 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RX_DFE_H5_CFG',
            bitSize = 11))

        self.add(pr.RemoteVariable(
            offset = 0x023 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RX_DFE_KL_CFG',
            bitSize = 13))

        self.add(pr.RemoteVariable(
            offset = [0x024 << 2, 0x025 <<2],
            bitOffset = [15, 0],
            bitSize = [1, 16],
            mode = mode,
            name = 'RX_DFE_UT_CFG'))

        self.add(pr.RemoteVariable(
            offset = 0x024 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RX_OS_CFG',
            bitSize = 13))

        self.add(pr.RemoteVariable(
            offset = [0x026 << 2, 0x027 << 2],
            bitOffset = [0, 0],
            bitSize = [16, 1],
            mode = mode,
            name = 'RX_DFE_VP_CFG'))

        self.add(pr.RemoteVariable(
            offset = 0x028 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RX_DFE_XYD_CFG',
            bitSize = 13))

        self.add(pr.RemoteVariable(
            offset = 0x029 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RX_DFE_LPM_CFG',
            bitSize = 16))

        self.add(pr.RemoteVariable(
            offset = 0x02A << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RXLPM_HF_CFG',
            bitSize = 14))

        self.add(pr.RemoteVariable(
            offset = 0x02B << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RXLPM_LF_CFG',
            bitSize = 14))

        self.add(pr.RemoteVariable(
            offset = [0x02C << 2,
                      0x02D << 2,
                      0x02E << 2,
                      0x02F << 2,
                      0x030 << 2],
            bitOffset = [0, 0, 0, 0, 0],
            bitSize = [16, 16, 16, 16, 16],
            mode = mode,
            name = 'ES_QUALIFIER'))

        self.add(pr.RemoteVariable(
            offset = [0x031 << 2,
                      0x032 << 2,
                      0x033 << 2,
                      0x034 << 2,
                      0x035 << 2],
            bitOffset = [0, 0, 0, 0, 0],
            bitSize = [16, 16, 16, 16, 16],
            mode = mode,
            name = 'ES_QUAL_MASK'))

        self.add(pr.RemoteVariable(
            offset = [0x036 << 2,
                      0x037 << 2,
                      0x038 << 2,
                      0x039 << 2,
                      0x03A << 2],
            bitOffset = [0, 0, 0, 0, 0],
            bitSize = [16, 16, 16, 16, 16],
            mode = mode,
            name = 'ES_SDATA_MASK'))

        self.add(pr.RemoteVariable(
            offset = 0x03B << 2,
            bitOffset = 11,
            mode = mode,
            name = 'ES_PRESCALE',
            bitSize = 5))

        self.add(pr.RemoteVariable(
            offset = 0x03B << 2,
            bitOffset = 0,
            mode = mode,
            name = 'ES_VERT_OFFSET',
            bitSize = 9))

        self.add(pr.RemoteVariable(
            offset = 0x03C << 2,
            bitOffset = 0,
            mode = mode,
            name = 'ES_HORZ_OFFSET',
            bitSize = 12))

        self.add(pr.RemoteVariable(
            offset = 0x03D << 2,
            bitOffset = 15,
            mode = mode,
            name = 'RX_DISPERR_SEQ_MATCH',
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x03D << 2,
            bitOffset = 14,
            mode = mode,
            name = 'DEC_PCOMMA_DETECT',
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x03D << 2,
            bitOffset = 13,
            mode = mode,
            name = 'DEC_MCOMMA_DETECT',
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x03D << 2,
            bitOffset = 12,
            mode = mode,
            name = 'DEC_VALID_COMMA_ONLY',
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x03D << 2,
            bitOffset = 9,
            mode = mode,
            name = 'ES_ERRDET_EN',
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x03D << 2,
            bitOffset = 8,
            mode = mode,
            name = 'ES_EYE_SCAN_EN',
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x03D << 2,
            bitOffset = 0,
            mode = mode,
            name = 'ES_CONTROL',
            bitSize = 6))

        self.add(pr.RemoteVariable(
            offset = 0x03E << 2,
            bitOffset = 0,
            mode = mode,
            name = 'ALIGN_COMMA_ENABLE',
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x03F << 2,
            bitOffset = 0,
            mode = mode,
            name = 'ALIGN_MCOMMA_VALUE',
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x040 << 2,
            bitOffset = 14,
            mode = mode,
            name = 'RXSLIDE_MODE',
            bitSize = 2,
            enum = {
                0: 'OFF',
                1: 'AUTO',
                2: 'PCS',
                3: 'PMA'}))

        self.add(pr.RemoteVariable(
            offset = 0x040 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'ALIGN_PCOMMA_VALUE',
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x041 << 2,
            bitOffset = 13,
            mode = mode,
            name = 'ALIGN_COMMA_WORD',
            bitSize = 3,
            value = 1,
            enum = {
                1: '1',
                2: '2',
                4: '4'}))

        self.add(pr.RemoteVariable(
            offset = 0x041 << 2,
            bitOffset = 8,
            mode = 'RO',
            name = 'RX_SIG_VALID_DLY',
            bitSize = 5,
            enum = {x: f'{x+1}' for x in range(32)}))

        self.add(pr.RemoteVariable(
            offset = 0x041 << 2,
            bitOffset = 7,
            mode = mode,
            name = 'ALIGN_PCOMMA_DET',
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x041 << 2,
            bitOffset = 6,
            mode = mode,
            name = 'ALIGN_MCOMMA_DET',
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x041 << 2,
            bitOffset = 5,
            mode = mode,
            name = 'SHOW_REALIGN_COMMA',
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x041 << 2,
            bitOffset = 4,
            mode = mode,
            name = 'ALIGN_COMMA_DOUBLE',
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x041 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RXSLIDE_AUTO_WAIT',
            bitSize = 4))

        self.add(pr.RemoteVariable(
            offset = 0x044 << 2,
            bitOffset = 14,
            mode = mode,
            name = 'CLK_CORRECT_USE',
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x044 << 2,
            bitOffset = 10,
            mode = mode,
            name = 'CLK_COR_SEQ_1_ENABLE',
            bitSize = 4))

        self.add(pr.RemoteVariable(
            offset = 0x044 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'CLK_COR_SEQ_1_1',
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x045 << 2,
            bitOffset = 10,
            mode = mode,
            name = 'CLK_COR_MAX_LAT',
            bitSize = 6))

        self.add(pr.RemoteVariable(
            offset = 0x045 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'CLK_COR_SEQ_1_2',
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x046 << 2,
            bitOffset = 10,
            mode = mode,
            name = 'CLK_COR_MIN_LAT',
            bitSize = 6))

        self.add(pr.RemoteVariable(
            offset = 0x046 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'CLK_COR_SEQ_1_3',
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x047 << 2,
            bitOffset = 10,
            mode = mode,
            name = 'CLK_COR_REPEAT_WAIT',
            bitSize = 5))

        self.add(pr.RemoteVariable(
            offset = 0x047 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'CLK_COR_SEQ_1_4',
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x048 << 2,
            bitOffset = 14,
            mode = mode,
            name = 'CLK_COR_SEQ_2_USE',
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x048 << 2,
            bitOffset = 10,
            mode = mode,
            name = 'CLK_COR_SEQ_2_ENABLE',
            bitSize = 4))

        self.add(pr.RemoteVariable(
            offset = 0x048 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'CLK_COR_SEQ_2_1',
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x049 << 2,
            bitOffset = 13,
            mode = mode,
            name = 'CLK_COR_KEEP_IDLE',
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x049 << 2,
            bitOffset = 12,
            mode = mode,
            name = 'CLK_COR_PRECEDENCE',
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x049 << 2,
            bitOffset = 10,
            mode = mode,
            name = 'CLK_COR_SEQ_LEN',
            bitSize = 2,
            enum = {
                0: '1',
                1: '2',
                2: '3',
                3: '4'}))

        self.add(pr.RemoteVariable(
            offset = 0x049 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'CLK_COR_SEQ_2_2',
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x04A << 2,
            bitOffset = 0,
            mode = mode,
            name = 'CLK_COR_SEQ_2_3',
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x04B << 2,
            bitOffset = 15,
            mode = mode,
            name = 'RXGEARBOX_EN',
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x04B << 2,
            bitOffset = 0,
            mode = mode,
            name = 'CLK_COR_SEQ_2_4',
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x04C << 2,
            bitOffset = 12,
            mode = mode,
            name = 'CHAN_BOND_SEQ_1_ENABLE',
            bitSize = 4))

        self.add(pr.RemoteVariable(
            offset = 0x04C << 2,
            bitOffset = 0,
            mode = mode,
            name = 'CHAN_BOND_SEQ_1_1',
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x04D << 2,
            bitOffset = 14,
            mode = mode,
            name = 'CHAN_BOND_SEQ_LEN',
            bitSize = 2,
            enum = {x:f'{x+1}' for x in range(4)}))

        self.add(pr.RemoteVariable(
            offset = 0x04D << 2,
            bitOffset = 0,
            mode = mode,
            name = 'CHAN_BOND_SEQ_1_2',
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x04E << 2,
            bitOffset = 15,
            mode = mode,
            name = 'CHAN_BOND_KEEP_ALIGN',
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x04E << 2,
            bitOffset = 0,
            mode = mode,
            name = 'CHAN_BOND_SEQ_1_3',
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x04F << 2,
            bitOffset = 0,
            mode = mode,
            name = 'CHAN_BOND_SEQ_1_4',
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x050 << 2,
            bitOffset = 12,
            mode = mode,
            name = 'CHAN_BOND_SEQ_2_ENABLE',
            bitSize = 4))

        self.add(pr.RemoteVariable(
            offset = 0x050 << 2,
            bitOffset = 11,
            mode = mode,
            name = 'CHAN_BOND_SEQ_2_USE',
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x050 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'CHAN_BOND_SEQ_2_1',
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x051 << 2,
            bitOffset = 12,
            mode = mode,
            name = 'FTS_LANE_DESKEW_CFG',
            bitSize = 4))

        self.add(pr.RemoteVariable(
            offset = 0x051 << 2,
            bitOffset = 11,
            mode = mode,
            name = 'FTS_LANE_DESKEW_EN',
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x051 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'CHAN_BOND_SEQ_2_2',
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x052 << 2,
            bitOffset = 12,
            mode = mode,
            name = 'FTS_DESKEW_SEQ_ENABLE',
            bitSize = 4))

        self.add(pr.RemoteVariable(
            offset = 0x052 << 2,
            bitOffset = 11,
            mode = mode,
            name = 'CBCC_DATA_SOURCE_SEL',
            bitSize = 1,
            enum = {
                0: 'ENCODED',
                1: 'DECODED'}))

        self.add(pr.RemoteVariable(
            offset = 0x052 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'CHAN_BOND_SEQ_2_3',
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x053 << 2,
            bitOffset = 12,
            mode = mode,
            name = 'CHAN_BOND_MAX_SKEW',
            bitSize = 4,
            value = 1,
            enum = {x:f'{x}' for x in range(1, 15)}))

        self.add(pr.RemoteVariable(
            offset = 0x053 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'CHAN_BOND_SEQ_2_4',
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x054 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RXDLY_TAP_CFG',
            bitSize = 16))

        self.add(pr.RemoteVariable(
            offset = 0x055 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RXDLY_CFG',
            bitSize = 16))

        self.add(pr.RemoteVariable(
            offset = 0x057 << 2,
            bitOffset = 8,
            mode = mode,
            name = 'RXPH_MONITOR_SEL',
            bitSize = 5))

        self.add(pr.RemoteVariable(
            offset = 0x057 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RX_DDI_SEL',
            bitSize = 6))

        self.add(pr.RemoteVariable(
            offset = 0x059 << 2,
            bitOffset = 7,
            mode = mode,
            name = 'TX_XCLK_SEL',
            bitSize = 1,
            enum = {
                0: 'TXOUT',
                1: 'TXUSR'}))

        self.add(pr.RemoteVariable(
            offset = 0x059 << 2,
            bitOffset = 6,
            mode = mode,
            name = 'RX_XCLK_SEL',
            bitSize = 1,
            enum = {
                0: 'RXREC',
                1: 'RXUSR'}))

        self.add(pr.RemoteVariable(
            offset = [0x05B << 2,
                      0x05C <<2],
            bitOffset = [0, 0],
            bitSize = [16, 8],
            mode = mode,
            name = 'CPLL_INIT_CFG'))

        self.add(pr.RemoteVariable(
            offset = [0x05C << 2,
                      0x05D << 2],
            bitOffset = [8, 0],
            bitSize = [8, 16],
            mode = mode,
            name = 'CPLL_CFG'))

        self.add(pr.RemoteVariable(
            offset = 0x05E << 2,
            bitOffset = 14,
            mode = mode,
            name = 'SATA_CPLL_CFG',
            bitSize = 2,
            enum = {
                0: 'VCO_3000MHZ',
                1: 'VCO_1500MHZ',
                2: 'VCO_750MHZ'}))

        self.add(pr.RemoteVariable(
            offset = 0x05E << 2,
            bitOffset = 8,
            mode = mode,
            name = 'CPLL_REFCLK_DIV',
            bitSize = 5,
            enum = {
                16: '1',
                0: '2',
                1: '3',
                2: '4',
                3: '5',
                5: '6',
                6: '8',
                7: '10',
                13: '12',
                14: '16',
                15: '20'}))

        self.add(pr.RemoteVariable(
            offset = 0x05E << 2,
            bitOffset = 7,
            mode = mode,
            name = 'CPLL_FBDIV_45',
            bitSize = 1,
            enum = {
                0: '4',
                1: '5'}))

        self.add(pr.RemoteVariable(
            offset = 0x05E << 2,
            bitOffset = 0,
            mode = mode,
            name = 'CPLL_FBDIV',
            bitSize = 7,
            enum = {
                16: '1',
                0: '2',
                1: '3',
                2: '4',
                3: '5',
                5: '6',
                6: '8',
                7: '10',
                13: '12',
                14: '16',
                15: '20'}))

        self.add(pr.RemoteVariable(
            offset = 0x05F << 2,
            bitOffset = 0,
            mode = mode,
            name = 'CPLL_LOCK_CFG',
            bitSize = 16))

        self.add(pr.RemoteVariable(
            offset = [0x060 << 2, 0x061 << 2],
            bitOffset = [0, 0],
            bitSize = [16, 8],
            mode = mode,
            name = 'TXPHDLY_CFG'))

        self.add(pr.RemoteVariable(
            offset = 0x062 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'TXDLY_CFG',
            bitSize = 16))

        self.add(pr.RemoteVariable(
            offset = 0x063 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'TXDLY_TAP_CFG',
            bitSize = 16))

        self.add(pr.RemoteVariable(
            offset = 0x064 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'TXPH_CFG',
            bitSize = 16))

        self.add(pr.RemoteVariable(
            offset = 0x065 << 2,
            bitOffset = 8,
            mode = mode,
            name = 'TXPH_MONITOR_SEL',
            bitSize = 5))

        self.add(pr.RemoteVariable(
            offset = 0x066 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RX_BIAS_CFG',
            bitSize = 12))

        self.add(pr.RemoteVariable(
            offset = 0x068 << 2,
            bitOffset = 1,
            mode = mode,
            name = 'TX_CLKMUX_PD',
            bitSize = 1))

        self.add(pr.RemoteVariable(
            offset = 0x068 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RX_CLKMUX_PD',
            bitSize = 1))

        self.add(pr.RemoteVariable(
            offset = 0x069 << 2,
            bitOffset = 8,
            mode = mode,
            name = 'TERM_RCAL_OVRD',
            bitSize = 1))

        self.add(pr.RemoteVariable(
            offset = 0x069 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'TERM_RCAL_CFG',
            bitSize = 5))

        self.add(pr.RemoteVariable(
            offset = 0x06A << 2,
            bitOffset =0,
            mode = mode,
            name = 'TX_CLKDIV_25',
            bitSize = 5,
            enum = {x:f'{x+1}' for x in range(32)}))

        self.add(pr.RemoteVariable(
            offset = 0x06B << 2,
            bitOffset = 15,
            mode = mode,
            name = 'TX_QPI_STATUS_EN',
            bitSize = 1))

        self.add(pr.RemoteVariable(
            offset = 0x06B << 2,
            bitOffset = 4,
            mode = mode,
            name = 'TX_INT_DATAWIDTH',
            bitSize = 1,
            enum = {
                0: '2-byte',
                1: '4-byte'}))

        self.add(pr.RemoteVariable(
            offset = 0x06B << 2,
            bitOffset = 0,
            mode = mode,
            name = 'TX_DATA_WIDTH',
            bitSize = 3,
            value = 2,
            enum = {
                2: '16',
                3: '20',
                4: '32',
                5: '40',
                6: '64',
                7: '80'}))

        self.add(pr.RemoteVariable(
            offset = [0x06F << 2,
                      0x070 << 2,
                      0x071 << 2],
            bitOffset = [0, 0, 0],
            bitSize = [16, 16, 16],
            mode = mode,
            name = 'PCS_RSVD_ATTR'))

        # Yes, this one is weird
        self.add(pr.RemoteVariable(
            offset = [0x074 << 2,
                      0x074 << 2,
                      0x07F << 2,
                      0x07F << 2,
                      0x083 << 2,
                      0x08C << 2],
            bitOffset = [0, 11, 0, 10, 7, 3],
            bitSize = [4, 5, 4, 5, 9, 5],
            mode = mode,
            name = 'RX_DFE_KL_CFG2'))

        self.add(pr.RemoteVariable(
            offset = 0x075 << 2,
            bitOffset = 8,
            mode = mode,
            name = 'TX_MARGIN_FULL_1',
            bitSize = 7))

        self.add(pr.RemoteVariable(
            offset = 0x075 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'TX_MARGIN_FULL_0',
            bitSize = 7))

        self.add(pr.RemoteVariable(
            offset = 0x076 << 2,
            bitOffset = 8,
            mode = mode,
            name = 'TX_MARGIN_FULL_3',
            bitSize = 7))

        self.add(pr.RemoteVariable(
            offset = 0x076 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'TX_MARGIN_FULL_2',
            bitSize = 7))

        self.add(pr.RemoteVariable(
            offset = 0x077 << 2,
            bitOffset = 8,
            mode = mode,
            name = 'TX_MARGIN_LOW_0',
            bitSize = 7))

        self.add(pr.RemoteVariable(
            offset = 0x077 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'TX_MARGIN_FULL_4',
            bitSize = 7))

        self.add(pr.RemoteVariable(
            offset = 0x078 << 2,
            bitOffset = 8,
            mode = mode,
            name = 'TX_MARGIN_LOW_2',
            bitSize = 7))

        self.add(pr.RemoteVariable(
            offset = 0x078 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'TX_MARGIN_LOW_1',
            bitSize = 7))

        self.add(pr.RemoteVariable(
            offset = 0x079 << 2,
            bitOffset = 8,
            mode = mode,
            name = 'TX_MARGIN_LOW_4',
            bitSize = 7))

        self.add(pr.RemoteVariable(
            offset = 0x079 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'TX_MARGIN_LOW_3',
            bitSize = 7))

        self.add(pr.RemoteVariable(
            offset = 0x07A << 2,
            bitOffset = 8,
            mode = mode,
            name = 'TX_DEEMPH1',
            bitSize = 5))

        self.add(pr.RemoteVariable(
            offset = 0x07A << 2,
            bitOffset = 0,
            mode = mode,
            name = 'TX_DEEMPH0',
            bitSize = 5))

        self.add(pr.RemoteVariable(
            offset = 0x07C << 2,
            bitOffset = 8,
            mode = mode,
            name = 'TX_RXDETECT_REF',
            bitSize = 3))

        self.add(pr.RemoteVariable(
            offset = 0x07C << 2,
            bitOffset = 3,
            mode = mode,
            name = 'TX_MAINCURSOR_SEL',
            bitSize = 1))

        self.add(pr.RemoteVariable(
            offset = 0x07C << 2,
            bitOffset = 0,
            mode = mode,
            name = 'PMA_RSV3',
            bitSize = 2))

        self.add(pr.RemoteVariable(
            offset = 0x07D << 2,
            bitOffset = 0,
            mode = mode,
            name = 'TX_RXDETECT_CFG',
            bitSize = 14))

        self.add(pr.RemoteVariable(
            offset = 0x082 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'PMA_RSV2',
            bitSize = 16))

        self.add(pr.RemoteVariable(
            offset = [0x086 << 2,
                      0x087 << 2],
            bitOffset = [0, 0],
            bitSize = [16, 8],
            mode = mode,
            name = 'DMONITOR_CFG'))

        self.add(pr.RemoteVariable(
            offset = 0x088 << 2,
            bitOffset = 4,
            bitSize = 3,
            mode = mode,
            name = 'TXOUT_DIV',
            enum = {
                0: '1',
                1: '2',
                2: '4',
                3: '8',
                4: '16'}))

        self.add(pr.RemoteVariable(
            offset = 0x088 << 2,
            bitOffset = 0,
            bitSize = 3,
            mode = mode,
            name = 'RXOUT_DIV',
            enum = {
                0: '1',
                1: '2',
                2: '4',
                3: '8',
                4: '16'}))

        self.add(pr.RemoteVariable(
            offset = [0x091 << 2,
                      0x092 << 2],
            bitOffset = [0, 0],
            mode = mode,
            name = 'PMA_RSV4',
            bitSize = [16, 16]))

        self.add(pr.RemoteVariable(
            offset = [0x097 << 2,
                      0x098 << 2],
            bitOffset = [0, 0],
            bitSize = [16, 16],
            mode = mode,
            name = 'TST_RSV'))


        self.add(pr.RemoteVariable(
            offset = [0x099 << 2,
                      0x09A << 2],
            bitOffset = [0, 0],
            bitSize = [16, 16],
            mode = mode,
            name = 'PNA_RSV'))


        self.add(pr.RemoteVariable(
            offset = 0x09B << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RX_BUFFER_CFG',
            bitSize = 6))

        self.add(pr.RemoteVariable(
            offset = 0x09C << 2,
            bitOffset = 8,
            mode = mode,
            name = 'RXBUF_THRESH_OVFLW',
            bitSize = 6))

        self.add(pr.RemoteVariable(
            offset = 0x09C << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RXBUF_THRESH_UNDFLW',
            bitSize = 6))

        self.add(pr.RemoteVariable(
            offset = 0x09D << 2,
            bitOffset = 12,
            mode = mode,
            name = 'RXBUF_EIDLE_HI_CNT',
            bitSize = 4))

        self.add(pr.RemoteVariable(
            offset = 0x09D << 2,
            bitOffset = 8,
            mode = mode,
            name = 'RXBUF_EIDLE_LO_CNT',
            bitSize = 4))

        self.add(pr.RemoteVariable(
            offset = 0x09D << 2,
            bitOffset = 7,
            mode = mode,
            name = 'RXBUF_ADDR_MODE',
            enum = {
                0: 'FULL',
                1: 'FAST'},
            bitSize = 1))

        self.add(pr.RemoteVariable(
            offset = 0x09D << 2,
            bitOffset = 6,
            mode = mode,
            name = 'RXBUF_RESET_ON_EIDLE',
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x09D << 2,
            bitOffset = 5,
            mode = mode,
            name = 'RXBUF_RESET_ON_CB_CHANGE',
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x09D << 2,
            bitOffset = 4,
            mode = mode,
            name = 'RXBUF_RESET_ON_RATE_CHANGE',
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x09D << 2,
            bitOffset = 3,
            mode = mode,
            name = 'RXBUF_RESET_ON_COMMAALIGN',
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x09D << 2,
            bitOffset = 2,
            mode = mode,
            name = 'RXBUF_THRESH_OVRD',
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x09D << 2,
            bitOffset = 1,
            mode = mode,
            name = 'RXBUF_EN',
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x09D << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RX_DEFER_RESET_BUF_EN',
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x09F << 2,
            bitOffset = 0,
            mode = mode,
            name = 'TXDLY_LCFG',
            bitSize = 9))

        self.add(pr.RemoteVariable(
            offset = 0x0A0 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RXDLY_LCFG',
            bitSize = 9))

        self.add(pr.RemoteVariable(
            offset = [0x0A1 << 2,
                      0x0A2 << 2],
            bitOffset = [0, 0],
            bitSize = [16, 8],
            mode = mode,
            name = 'RXPH_CFG'))


        self.add(pr.RemoteVariable(
            offset = [0x0A3 << 2,
                      0x0A4 << 2],
            bitOffset = [0, 0],
            bitSize = [16, 8],
            mode = mode,
            name = 'RXPHDLY_CFG'))

        self.add(pr.RemoteVariable(
            offset = 0x0A5 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RX_DEBUG_CFG',
            bitSize = 12))

        self.add(pr.RemoteVariable(
            offset = 0x0A6 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'ES_PMA_CFG',
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x0A7 << 2,
            bitOffset = 13,
            mode = mode,
            name = 'RXCDR_PH_RESET_ON_EIDLE',
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x0A7 << 2,
            bitOffset = 12,
            mode = mode,
            name = 'RXCDR_FR_RESET_ON_EIDLE',
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x0A7 << 2,
            bitOffset = 11,
            mode = mode,
            name = 'RXCDR_HOLD_DURING_EIDLE',
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x0A7 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RXCDR_LOCK_CFG',
            bitSize = 6))

        self.add(pr.RemoteVariable(
            offset = [0x0A8 << 2,
                      0x0A9 << 2,
                      0x0AA << 2,
                      0x0AB << 2,
                      0x0AC << 2],
            bitOffset = [0, 0, 0, 0, 0],
            bitSize = [16, 16, 16, 16, 8],
            mode = mode,
            name = 'RXCDR_CFG'))

        self.add(pr.RemoteVariable(
            offset = 0x14E << 2,
            bitOffset = 0,
            mode = mode,
            name = 'COMMA_ALIGN_LATENCY',
            bitSize = 7))

        self.add(pr.RemoteVariable(
            offset = 0x15C << 2,
            bitOffset = 0,
            mode = 'RO',
            name = 'RX_PRBS_ERR_CNT',
            bitSize = 16))
