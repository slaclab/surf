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
            description = "Clear microcode error flag",
            bitSize = 1))

        self.add(pr.RemoteVariable(
            offset = [0x00D << 2, 0x00E <<2],
            bitOffset = [15, 0],
            bitSize = [1, 6],
            mode = mode,
            name = 'RXDFELPMRESET_TIME',
            description = "RX DFE LPM reset duration timer"))

        self.add(pr.RemoteVariable(
            offset = 0x00D << 2,
            bitOffset = 10,
            mode = mode,
            name = 'RXCDRPHRESET_TIME',
            description = "RX CDR phase reset duration timer",
            bitSize = 5))

        self.add(pr.RemoteVariable(
            offset = 0x00D << 2,
            bitOffset = 5,
            mode = mode,
            name = 'RXCDRFREQRESET_TIME',
            description = "RX CDR frequency reset duration timer",
            bitSize = 5))

        self.add(pr.RemoteVariable(
            offset = 0x00D << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RXBUFRESET_TIME',
            description = "RX buffer reset duration timer",
            bitSize = 5))

        self.add(pr.RemoteVariable(
            offset = 0x00E << 2,
            bitOffset = 11,
            mode = mode,
            name = 'RXPCSRESET_TIME',
            description = "RX PCS reset duration timer",
            bitSize = 5))

        self.add(pr.RemoteVariable(
            offset = 0x00E << 2,
            bitOffset = 6,
            mode = mode,
            name = 'RXPMARESET_TIME',
            description = "RX PMA reset duration timer",
            bitSize = 5))

        self.add(pr.RemoteVariable(
            offset = 0x00F << 2,
            bitOffset = 10,
            mode = mode,
            name = 'RXISCANRESET_TIME',
            description = "RX I-scan reset duration timer",
            bitSize = 5))

        self.add(pr.RemoteVariable(
            offset = 0x00F << 2,
            bitOffset = 5,
            mode = mode,
            name = 'TXPCSRESET_TIME',
            description = "TX PCS reset duration timer",
            bitSize = 5))

        self.add(pr.RemoteVariable(
            offset = 0x00F << 2,
            bitOffset = 0,
            mode = mode,
            name = 'TXPMARESET_TIME',
            description = "TX PMA reset duration timer",
            bitSize = 5))

        self.add(pr.RemoteVariable(
            offset = 0x011 << 2,
            bitOffset = 14,
            mode = mode,
            name = 'RX_INT_DATAWIDTH',
            description = "RX internal datapath width selection (2-byte or 4-byte)",
            bitSize = 1,
            enum = {
                0: '2-byte',
                1: '4-byte'}))

        self.add(pr.RemoteVariable(
            offset = 0x011 << 2,
            bitOffset = 11,
            mode = mode,
            name = 'RX_DATA_WIDTH',
            description = "RX user data width in bits",
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
            description = "RX 25 MHz clock divider setting",
            bitSize = 5,
            enum = {x:f'{x+1}' for x in range(32)}))

        self.add(pr.RemoteVariable(
            offset = 0x011 << 2,
            bitOffset = 4,
            mode = mode,
            name = 'RX_CM_SEL',
            description = "RX common-mode voltage source selection",
            bitSize = 2))

        self.add(pr.RemoteVariable(
            offset = 0x011 << 2,
            bitOffset = 1,
            mode = mode,
            name = 'RX_CM_TRIM',
            description = "RX common-mode voltage trim adjustment",
            bitSize = 3))

        self.add(pr.RemoteVariable(
            offset = 0x011 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RXPRBS_ERR_LOOPBACK',
            description = "Route RX PRBS error output to loopback path",
            bitSize = 1))

        self.add(pr.RemoteVariable(
            offset = 0x012 << 2,
            bitOffset = 12,
            mode = mode,
            name = 'SATA_BURST_SEQ_LEN',
            description = "SATA burst sequence length setting",
            bitSize = 4))

        self.add(pr.RemoteVariable(
            offset = 0x012 << 2,
            bitOffset = 10,
            mode = mode,
            name = 'OUTREFCLK_SEL_INV',
            description = "Output reference clock polarity inversion control",
            bitSize = 2))

        self.add(pr.RemoteVariable(
            offset = 0x012 << 2,
            bitOffset = 7,
            mode = mode,
            name = 'SATA_BURST_VAL',
            description = "SATA burst primitive value encoding",
            bitSize = 3))

        self.add(pr.RemoteVariable(
            offset = 0x012 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RXOOB_CFG',
            description = "RX out-of-band signaling configuration",
            bitSize = 7))

        self.add(pr.RemoteVariable(
            offset = 0x013 << 2,
            bitOffset = 9,
            mode = mode,
            name = 'SAS_MIN_COM',
            description = "SAS minimum COMSAS primitive duration",
            bitSize = 6))

        self.add(pr.RemoteVariable(
            offset = 0x013 << 2,
            bitOffset = 3,
            mode = mode,
            name = 'SATA_MIN_BURST',
            description = "SATA minimum burst primitive duration",
            bitSize = 6))

        self.add(pr.RemoteVariable(
            offset = 0x013 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'SATA_EIDLE_VAL',
            description = "SATA electrical idle primitive value encoding",
            bitSize = 3))

        self.add(pr.RemoteVariable(
            offset = 0x014 << 2,
            bitOffset = 6,
            mode = mode,
            name = 'SATA_MIN_WAKE',
            description = "SATA minimum wake primitive duration",
            bitSize = 6))

        self.add(pr.RemoteVariable(
            offset = 0x014 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'SATA_MIN_INIT',
            description = "SATA minimum COMINIT primitive duration",
            bitSize = 6))

        self.add(pr.RemoteVariable(
            offset = 0x015 << 2,
            bitOffset = 6,
            mode = mode,
            name = 'SAS_MAX_COM',
            description = "SAS maximum COMSAS primitive duration",
            bitSize = 7))

        self.add(pr.RemoteVariable(
            offset = 0x015 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'SATA_MAX_BURST',
            description = "SATA maximum burst primitive duration",
            bitSize = 6))

        self.add(pr.RemoteVariable(
            offset = 0x016 << 2,
            bitOffset = 6,
            mode = mode,
            name = 'SATA_MAX_WAKE',
            description = "SATA maximum wake primitive duration",
            bitSize = 6))

        self.add(pr.RemoteVariable(
            offset = 0x016 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'SATA_MAX_INIT',
            description = "SATA maximum COMINIT primitive duration",
            bitSize = 6))

        self.add(pr.RemoteVariable(
            offset = 0x018 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'TRANS_TIME_RATE',
            description = "Power state transition time rate control",
            bitSize = 8))

        self.add(pr.RemoteVariable(
            offset = 0x019 << 2,
            bitOffset = 12,
            mode = mode,
            name = 'TX_PREDRIVER_MODE',
            description = "TX pre-driver operating mode selection",
            bitSize = 1))

        self.add(pr.RemoteVariable(
            offset = 0x019 << 2,
            bitOffset = 9,
            mode = mode,
            name = 'TX_EIDLE_DEASSERT_DELAY',
            description = "TX electrical idle de-assertion delay",
            bitSize = 3))

        self.add(pr.RemoteVariable(
            offset = 0x019 << 2,
            bitOffset = 6,
            mode = mode,
            name = 'TX_EIDLE_ASSERT_DELAY',
            description = "TX electrical idle assertion delay",
            bitSize = 3))

        self.add(pr.RemoteVariable(
            offset = 0x019 << 2,
            bitOffset = 5,
            mode = mode,
            name = 'TX_LOOPBACK_DRIVE_HIZ',
            description = "Drive TX output to high-impedance during loopback",
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x019 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'TX_DRIVE_MODE',
            description = "TX output driver mode selection",
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
            description = "Power-down transition time to P2 state",
            bitSize = 8))

        self.add(pr.RemoteVariable(
            offset = 0x01A << 2,
            bitOffset = 0,
            mode = mode,
            name = 'PD_TRANS_TIME_NONE_P2',
            description = "Power-down transition time to non-P2 state",
            bitSize = 8))

        self.add(pr.RemoteVariable(
            offset = 0x01B << 2,
            bitOffset = 1,
            mode = mode,
            name = 'PD_TRANS_TIME_FROM_P2',
            description = "Power-down transition time from P2 state",
            bitSize = 12))

        self.add(pr.RemoteVariable(
            offset = 0x01B << 2,
            bitOffset = 0,
            mode = mode,
            name = 'PCS_PCIE_EN',
            description = "Enable PCS PCIe mode",
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x01C << 2,
            bitOffset = 15,
            mode = mode,
            name = 'TXBUF_RESET_ON_RATE_CHANGE',
            description = "Reset TX buffer on line rate change",
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x01C << 2,
            bitOffset = 14,
            mode = mode,
            name = 'TXBUF_EN',
            description = "Enable TX elastic buffer",
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x01C << 2,
            bitOffset = 5,
            mode = mode,
            name = 'TXGEARBOX_EN',
            description = "Enable TX gearbox for 64b/66b or 64b/67b encoding",
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x01C << 2,
            bitOffset = 0,
            mode = mode,
            name = 'GEARBOX_MODE',
            description = "Gearbox operating mode selection",
            bitSize = 3))

        self.add(pr.RemoteVariable(
            offset = [0x01D << 2, 0x01E << 2],
            bitOffset = [0, 0],
            bitSize = [16, 7],
            mode = mode,
            name = 'RX_DFE_GAIN_CFG',
            description = "RX DFE gain configuration register"))

        self.add(pr.RemoteVariable(
            offset = 0x01E << 2,
            bitOffset = 14,
            mode = mode,
            name = 'RX_DFE_LPM_HOLD_DURING_EIDLE',
            description = "Hold RX DFE LPM adaptation during electrical idle",
            bitSize = 1))

        self.add(pr.RemoteVariable(
            offset = 0x01F << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RX_DFE_H2_CFG',
            description = "RX DFE H2 tap coefficient configuration",
            bitSize = 12))

        self.add(pr.RemoteVariable(
            offset = 0x020 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RX_DFE_H3_CFG',
            description = "RX DFE H3 tap coefficient configuration",
            bitSize = 12))

        self.add(pr.RemoteVariable(
            offset = 0x021 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RX_DFE_H4_CFG',
            description = "RX DFE H4 tap coefficient configuration",
            bitSize = 11))

        self.add(pr.RemoteVariable(
            offset = 0x022 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RX_DFE_H5_CFG',
            description = "RX DFE H5 tap coefficient configuration",
            bitSize = 11))

        self.add(pr.RemoteVariable(
            offset = 0x023 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RX_DFE_KL_CFG',
            description = "RX DFE K/L adaptation loop configuration",
            bitSize = 13))

        self.add(pr.RemoteVariable(
            offset = [0x024 << 2, 0x025 <<2],
            bitOffset = [15, 0],
            bitSize = [1, 16],
            mode = mode,
            name = 'RX_DFE_UT_CFG',
            description = "RX DFE unidirectional tap configuration"))

        self.add(pr.RemoteVariable(
            offset = 0x024 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RX_OS_CFG',
            description = "RX offset cancellation configuration",
            bitSize = 13))

        self.add(pr.RemoteVariable(
            offset = [0x026 << 2, 0x027 << 2],
            bitOffset = [0, 0],
            bitSize = [16, 1],
            mode = mode,
            name = 'RX_DFE_VP_CFG',
            description = "RX DFE voltage probe configuration"))

        self.add(pr.RemoteVariable(
            offset = 0x028 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RX_DFE_XYD_CFG',
            description = "RX DFE XY-detector configuration",
            bitSize = 13))

        self.add(pr.RemoteVariable(
            offset = 0x029 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RX_DFE_LPM_CFG',
            description = "RX DFE low-power mode configuration",
            bitSize = 16))

        self.add(pr.RemoteVariable(
            offset = 0x02A << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RXLPM_HF_CFG',
            description = "RX LPM high-frequency path configuration",
            bitSize = 14))

        self.add(pr.RemoteVariable(
            offset = 0x02B << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RXLPM_LF_CFG',
            description = "RX LPM low-frequency path configuration",
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
            name = 'ES_QUALIFIER',
            description = "Eye scan qualifier pattern for error counting"))

        self.add(pr.RemoteVariable(
            offset = [0x031 << 2,
                      0x032 << 2,
                      0x033 << 2,
                      0x034 << 2,
                      0x035 << 2],
            bitOffset = [0, 0, 0, 0, 0],
            bitSize = [16, 16, 16, 16, 16],
            mode = mode,
            name = 'ES_QUAL_MASK',
            description = "Eye scan qualifier mask pattern"))

        self.add(pr.RemoteVariable(
            offset = [0x036 << 2,
                      0x037 << 2,
                      0x038 << 2,
                      0x039 << 2,
                      0x03A << 2],
            bitOffset = [0, 0, 0, 0, 0],
            bitSize = [16, 16, 16, 16, 16],
            mode = mode,
            name = 'ES_SDATA_MASK',
            description = "Eye scan sample data mask pattern"))

        self.add(pr.RemoteVariable(
            offset = 0x03B << 2,
            bitOffset = 11,
            mode = mode,
            name = 'ES_PRESCALE',
            description = "Eye scan error count prescale factor",
            bitSize = 5))

        self.add(pr.RemoteVariable(
            offset = 0x03B << 2,
            bitOffset = 0,
            mode = mode,
            name = 'ES_VERT_OFFSET',
            description = "Eye scan vertical offset setting",
            bitSize = 9))

        self.add(pr.RemoteVariable(
            offset = 0x03C << 2,
            bitOffset = 0,
            mode = mode,
            name = 'ES_HORZ_OFFSET',
            description = "Eye scan horizontal offset setting",
            bitSize = 12))

        self.add(pr.RemoteVariable(
            offset = 0x03D << 2,
            bitOffset = 15,
            mode = mode,
            name = 'RX_DISPERR_SEQ_MATCH',
            description = "Enable RX disparity error sequence matching",
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x03D << 2,
            bitOffset = 14,
            mode = mode,
            name = 'DEC_PCOMMA_DETECT',
            description = "Enable positive comma detection in 8b/10b decoder",
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x03D << 2,
            bitOffset = 13,
            mode = mode,
            name = 'DEC_MCOMMA_DETECT',
            description = "Enable negative comma detection in 8b/10b decoder",
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x03D << 2,
            bitOffset = 12,
            mode = mode,
            name = 'DEC_VALID_COMMA_ONLY',
            description = "Use only valid comma characters for alignment",
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x03D << 2,
            bitOffset = 9,
            mode = mode,
            name = 'ES_ERRDET_EN',
            description = "Enable eye scan error detection",
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x03D << 2,
            bitOffset = 8,
            mode = mode,
            name = 'ES_EYE_SCAN_EN',
            description = "Enable eye scan functionality",
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x03D << 2,
            bitOffset = 0,
            mode = mode,
            name = 'ES_CONTROL',
            description = "Eye scan control and mode settings",
            bitSize = 6))

        self.add(pr.RemoteVariable(
            offset = 0x03E << 2,
            bitOffset = 0,
            mode = mode,
            name = 'ALIGN_COMMA_ENABLE',
            description = "Comma alignment enable mask for each bit position",
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x03F << 2,
            bitOffset = 0,
            mode = mode,
            name = 'ALIGN_MCOMMA_VALUE',
            description = "Negative comma (K28.7) alignment pattern value",
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x040 << 2,
            bitOffset = 14,
            mode = mode,
            name = 'RXSLIDE_MODE',
            description = "RX slide mode selection for bit alignment",
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
            description = "Positive comma (K28.5) alignment pattern value",
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x041 << 2,
            bitOffset = 13,
            mode = mode,
            name = 'ALIGN_COMMA_WORD',
            description = "Number of words over which comma alignment is performed",
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
            description = "RX signal valid delay count before asserting RXVALID",
            bitSize = 5,
            enum = {x: f'{x+1}' for x in range(32)}))

        self.add(pr.RemoteVariable(
            offset = 0x041 << 2,
            bitOffset = 7,
            mode = mode,
            name = 'ALIGN_PCOMMA_DET',
            description = "Enable positive comma detection for alignment",
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x041 << 2,
            bitOffset = 6,
            mode = mode,
            name = 'ALIGN_MCOMMA_DET',
            description = "Enable negative comma detection for alignment",
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x041 << 2,
            bitOffset = 5,
            mode = mode,
            name = 'SHOW_REALIGN_COMMA',
            description = "Output realignment comma to user data path",
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x041 << 2,
            bitOffset = 4,
            mode = mode,
            name = 'ALIGN_COMMA_DOUBLE',
            description = "Use double-width comma alignment for 20/40-bit data width",
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x041 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RXSLIDE_AUTO_WAIT',
            description = "Wait cycles between automatic RX slide operations",
            bitSize = 4))

        self.add(pr.RemoteVariable(
            offset = 0x044 << 2,
            bitOffset = 14,
            mode = mode,
            name = 'CLK_CORRECT_USE',
            description = "Enable clock correction sequence insertion/deletion",
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x044 << 2,
            bitOffset = 10,
            mode = mode,
            name = 'CLK_COR_SEQ_1_ENABLE',
            description = "Clock correction sequence 1 character enable mask",
            bitSize = 4))

        self.add(pr.RemoteVariable(
            offset = 0x044 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'CLK_COR_SEQ_1_1',
            description = "Clock correction sequence 1 character 1 value",
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x045 << 2,
            bitOffset = 10,
            mode = mode,
            name = 'CLK_COR_MAX_LAT',
            description = "Clock correction maximum latency threshold",
            bitSize = 6))

        self.add(pr.RemoteVariable(
            offset = 0x045 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'CLK_COR_SEQ_1_2',
            description = "Clock correction sequence 1 character 2 value",
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x046 << 2,
            bitOffset = 10,
            mode = mode,
            name = 'CLK_COR_MIN_LAT',
            description = "Clock correction minimum latency threshold",
            bitSize = 6))

        self.add(pr.RemoteVariable(
            offset = 0x046 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'CLK_COR_SEQ_1_3',
            description = "Clock correction sequence 1 character 3 value",
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x047 << 2,
            bitOffset = 10,
            mode = mode,
            name = 'CLK_COR_REPEAT_WAIT',
            description = "Wait cycles between repeated clock correction insertions",
            bitSize = 5))

        self.add(pr.RemoteVariable(
            offset = 0x047 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'CLK_COR_SEQ_1_4',
            description = "Clock correction sequence 1 character 4 value",
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x048 << 2,
            bitOffset = 14,
            mode = mode,
            name = 'CLK_COR_SEQ_2_USE',
            description = "Enable use of clock correction sequence 2",
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x048 << 2,
            bitOffset = 10,
            mode = mode,
            name = 'CLK_COR_SEQ_2_ENABLE',
            description = "Clock correction sequence 2 character enable mask",
            bitSize = 4))

        self.add(pr.RemoteVariable(
            offset = 0x048 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'CLK_COR_SEQ_2_1',
            description = "Clock correction sequence 2 character 1 value",
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x049 << 2,
            bitOffset = 13,
            mode = mode,
            name = 'CLK_COR_KEEP_IDLE',
            description = "Keep RX buffer at idle fill level during clock correction",
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x049 << 2,
            bitOffset = 12,
            mode = mode,
            name = 'CLK_COR_PRECEDENCE',
            description = "Clock correction sequence 1 takes precedence over sequence 2",
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x049 << 2,
            bitOffset = 10,
            mode = mode,
            name = 'CLK_COR_SEQ_LEN',
            description = "Clock correction sequence length in characters",
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
            description = "Clock correction sequence 2 character 2 value",
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x04A << 2,
            bitOffset = 0,
            mode = mode,
            name = 'CLK_COR_SEQ_2_3',
            description = "Clock correction sequence 2 character 3 value",
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x04B << 2,
            bitOffset = 15,
            mode = mode,
            name = 'RXGEARBOX_EN',
            description = "Enable RX gearbox for 64b/66b or 64b/67b decoding",
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x04B << 2,
            bitOffset = 0,
            mode = mode,
            name = 'CLK_COR_SEQ_2_4',
            description = "Clock correction sequence 2 character 4 value",
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x04C << 2,
            bitOffset = 12,
            mode = mode,
            name = 'CHAN_BOND_SEQ_1_ENABLE',
            description = "Channel bonding sequence 1 character enable mask",
            bitSize = 4))

        self.add(pr.RemoteVariable(
            offset = 0x04C << 2,
            bitOffset = 0,
            mode = mode,
            name = 'CHAN_BOND_SEQ_1_1',
            description = "Channel bonding sequence 1 character 1 value",
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x04D << 2,
            bitOffset = 14,
            mode = mode,
            name = 'CHAN_BOND_SEQ_LEN',
            description = "Channel bonding sequence length in characters",
            bitSize = 2,
            enum = {x:f'{x+1}' for x in range(4)}))

        self.add(pr.RemoteVariable(
            offset = 0x04D << 2,
            bitOffset = 0,
            mode = mode,
            name = 'CHAN_BOND_SEQ_1_2',
            description = "Channel bonding sequence 1 character 2 value",
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x04E << 2,
            bitOffset = 15,
            mode = mode,
            name = 'CHAN_BOND_KEEP_ALIGN',
            description = "Maintain channel bonding alignment after initial lock",
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x04E << 2,
            bitOffset = 0,
            mode = mode,
            name = 'CHAN_BOND_SEQ_1_3',
            description = "Channel bonding sequence 1 character 3 value",
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x04F << 2,
            bitOffset = 0,
            mode = mode,
            name = 'CHAN_BOND_SEQ_1_4',
            description = "Channel bonding sequence 1 character 4 value",
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x050 << 2,
            bitOffset = 12,
            mode = mode,
            name = 'CHAN_BOND_SEQ_2_ENABLE',
            description = "Channel bonding sequence 2 character enable mask",
            bitSize = 4))

        self.add(pr.RemoteVariable(
            offset = 0x050 << 2,
            bitOffset = 11,
            mode = mode,
            name = 'CHAN_BOND_SEQ_2_USE',
            description = "Enable use of channel bonding sequence 2",
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x050 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'CHAN_BOND_SEQ_2_1',
            description = "Channel bonding sequence 2 character 1 value",
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x051 << 2,
            bitOffset = 12,
            mode = mode,
            name = 'FTS_LANE_DESKEW_CFG',
            description = "FTS lane deskew configuration for PCIe",
            bitSize = 4))

        self.add(pr.RemoteVariable(
            offset = 0x051 << 2,
            bitOffset = 11,
            mode = mode,
            name = 'FTS_LANE_DESKEW_EN',
            description = "Enable FTS-based lane deskew for PCIe Gen 2",
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x051 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'CHAN_BOND_SEQ_2_2',
            description = "Channel bonding sequence 2 character 2 value",
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x052 << 2,
            bitOffset = 12,
            mode = mode,
            name = 'FTS_DESKEW_SEQ_ENABLE',
            description = "FTS deskew sequence character enable mask",
            bitSize = 4))

        self.add(pr.RemoteVariable(
            offset = 0x052 << 2,
            bitOffset = 11,
            mode = mode,
            name = 'CBCC_DATA_SOURCE_SEL',
            description = "Channel bonding comma code data source selection",
            bitSize = 1,
            enum = {
                0: 'ENCODED',
                1: 'DECODED'}))

        self.add(pr.RemoteVariable(
            offset = 0x052 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'CHAN_BOND_SEQ_2_3',
            description = "Channel bonding sequence 2 character 3 value",
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x053 << 2,
            bitOffset = 12,
            mode = mode,
            name = 'CHAN_BOND_MAX_SKEW',
            description = "Maximum allowed lane skew for channel bonding",
            bitSize = 4,
            value = 1,
            enum = {x:f'{x}' for x in range(1, 15)}))

        self.add(pr.RemoteVariable(
            offset = 0x053 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'CHAN_BOND_SEQ_2_4',
            description = "Channel bonding sequence 2 character 4 value",
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x054 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RXDLY_TAP_CFG',
            description = "RX delay tap configuration register",
            bitSize = 16))

        self.add(pr.RemoteVariable(
            offset = 0x055 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RXDLY_CFG',
            description = "RX delay line configuration register",
            bitSize = 16))

        self.add(pr.RemoteVariable(
            offset = 0x057 << 2,
            bitOffset = 8,
            mode = mode,
            name = 'RXPH_MONITOR_SEL',
            description = "RX phase monitor output selection",
            bitSize = 5))

        self.add(pr.RemoteVariable(
            offset = 0x057 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RX_DDI_SEL',
            description = "RX decision-directed interpolation selection",
            bitSize = 6))

        self.add(pr.RemoteVariable(
            offset = 0x059 << 2,
            bitOffset = 7,
            mode = mode,
            name = 'TX_XCLK_SEL',
            description = "TX transmit clock source selection",
            bitSize = 1,
            enum = {
                0: 'TXOUT',
                1: 'TXUSR'}))

        self.add(pr.RemoteVariable(
            offset = 0x059 << 2,
            bitOffset = 6,
            mode = mode,
            name = 'RX_XCLK_SEL',
            description = "RX recovered clock source selection",
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
            name = 'CPLL_INIT_CFG',
            description = "CPLL initialization configuration register"))

        self.add(pr.RemoteVariable(
            offset = [0x05C << 2,
                      0x05D << 2],
            bitOffset = [8, 0],
            bitSize = [8, 16],
            mode = mode,
            name = 'CPLL_CFG',
            description = "CPLL configuration register"))

        self.add(pr.RemoteVariable(
            offset = 0x05E << 2,
            bitOffset = 14,
            mode = mode,
            name = 'SATA_CPLL_CFG',
            description = "SATA CPLL VCO frequency range selection",
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
            description = "CPLL reference clock pre-divider ratio",
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
            description = "CPLL feedback divider 4/5 selection",
            bitSize = 1,
            enum = {
                0: '4',
                1: '5'}))

        self.add(pr.RemoteVariable(
            offset = 0x05E << 2,
            bitOffset = 0,
            mode = mode,
            name = 'CPLL_FBDIV',
            description = "CPLL feedback divider ratio",
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
            description = "CPLL lock detection configuration register",
            bitSize = 16))

        self.add(pr.RemoteVariable(
            offset = [0x060 << 2, 0x061 << 2],
            bitOffset = [0, 0],
            bitSize = [16, 8],
            mode = mode,
            name = 'TXPHDLY_CFG',
            description = "TX phase delay line configuration register"))

        self.add(pr.RemoteVariable(
            offset = 0x062 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'TXDLY_CFG',
            description = "TX delay line configuration register",
            bitSize = 16))

        self.add(pr.RemoteVariable(
            offset = 0x063 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'TXDLY_TAP_CFG',
            description = "TX delay tap configuration register",
            bitSize = 16))

        self.add(pr.RemoteVariable(
            offset = 0x064 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'TXPH_CFG',
            description = "TX phase alignment configuration register",
            bitSize = 16))

        self.add(pr.RemoteVariable(
            offset = 0x065 << 2,
            bitOffset = 8,
            mode = mode,
            name = 'TXPH_MONITOR_SEL',
            description = "TX phase monitor output selection",
            bitSize = 5))

        self.add(pr.RemoteVariable(
            offset = 0x066 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RX_BIAS_CFG',
            description = "RX analog bias and current configuration",
            bitSize = 12))

        self.add(pr.RemoteVariable(
            offset = 0x068 << 2,
            bitOffset = 1,
            mode = mode,
            name = 'TX_CLKMUX_PD',
            description = "Power down TX clock multiplexer",
            bitSize = 1))

        self.add(pr.RemoteVariable(
            offset = 0x068 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RX_CLKMUX_PD',
            description = "Power down RX clock multiplexer",
            bitSize = 1))

        self.add(pr.RemoteVariable(
            offset = 0x069 << 2,
            bitOffset = 8,
            mode = mode,
            name = 'TERM_RCAL_OVRD',
            description = "Override termination resistor calibration value",
            bitSize = 1))

        self.add(pr.RemoteVariable(
            offset = 0x069 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'TERM_RCAL_CFG',
            description = "Termination resistor calibration configuration",
            bitSize = 5))

        self.add(pr.RemoteVariable(
            offset = 0x06A << 2,
            bitOffset =0,
            mode = mode,
            name = 'TX_CLKDIV_25',
            description = "TX 25 MHz clock divider setting",
            bitSize = 5,
            enum = {x:f'{x+1}' for x in range(32)}))

        self.add(pr.RemoteVariable(
            offset = 0x06B << 2,
            bitOffset = 15,
            mode = mode,
            name = 'TX_QPI_STATUS_EN',
            description = "Enable TX QPI status output",
            bitSize = 1))

        self.add(pr.RemoteVariable(
            offset = 0x06B << 2,
            bitOffset = 4,
            mode = mode,
            name = 'TX_INT_DATAWIDTH',
            description = "TX internal datapath width selection (2-byte or 4-byte)",
            bitSize = 1,
            enum = {
                0: '2-byte',
                1: '4-byte'}))

        self.add(pr.RemoteVariable(
            offset = 0x06B << 2,
            bitOffset = 0,
            mode = mode,
            name = 'TX_DATA_WIDTH',
            description = "TX user data width in bits",
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
            name = 'PCS_RSVD_ATTR',
            description = "PCS reserved attribute configuration register"))

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
            name = 'RX_DFE_KL_CFG2',
            description = "RX DFE K/L adaptation extended configuration register"))

        self.add(pr.RemoteVariable(
            offset = 0x075 << 2,
            bitOffset = 8,
            mode = mode,
            name = 'TX_MARGIN_FULL_1',
            description = "TX output swing margin preset 1 (full swing)",
            bitSize = 7))

        self.add(pr.RemoteVariable(
            offset = 0x075 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'TX_MARGIN_FULL_0',
            description = "TX output swing margin preset 0 (full swing)",
            bitSize = 7))

        self.add(pr.RemoteVariable(
            offset = 0x076 << 2,
            bitOffset = 8,
            mode = mode,
            name = 'TX_MARGIN_FULL_3',
            description = "TX output swing margin preset 3 (full swing)",
            bitSize = 7))

        self.add(pr.RemoteVariable(
            offset = 0x076 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'TX_MARGIN_FULL_2',
            description = "TX output swing margin preset 2 (full swing)",
            bitSize = 7))

        self.add(pr.RemoteVariable(
            offset = 0x077 << 2,
            bitOffset = 8,
            mode = mode,
            name = 'TX_MARGIN_LOW_0',
            description = "TX output swing margin preset 0 (low swing)",
            bitSize = 7))

        self.add(pr.RemoteVariable(
            offset = 0x077 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'TX_MARGIN_FULL_4',
            description = "TX output swing margin preset 4 (full swing)",
            bitSize = 7))

        self.add(pr.RemoteVariable(
            offset = 0x078 << 2,
            bitOffset = 8,
            mode = mode,
            name = 'TX_MARGIN_LOW_2',
            description = "TX output swing margin preset 2 (low swing)",
            bitSize = 7))

        self.add(pr.RemoteVariable(
            offset = 0x078 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'TX_MARGIN_LOW_1',
            description = "TX output swing margin preset 1 (low swing)",
            bitSize = 7))

        self.add(pr.RemoteVariable(
            offset = 0x079 << 2,
            bitOffset = 8,
            mode = mode,
            name = 'TX_MARGIN_LOW_4',
            description = "TX output swing margin preset 4 (low swing)",
            bitSize = 7))

        self.add(pr.RemoteVariable(
            offset = 0x079 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'TX_MARGIN_LOW_3',
            description = "TX output swing margin preset 3 (low swing)",
            bitSize = 7))

        self.add(pr.RemoteVariable(
            offset = 0x07A << 2,
            bitOffset = 8,
            mode = mode,
            name = 'TX_DEEMPH1',
            description = "TX de-emphasis level 1 setting",
            bitSize = 5))

        self.add(pr.RemoteVariable(
            offset = 0x07A << 2,
            bitOffset = 0,
            mode = mode,
            name = 'TX_DEEMPH0',
            description = "TX de-emphasis level 0 setting",
            bitSize = 5))

        self.add(pr.RemoteVariable(
            offset = 0x07C << 2,
            bitOffset = 8,
            mode = mode,
            name = 'TX_RXDETECT_REF',
            description = "TX receiver detection reference voltage setting",
            bitSize = 3))

        self.add(pr.RemoteVariable(
            offset = 0x07C << 2,
            bitOffset = 3,
            mode = mode,
            name = 'TX_MAINCURSOR_SEL',
            description = "TX main cursor amplitude selection",
            bitSize = 1))

        self.add(pr.RemoteVariable(
            offset = 0x07C << 2,
            bitOffset = 0,
            mode = mode,
            name = 'PMA_RSV3',
            description = "PMA reserved configuration register 3",
            bitSize = 2))

        self.add(pr.RemoteVariable(
            offset = 0x07D << 2,
            bitOffset = 0,
            mode = mode,
            name = 'TX_RXDETECT_CFG',
            description = "TX receiver detection configuration register",
            bitSize = 14))

        self.add(pr.RemoteVariable(
            offset = 0x082 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'PMA_RSV2',
            description = "PMA reserved configuration register 2",
            bitSize = 16))

        self.add(pr.RemoteVariable(
            offset = [0x086 << 2,
                      0x087 << 2],
            bitOffset = [0, 0],
            bitSize = [16, 8],
            mode = mode,
            name = 'DMONITOR_CFG',
            description = "Digital monitor output configuration register"))

        self.add(pr.RemoteVariable(
            offset = 0x088 << 2,
            bitOffset = 4,
            bitSize = 3,
            mode = mode,
            name = 'TXOUT_DIV',
            description = "TX output clock divider ratio",
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
            description = "RX output clock divider ratio",
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
            description = "PMA reserved configuration register 4",
            bitSize = [16, 16]))

        self.add(pr.RemoteVariable(
            offset = [0x097 << 2,
                      0x098 << 2],
            bitOffset = [0, 0],
            bitSize = [16, 16],
            mode = mode,
            name = 'TST_RSV',
            description = "Test reserved attribute register"))


        self.add(pr.RemoteVariable(
            offset = [0x099 << 2,
                      0x09A << 2],
            bitOffset = [0, 0],
            bitSize = [16, 16],
            mode = mode,
            name = 'PNA_RSV',
            description = "PNA reserved attribute register"))


        self.add(pr.RemoteVariable(
            offset = 0x09B << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RX_BUFFER_CFG',
            description = "RX elastic buffer configuration register",
            bitSize = 6))

        self.add(pr.RemoteVariable(
            offset = 0x09C << 2,
            bitOffset = 8,
            mode = mode,
            name = 'RXBUF_THRESH_OVFLW',
            description = "RX buffer overflow threshold level",
            bitSize = 6))

        self.add(pr.RemoteVariable(
            offset = 0x09C << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RXBUF_THRESH_UNDFLW',
            description = "RX buffer underflow threshold level",
            bitSize = 6))

        self.add(pr.RemoteVariable(
            offset = 0x09D << 2,
            bitOffset = 12,
            mode = mode,
            name = 'RXBUF_EIDLE_HI_CNT',
            description = "RX buffer electrical idle high count threshold",
            bitSize = 4))

        self.add(pr.RemoteVariable(
            offset = 0x09D << 2,
            bitOffset = 8,
            mode = mode,
            name = 'RXBUF_EIDLE_LO_CNT',
            description = "RX buffer electrical idle low count threshold",
            bitSize = 4))

        self.add(pr.RemoteVariable(
            offset = 0x09D << 2,
            bitOffset = 7,
            mode = mode,
            name = 'RXBUF_ADDR_MODE',
            description = "RX buffer address pointer mode selection",
            enum = {
                0: 'FULL',
                1: 'FAST'},
            bitSize = 1))

        self.add(pr.RemoteVariable(
            offset = 0x09D << 2,
            bitOffset = 6,
            mode = mode,
            name = 'RXBUF_RESET_ON_EIDLE',
            description = "Reset RX buffer when electrical idle is detected",
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x09D << 2,
            bitOffset = 5,
            mode = mode,
            name = 'RXBUF_RESET_ON_CB_CHANGE',
            description = "Reset RX buffer on channel bond sequence change",
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x09D << 2,
            bitOffset = 4,
            mode = mode,
            name = 'RXBUF_RESET_ON_RATE_CHANGE',
            description = "Reset RX buffer on line rate change",
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x09D << 2,
            bitOffset = 3,
            mode = mode,
            name = 'RXBUF_RESET_ON_COMMAALIGN',
            description = "Reset RX buffer after comma alignment completes",
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x09D << 2,
            bitOffset = 2,
            mode = mode,
            name = 'RXBUF_THRESH_OVRD',
            description = "Override RX buffer threshold with programmed values",
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x09D << 2,
            bitOffset = 1,
            mode = mode,
            name = 'RXBUF_EN',
            description = "Enable RX elastic buffer",
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x09D << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RX_DEFER_RESET_BUF_EN',
            description = "Enable deferred RX buffer reset on RXPMARESET",
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x09F << 2,
            bitOffset = 0,
            mode = mode,
            name = 'TXDLY_LCFG',
            description = "TX delay line loop configuration register",
            bitSize = 9))

        self.add(pr.RemoteVariable(
            offset = 0x0A0 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RXDLY_LCFG',
            description = "RX delay line loop configuration register",
            bitSize = 9))

        self.add(pr.RemoteVariable(
            offset = [0x0A1 << 2,
                      0x0A2 << 2],
            bitOffset = [0, 0],
            bitSize = [16, 8],
            mode = mode,
            name = 'RXPH_CFG',
            description = "RX phase alignment configuration register"))


        self.add(pr.RemoteVariable(
            offset = [0x0A3 << 2,
                      0x0A4 << 2],
            bitOffset = [0, 0],
            bitSize = [16, 8],
            mode = mode,
            name = 'RXPHDLY_CFG',
            description = "RX phase delay line configuration register"))

        self.add(pr.RemoteVariable(
            offset = 0x0A5 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RX_DEBUG_CFG',
            description = "RX debug configuration register",
            bitSize = 12))

        self.add(pr.RemoteVariable(
            offset = 0x0A6 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'ES_PMA_CFG',
            description = "Eye scan PMA configuration register",
            bitSize = 10))

        self.add(pr.RemoteVariable(
            offset = 0x0A7 << 2,
            bitOffset = 13,
            mode = mode,
            name = 'RXCDR_PH_RESET_ON_EIDLE',
            description = "Reset CDR phase on electrical idle detection",
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x0A7 << 2,
            bitOffset = 12,
            mode = mode,
            name = 'RXCDR_FR_RESET_ON_EIDLE',
            description = "Reset CDR frequency on electrical idle detection",
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x0A7 << 2,
            bitOffset = 11,
            mode = mode,
            name = 'RXCDR_HOLD_DURING_EIDLE',
            description = "Hold CDR lock during electrical idle",
            bitSize = 1,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            offset = 0x0A7 << 2,
            bitOffset = 0,
            mode = mode,
            name = 'RXCDR_LOCK_CFG',
            description = "RX CDR lock detection configuration",
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
            name = 'RXCDR_CFG',
            description = "RX CDR loop filter and bandwidth configuration"))

        self.add(pr.RemoteVariable(
            offset = 0x14E << 2,
            bitOffset = 0,
            mode = mode,
            name = 'COMMA_ALIGN_LATENCY',
            description = "Comma alignment latency in clock cycles",
            bitSize = 7))

        self.add(pr.RemoteVariable(
            offset = 0x15C << 2,
            bitOffset = 0,
            mode = 'RO',
            name = 'RX_PRBS_ERR_CNT',
            description = "RX PRBS error count readback",
            bitSize = 16))
