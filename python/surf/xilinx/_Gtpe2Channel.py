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

class Gtpe2Channel(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        ##############################
        # Variables
        ##############################

        self.add(pr.RemoteVariable(
            name        = "ACJTAG_RESET",
            description = "Reset the AC-coupled JTAG interface",
            offset      =  (0x0000<<2),
            bitSize     =  1,
            bitOffset   =  15,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ACJTAG_DEBUG_MODE",
            description = "Enable AC-coupled JTAG debug mode",
            offset      =  (0x0000<<2),
            bitSize     =  1,
            bitOffset   =  14,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ACJTAG_MODE",
            description = "Enable AC-coupled JTAG operation mode",
            offset      =  (0x0000<<2),
            bitSize     =  1,
            bitOffset   =  13,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "UCODEER_CLR",
            description = "Clear microcode error flag",
            offset      =  (0x0000<<2),
            bitSize     =  1,
            bitOffset   =  1,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXBUFRESET_TIME",
            description = "RX buffer reset duration in clock cycles",
            offset      =  (0x000C<<2),
            bitSize     =  5,
            bitOffset   =  11,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXCDRPHRESET_TIME",
            description = "CDR phase reset duration in clock cycles",
            offset      =  (0x000D<<2),
            bitSize     =  5,
            bitOffset   =  10,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXCDRFREQRESET_TIME",
            description = "CDR frequency reset duration in clock cycles",
            offset      =  (0x000D<<2),
            bitSize     =  5,
            bitOffset   =  5,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXPMARESET_TIME",
            description = "RX PMA reset duration in clock cycles",
            offset      =  (0x000D<<2),
            bitSize     =  5,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXPCSRESET_TIME",
            description = "RX PCS reset duration in clock cycles",
            offset      =  (0x000E<<2),
            bitSize     =  5,
            bitOffset   =  7,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXLPMRESET_TIME",
            description = "RX LPM reset duration in clock cycles",
            offset      =  (0x000E<<2),
            bitSize     =  7,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXISCANRESET_TIME",
            description = "RX I-scan reset duration in clock cycles",
            offset      =  (0x000F<<2),
            bitSize     =  5,
            bitOffset   =  7,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXSYNC_OVRD",
            description = "Override RX synchronization control",
            offset      =  (0x0010<<2),
            bitSize     =  1,
            bitOffset   =  15,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXSYNC_OVRD",
            description = "Override TX synchronization control",
            offset      =  (0x0010<<2),
            bitSize     =  1,
            bitOffset   =  14,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXSYNC_SKIP_DA",
            description = "Skip deskew alignment during RX sync",
            offset      =  (0x0010<<2),
            bitSize     =  1,
            bitOffset   =  13,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXSYNC_SKIP_DA",
            description = "Skip deskew alignment during TX sync",
            offset      =  (0x0010<<2),
            bitSize     =  1,
            bitOffset   =  12,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXSYNC_MULTILANE",
            description = "Enable TX multi-lane synchronization mode",
            offset      =  (0x0010<<2),
            bitSize     =  1,
            bitOffset   =  11,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXSYNC_MULTILANE",
            description = "Enable RX multi-lane synchronization mode",
            offset      =  (0x0010<<2),
            bitSize     =  1,
            bitOffset   =  10,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXPCSRESET_TIME",
            description = "TX PCS reset duration in clock cycles",
            offset      =  (0x0010<<2),
            bitSize     =  5,
            bitOffset   =  5,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXPMARESET_TIME",
            description = "TX PMA reset duration in clock cycles",
            offset      =  (0x0010<<2),
            bitSize     =  5,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_XCLK_SEL",
            description = "RX recovered clock output selection",
            offset      =  (0x0011<<2),
            bitSize     =  1,
            bitOffset   =  14,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_DATA_WIDTH",
            description = "RX internal data path width selection",
            offset      =  (0x0011<<2),
            bitSize     =  3,
            bitOffset   =  11,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_CLK25_DIV",
            description = "RX 25 MHz clock divider setting",
            offset      =  (0x0011<<2),
            bitSize     =  5,
            bitOffset   =  6,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_CM_SEL",
            description = "RX common-mode voltage selection",
            offset      =  (0x0011<<2),
            bitSize     =  2,
            bitOffset   =  4,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXPRBS_ERR_LOOPBACK",
            description = "Enable PRBS error loopback on RX path",
            offset      =  (0x0011<<2),
            bitSize     =  1,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "SATA_BURST_SEQ_LEN",
            description = "SATA burst sequence length setting",
            offset      =  (0x0012<<2),
            bitSize     =  4,
            bitOffset   =  12,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "OUTREFCLK_SEL_INV",
            description = "Output reference clock inversion selection",
            offset      =  (0x0012<<2),
            bitSize     =  2,
            bitOffset   =  10,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "SATA_BURST_VAL",
            description = "SATA burst primitive value",
            offset      =  (0x0012<<2),
            bitSize     =  3,
            bitOffset   =  7,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXOOB_CFG",
            description = "RX out-of-band signaling configuration register",
            offset      =  (0x0012<<2),
            bitSize     =  7,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "SAS_MIN_COM",
            description = "SAS minimum COMSAS sequence count",
            offset      =  (0x0013<<2),
            bitSize     =  6,
            bitOffset   =  9,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "SATA_MIN_BURST",
            description = "SATA minimum burst sequence count",
            offset      =  (0x0013<<2),
            bitSize     =  6,
            bitOffset   =  3,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "SATA_EIDLE_VAL",
            description = "SATA electrical idle detection value",
            offset      =  (0x0013<<2),
            bitSize     =  3,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "SATA_MIN_WAKE",
            description = "SATA minimum WAKE sequence count",
            offset      =  (0x0014<<2),
            bitSize     =  6,
            bitOffset   =  6,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "SATA_MIN_INIT",
            description = "SATA minimum COMRESET/COMINIT count",
            offset      =  (0x0014<<2),
            bitSize     =  6,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "SAS_MAX_COM",
            description = "SAS maximum COMSAS sequence count",
            offset      =  (0x0015<<2),
            bitSize     =  7,
            bitOffset   =  6,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "SATA_MAX_BURST",
            description = "SATA maximum burst sequence count",
            offset      =  (0x0015<<2),
            bitSize     =  6,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "SATA_MAX_WAKE",
            description = "SATA maximum WAKE sequence count",
            offset      =  (0x0016<<2),
            bitSize     =  6,
            bitOffset   =  6,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "SATA_MAX_INIT",
            description = "SATA maximum COMRESET/COMINIT count",
            offset      =  (0x0016<<2),
            bitSize     =  6,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXOSCALRESET_TIMEOUT",
            description = "RX offset calibration reset timeout",
            offset      =  (0x0017<<2),
            bitSize     =  5,
            bitOffset   =  11,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXOSCALRESET_TIME",
            description = "RX offset calibration reset duration",
            offset      =  (0x0017<<2),
            bitSize     =  5,
            bitOffset   =  6,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TRANS_TIME_RATE",
            description = "Power state transition time rate",
            offset      =  (0x0018<<2),
            bitSize     =  8,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PMA_LOOPBACK_CFG",
            description = "PMA loopback configuration setting",
            offset      =  (0x0019<<2),
            bitSize     =  1,
            bitOffset   =  15,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_PREDRIVER_MODE",
            description = "TX pre-driver operating mode selection",
            offset      =  (0x0019<<2),
            bitSize     =  1,
            bitOffset   =  12,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_EIDLE_DEASSERT_DELAY",
            description = "TX electrical idle de-assertion delay",
            offset      =  (0x0019<<2),
            bitSize     =  3,
            bitOffset   =  9,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_EIDLE_ASSERT_DELAY",
            description = "TX electrical idle assertion delay",
            offset      =  (0x0019<<2),
            bitSize     =  3,
            bitOffset   =  6,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_LOOPBACK_DRIVE_HIZ",
            description = "Drive TX output to high-impedance during loopback",
            offset      =  (0x0019<<2),
            bitSize     =  1,
            bitOffset   =  5,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_DRIVE_MODE",
            description = "TX output driver mode selection",
            offset      =  (0x0019<<2),
            bitSize     =  5,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PD_TRANS_TIME_TO_P2",
            description = "Power-down transition time to P2 state",
            offset      =  (0x001A<<2),
            bitSize     =  8,
            bitOffset   =  8,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PD_TRANS_TIME_NONE_P2",
            description = "Power-down transition time from non-P2 state",
            offset      =  (0x001A<<2),
            bitSize     =  8,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PD_TRANS_TIME_FROM_P2",
            description = "Power-down transition time from P2 state",
            offset      =  (0x001B<<2),
            bitSize     =  12,
            bitOffset   =  1,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PCS_PCIE_EN",
            description = "Enable PCI Express mode for PCS",
            offset      =  (0x001B<<2),
            bitSize     =  1,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXBUF_RESET_ON_RATE_CHANGE",
            description = "Reset TX buffer on rate change",
            offset      =  (0x001C<<2),
            bitSize     =  1,
            bitOffset   =  15,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXBUF_EN",
            description = "Enable TX elastic buffer",
            offset      =  (0x001C<<2),
            bitSize     =  1,
            bitOffset   =  14,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXGEARBOX_EN",
            description = "Enable TX gearbox for width conversion",
            offset      =  (0x001C<<2),
            bitSize     =  1,
            bitOffset   =  5,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "GEARBOX_MODE",
            description = "Gearbox operating mode selection",
            offset      =  (0x001C<<2),
            bitSize     =  3,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXLPM_HOLD_DURING_EIDLE",
            description = "Hold RX LPM adaptation during electrical idle",
            offset      =  (0x001E<<2),
            bitSize     =  1,
            bitOffset   =  14,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_OS_CFG",
            description = "RX offset cancellation configuration register",
            offset      =  (0x0024<<2),
            bitSize     =  13,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXLPM_LF_CFG_WRD1",
            description = "RX LPM low-frequency configuration word 1",
            offset      =  (0x002A<<2),
            bitSize     =  2,
            bitOffset   =  14,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXLPM_HF_CFG",
            description = "RX LPM high-frequency configuration register",
            offset      =  (0x002A<<2),
            bitSize     =  14,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXLPM_LF_CFG_WRD0",
            description = "RX LPM low-frequency configuration word 0",
            offset      =  (0x002B<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ES_QUALIFIER_WRD0",
            description = "Eye scan qualifier mask word 0",
            offset      =  (0x002C<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ES_QUALIFIER_WRD1",
            description = "Eye scan qualifier mask word 1",
            offset      =  (0x002D<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ES_QUALIFIER_WRD2",
            description = "Eye scan qualifier mask word 2",
            offset      =  (0x002E<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ES_QUALIFIER_WRD3",
            description = "Eye scan qualifier mask word 3",
            offset      =  (0x002F<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ES_QUALIFIER_WRD4",
            description = "Eye scan qualifier mask word 4",
            offset      =  (0x0030<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ES_SDATA_MASK_WRD0",
            description = "Eye scan sample data mask word 0",
            offset      =  (0x0036<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ES_SDATA_MASK_WRD1",
            description = "Eye scan sample data mask word 1",
            offset      =  (0x0037<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ES_SDATA_MASK_WRD2",
            description = "Eye scan sample data mask word 2",
            offset      =  (0x0038<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ES_SDATA_MASK_WRD3",
            description = "Eye scan sample data mask word 3",
            offset      =  (0x0039<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ES_SDATA_MASK_WRD4",
            description = "Eye scan sample data mask word 4",
            offset      =  (0x003A<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ES_PRESCALE",
            description = "Eye scan prescale factor for sample accumulation",
            offset      =  (0x003B<<2),
            bitSize     =  5,
            bitOffset   =  11,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ES_VERT_OFFSET",
            description = "Eye scan vertical offset setting",
            offset      =  (0x003B<<2),
            bitSize     =  9,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ES_HORZ_OFFSET",
            description = "Eye scan horizontal phase offset setting",
            offset      =  (0x003C<<2),
            bitSize     =  12,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_DISPERR_SEQ_MATCH",
            description = "Enable disparity error sequence matching",
            offset      =  (0x003D<<2),
            bitSize     =  1,
            bitOffset   =  15,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "DEC_PCOMMA_DETECT",
            description = "Enable positive comma character detection",
            offset      =  (0x003D<<2),
            bitSize     =  1,
            bitOffset   =  14,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "DEC_MCOMMA_DETECT",
            description = "Enable negative comma character detection",
            offset      =  (0x003D<<2),
            bitSize     =  1,
            bitOffset   =  13,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "DEC_VALID_COMMA_ONLY",
            description = "Accept only valid comma characters for alignment",
            offset      =  (0x003D<<2),
            bitSize     =  1,
            bitOffset   =  12,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ES_ERRDET_EN",
            description = "Enable eye scan error detection",
            offset      =  (0x003D<<2),
            bitSize     =  1,
            bitOffset   =  9,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ES_EYE_SCAN_EN",
            description = "Enable eye scan functionality",
            offset      =  (0x003D<<2),
            bitSize     =  1,
            bitOffset   =  8,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ES_CONTROL",
            description = "Eye scan control and mode register",
            offset      =  (0x003D<<2),
            bitSize     =  6,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ALIGN_COMMA_ENABLE",
            description = "Comma alignment enable bit mask",
            offset      =  (0x003E<<2),
            bitSize     =  9,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ALIGN_MCOMMA_VALUE",
            description = "Negative comma alignment pattern value",
            offset      =  (0x003F<<2),
            bitSize     =  9,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXSLIDE_MODE",
            description = "RX bit-slip mode selection",
            offset      =  (0x0040<<2),
            bitSize     =  2,
            bitOffset   =  14,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ALIGN_PCOMMA_VALUE",
            description = "Positive comma alignment pattern value",
            offset      =  (0x0040<<2),
            bitSize     =  10,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ALIGN_COMMA_WORD",
            description = "Comma alignment word width setting",
            offset      =  (0x0041<<2),
            bitSize     =  2,
            bitOffset   =  13,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_SIG_VALID_DLY",
            description = "RX signal valid assertion delay",
            offset      =  (0x0041<<2),
            bitSize     =  5,
            bitOffset   =  8,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ALIGN_PCOMMA_DET",
            description = "Enable positive comma detection for alignment",
            offset      =  (0x0041<<2),
            bitSize     =  1,
            bitOffset   =  7,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ALIGN_MCOMMA_DET",
            description = "Enable negative comma detection for alignment",
            offset      =  (0x0041<<2),
            bitSize     =  1,
            bitOffset   =  6,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "SHOW_REALIGN_COMMA",
            description = "Show comma realignment events on status port",
            offset      =  (0x0041<<2),
            bitSize     =  1,
            bitOffset   =  5,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ALIGN_COMMA_DOUBLE",
            description = "Enable double-width comma alignment",
            offset      =  (0x0041<<2),
            bitSize     =  1,
            bitOffset   =  4,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXSLIDE_AUTO_WAIT",
            description = "Auto bit-slip wait cycles between slides",
            offset      =  (0x0041<<2),
            bitSize     =  4,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CLK_CORRECT_USE",
            description = "Enable clock correction",
            offset      =  (0x0044<<2),
            bitSize     =  1,
            bitOffset   =  14,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CLK_COR_SEQ_1_ENABLE",
            description = "Enable bytes in clock correction sequence 1",
            offset      =  (0x0044<<2),
            bitSize     =  4,
            bitOffset   =  10,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CLK_COR_SEQ_1_1",
            description = "Clock correction sequence 1 byte 1 pattern",
            offset      =  (0x0044<<2),
            bitSize     =  10,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CLK_COR_MAX_LAT",
            description = "Maximum clock correction latency in clock cycles",
            offset      =  (0x0045<<2),
            bitSize     =  6,
            bitOffset   =  10,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CLK_COR_SEQ_1_2",
            description = "Clock correction sequence 1 byte 2 pattern",
            offset      =  (0x0045<<2),
            bitSize     =  10,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CLK_COR_MIN_LAT",
            description = "Minimum clock correction latency in clock cycles",
            offset      =  (0x0046<<2),
            bitSize     =  6,
            bitOffset   =  10,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CLK_COR_SEQ_1_3",
            description = "Clock correction sequence 1 byte 3 pattern",
            offset      =  (0x0046<<2),
            bitSize     =  10,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CLK_COR_REPEAT_WAIT",
            description = "Wait cycles before repeating clock correction",
            offset      =  (0x0047<<2),
            bitSize     =  5,
            bitOffset   =  10,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CLK_COR_SEQ_1_4",
            description = "Clock correction sequence 1 byte 4 pattern",
            offset      =  (0x0047<<2),
            bitSize     =  10,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CLK_COR_SEQ_2_USE",
            description = "Enable clock correction sequence 2",
            offset      =  (0x0048<<2),
            bitSize     =  1,
            bitOffset   =  14,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CLK_COR_SEQ_2_ENABLE",
            description = "Enable bytes in clock correction sequence 2",
            offset      =  (0x0048<<2),
            bitSize     =  4,
            bitOffset   =  10,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CLK_COR_SEQ_2_1",
            description = "Clock correction sequence 2 byte 1 pattern",
            offset      =  (0x0048<<2),
            bitSize     =  10,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CLK_COR_KEEP_IDLE",
            description = "Keep clock correction in idle state",
            offset      =  (0x0049<<2),
            bitSize     =  1,
            bitOffset   =  14,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CLK_COR_PRECEDENCE",
            description = "Clock correction sequence priority selection",
            offset      =  (0x0049<<2),
            bitSize     =  1,
            bitOffset   =  12,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CLK_COR_SEQ_LEN",
            description = "Number of bytes in clock correction sequence",
            offset      =  (0x0049<<2),
            bitSize     =  2,
            bitOffset   =  10,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CLK_COR_SEQ_2_2",
            description = "Clock correction sequence 2 byte 2 pattern",
            offset      =  (0x0049<<2),
            bitSize     =  10,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CLK_COR_SEQ_2_3",
            description = "Clock correction sequence 2 byte 3 pattern",
            offset      =  (0x004A<<2),
            bitSize     =  10,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXGEARBOX_EN",
            description = "Enable RX gearbox for width conversion",
            offset      =  (0x004B<<2),
            bitSize     =  1,
            bitOffset   =  15,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CLK_COR_SEQ_2_4",
            description = "Clock correction sequence 2 byte 4 pattern",
            offset      =  (0x004B<<2),
            bitSize     =  10,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CHAN_BOND_SEQ_1_ENABLE",
            description = "Enable bytes in channel bonding sequence 1",
            offset      =  (0x004C<<2),
            bitSize     =  4,
            bitOffset   =  12,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CHAN_BOND_SEQ_1_1",
            description = "Channel bonding sequence 1 byte 1 pattern",
            offset      =  (0x004C<<2),
            bitSize     =  10,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CHAN_BOND_SEQ_LEN",
            description = "Number of bytes in channel bonding sequence",
            offset      =  (0x004D<<2),
            bitSize     =  2,
            bitOffset   =  14,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CHAN_BOND_SEQ_1_2",
            description = "Channel bonding sequence 1 byte 2 pattern",
            offset      =  (0x004D<<2),
            bitSize     =  10,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CHAN_BOND_KEEP_ALIGN",
            description = "Maintain channel bonding alignment continuously",
            offset      =  (0x004E<<2),
            bitSize     =  1,
            bitOffset   =  15,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CHAN_BOND_SEQ_1_3",
            description = "Channel bonding sequence 1 byte 3 pattern",
            offset      =  (0x004E<<2),
            bitSize     =  10,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CHAN_BOND_SEQ_1_4",
            description = "Channel bonding sequence 1 byte 4 pattern",
            offset      =  (0x004F<<2),
            bitSize     =  10,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CHAN_BOND_SEQ_2_ENABLE",
            description = "Enable bytes in channel bonding sequence 2",
            offset      =  (0x0050<<2),
            bitSize     =  4,
            bitOffset   =  12,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CHAN_BOND_SEQ_2_USE",
            description = "Enable channel bonding sequence 2",
            offset      =  (0x0050<<2),
            bitSize     =  1,
            bitOffset   =  11,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CHAN_BOND_SEQ_2_1",
            description = "Channel bonding sequence 2 byte 1 pattern",
            offset      =  (0x0050<<2),
            bitSize     =  10,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "FTS_LANE_DESKEW_CFG",
            description = "PCIe FTS lane deskew configuration",
            offset      =  (0x0051<<2),
            bitSize     =  4,
            bitOffset   =  12,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "FTS_LANE_DESKEW_EN",
            description = "Enable PCIe FTS lane deskew",
            offset      =  (0x0051<<2),
            bitSize     =  1,
            bitOffset   =  11,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CHAN_BOND_SEQ_2_2",
            description = "Channel bonding sequence 2 byte 2 pattern",
            offset      =  (0x0051<<2),
            bitSize     =  10,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "FTS_DESKEW_SEQ_ENABLE",
            description = "Enable bytes in FTS deskew sequence",
            offset      =  (0x0052<<2),
            bitSize     =  4,
            bitOffset   =  12,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CBCC_DATA_SOURCE_SEL",
            description = "Channel bonding comma count data source selection",
            offset      =  (0x0052<<2),
            bitSize     =  1,
            bitOffset   =  11,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CHAN_BOND_SEQ_2_3",
            description = "Channel bonding sequence 2 byte 3 pattern",
            offset      =  (0x0052<<2),
            bitSize     =  10,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CHAN_BOND_MAX_SKEW",
            description = "Maximum channel bonding skew in UI",
            offset      =  (0x0053<<2),
            bitSize     =  4,
            bitOffset   =  12,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CHAN_BOND_SEQ_2_4",
            description = "Channel bonding sequence 2 byte 4 pattern",
            offset      =  (0x0053<<2),
            bitSize     =  10,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDLY_TAP_CFG",
            description = "RX delay tap configuration register",
            offset      =  (0x0054<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDLY_CFG",
            description = "RX delay line configuration register",
            offset      =  (0x0055<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXPH_MONITOR_SEL",
            description = "RX phase monitor output selection",
            offset      =  (0x0057<<2),
            bitSize     =  5,
            bitOffset   =  8,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_DDI_SEL",
            description = "RX data delay interpolator selection",
            offset      =  (0x0057<<2),
            bitSize     =  6,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_XCLK_SEL",
            description = "TX clock output selection",
            offset      =  (0x0059<<2),
            bitSize     =  1,
            bitOffset   =  7,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXBUF_EN",
            description = "Enable RX elastic buffer",
            offset      =  (0x0059<<2),
            bitSize     =  1,
            bitOffset   =  6,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXOOB_CFG",
            description = "TX out-of-band signaling configuration",
            offset      =  (0x005A<<2),
            bitSize     =  1,
            bitOffset   =  9,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "LOOPBACK_CFG",
            description = "Loopback path configuration setting",
            offset      =  (0x005A<<2),
            bitSize     =  1,
            bitOffset   =  8,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXPI_CFG5",
            description = "TX phase interpolator configuration 5",
            offset      =  (0x005D<<2),
            bitSize     =  3,
            bitOffset   =  8,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXPI_CFG4",
            description = "TX phase interpolator configuration 4",
            offset      =  (0x005D<<2),
            bitSize     =  1,
            bitOffset   =  7,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXPI_CFG3",
            description = "TX phase interpolator configuration 3",
            offset      =  (0x005D<<2),
            bitSize     =  1,
            bitOffset   =  6,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXPI_CFG2",
            description = "TX phase interpolator configuration 2",
            offset      =  (0x005D<<2),
            bitSize     =  2,
            bitOffset   =  4,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXPI_CFG1",
            description = "TX phase interpolator configuration 1",
            offset      =  (0x005D<<2),
            bitSize     =  2,
            bitOffset   =  2,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXPI_CFG0",
            description = "TX phase interpolator configuration 0",
            offset      =  (0x005D<<2),
            bitSize     =  2,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "SATA_PLL_CFG",
            description = "SATA PLL divider configuration",
            offset      =  (0x005E<<2),
            bitSize     =  2,
            bitOffset   =  14,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXPHDLY_CFG_WRD0",
            description = "TX phase delay configuration word 0",
            offset      =  (0x0060<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXPHDLY_CFG_WRD1",
            description = "TX phase delay configuration word 1",
            offset      =  (0x0061<<2),
            bitSize     =  8,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXDLY_CFG",
            description = "TX delay line configuration register",
            offset      =  (0x0062<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXDLY_TAP_CFG",
            description = "TX delay tap configuration register",
            offset      =  (0x0063<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXPH_CFG",
            description = "TX phase configuration register",
            offset      =  (0x0064<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXPH_MONITOR_SEL",
            description = "TX phase monitor output selection",
            offset      =  (0x0065<<2),
            bitSize     =  5,
            bitOffset   =  8,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_BIAS_CFG",
            description = "RX bias circuit configuration register",
            offset      =  (0x0066<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXOOB_CLK_CFG",
            description = "RX out-of-band clock source configuration",
            offset      =  (0x0068<<2),
            bitSize     =  1,
            bitOffset   =  3,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_CLKMUX_EN",
            description = "Enable TX clock multiplexer",
            offset      =  (0x0068<<2),
            bitSize     =  1,
            bitOffset   =  1,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_CLKMUX_EN",
            description = "Enable RX clock multiplexer",
            offset      =  (0x0068<<2),
            bitSize     =  1,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TERM_RCAL_CFG",
            description = "RX termination resistance calibration configuration",
            offset      =  (0x0069<<2),
            bitSize     =  15,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        # "This feature is intended for internal use only." (UG482)
        # self.add(pr.RemoteVariable(
            # name         = "TERM_RCAL_OVRD",
            # description  = "RX termination resistance calibration override",
            # offset       =  (0x006A<<2),
            # bitSize      =  3,
            # bitOffset    =  13,
            # base         = pr.UInt,
            # mode         = "RW",
        # ))

        self.add(pr.RemoteVariable(
            name        = "TX_CLK25_DIV",
            description = "TX 25 MHz clock divider setting",
            offset      =  (0x006A<<2),
            bitSize     =  5,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PMA_RSV5",
            description = "PMA reserved attribute 5",
            offset      =  (0x006B<<2),
            bitSize     =  1,
            bitOffset   =  15,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PMA_RSV4",
            description = "PMA reserved attribute 4",
            offset      =  (0x006B<<2),
            bitSize     =  4,
            bitOffset   =  8,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_DATA_WIDTH",
            description = "TX internal data path width selection",
            offset      =  (0x006B<<2),
            bitSize     =  3,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PCS_RSVD_ATTR_WRD0",
            description = "PCS reserved attribute word 0",
            offset      =  (0x006F<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PCS_RSVD_ATTR_WRD1",
            description = "PCS reserved attribute word 1",
            offset      =  (0x0070<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PCS_RSVD_ATTR_WRD2",
            description = "PCS reserved attribute word 2",
            offset      =  (0x0071<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_MARGIN_FULL_1",
            description = "TX output swing margin at full swing setting 1",
            offset      =  (0x0075<<2),
            bitSize     =  7,
            bitOffset   =  8,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_MARGIN_FULL_0",
            description = "TX output swing margin at full swing setting 0",
            offset      =  (0x0075<<2),
            bitSize     =  7,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_MARGIN_FULL_3",
            description = "TX output swing margin at full swing setting 3",
            offset      =  (0x0076<<2),
            bitSize     =  7,
            bitOffset   =  8,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_MARGIN_FULL_2",
            description = "TX output swing margin at full swing setting 2",
            offset      =  (0x0076<<2),
            bitSize     =  7,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_MARGIN_LOW_0",
            description = "TX output swing margin at low swing setting 0",
            offset      =  (0x0077<<2),
            bitSize     =  7,
            bitOffset   =  8,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_MARGIN_FULL_4",
            description = "TX output swing margin at full swing setting 4",
            offset      =  (0x0077<<2),
            bitSize     =  7,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_MARGIN_LOW_2",
            description = "TX output swing margin at low swing setting 2",
            offset      =  (0x0078<<2),
            bitSize     =  7,
            bitOffset   =  8,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_MARGIN_LOW_1",
            description = "TX output swing margin at low swing setting 1",
            offset      =  (0x0078<<2),
            bitSize     =  7,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_MARGIN_LOW_4",
            description = "TX output swing margin at low swing setting 4",
            offset      =  (0x0079<<2),
            bitSize     =  7,
            bitOffset   =  8,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_MARGIN_LOW_3",
            description = "TX output swing margin at low swing setting 3",
            offset      =  (0x0079<<2),
            bitSize     =  7,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_DEEMPH1",
            description = "TX de-emphasis level 1 setting",
            offset      =  (0x007A<<2),
            bitSize     =  6,
            bitOffset   =  8,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_DEEMPH0",
            description = "TX de-emphasis level 0 setting",
            offset      =  (0x007A<<2),
            bitSize     =  6,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_RXDETECT_REF",
            description = "TX receiver detection reference voltage",
            offset      =  (0x007C<<2),
            bitSize     =  3,
            bitOffset   =  8,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_MAINCURSOR_SEL",
            description = "TX main cursor amplitude selection",
            offset      =  (0x007C<<2),
            bitSize     =  1,
            bitOffset   =  3,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PMA_RSV3",
            description = "PMA reserved attribute 3",
            offset      =  (0x007C<<2),
            bitSize     =  2,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PMA_RSV7",
            description = "PMA reserved attribute 7",
            offset      =  (0x007D<<2),
            bitSize     =  1,
            bitOffset   =  15,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PMA_RSV6",
            description = "PMA reserved attribute 6",
            offset      =  (0x007D<<2),
            bitSize     =  1,
            bitOffset   =  14,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TX_RXDETECT_CFG",
            description = "TX receiver detection configuration register",
            offset      =  (0x007D<<2),
            bitSize     =  14,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CLK_COMMON_SWING",
            description = "Common clock output swing level selection",
            offset      =  (0x007E<<2),
            bitSize     =  1,
            bitOffset   =  15,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_CM_TRIM",
            description = "RX common-mode voltage trim setting",
            offset      =  (0x007E<<2),
            bitSize     =  4,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXLPM_CFG1",
            description = "RX LPM configuration register 1",
            offset      =  (0x0081<<2),
            bitSize     =  1,
            bitOffset   =  4,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXLPM_CFG",
            description = "RX LPM configuration register",
            offset      =  (0x0081<<2),
            bitSize     =  4,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PMA_RSV2_WRD0",
            description = "PMA reserved attribute 2 word 0",
            offset      =  (0x0082<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PMA_RSV2_WRD1",
            description = "PMA reserved attribute 2 word 1",
            offset      =  (0x0083<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "DMONITOR_CFG_WRD0",
            description = "Digital monitor configuration word 0",
            offset      =  (0x0086<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "DMONITOR_CFG_WRD1",
            description = "Digital monitor configuration word 1",
            offset      =  (0x0087<<2),
            bitSize     =  8,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXLPM_BIAS_STARTUP_DISABLE",
            description = "Disable RX LPM bias during startup",
            offset      =  (0x0088<<2),
            bitSize     =  1,
            bitOffset   =  15,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXLPM_HF_CFG3",
            description = "RX LPM high-frequency configuration 3",
            offset      =  (0x0088<<2),
            bitSize     =  4,
            bitOffset   =  11,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXOUT_DIV",
            description = "TX output divider setting",
            offset      =  (0x0088<<2),
            bitSize     =  3,
            bitOffset   =  4,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXOUT_DIV",
            description = "RX output divider setting",
            offset      =  (0x0088<<2),
            bitSize     =  3,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CFOK_CFG_WRD0",
            description = "CDR frequency offset kicker configuration word 0",
            offset      =  (0x0089<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CFOK_CFG_WRD1",
            description = "CDR frequency offset kicker configuration word 1",
            offset      =  (0x008A<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CFOK_CFG_WRD2",
            description = "CDR frequency offset kicker configuration word 2",
            offset      =  (0x008B<<2),
            bitSize     =  11,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CFOK_CFG3",
            description = "CDR frequency offset kicker configuration 3",
            offset      =  (0x008C<<2),
            bitSize     =  7,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXPI_CFG0",
            description = "RX phase interpolator configuration 0",
            offset      =  (0x008D<<2),
            bitSize     =  3,
            bitOffset   =  13,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXLPM_CM_CFG",
            description = "RX LPM common-mode configuration setting",
            offset      =  (0x008D<<2),
            bitSize     =  1,
            bitOffset   =  12,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CFOK_CFG5",
            description = "CDR frequency offset kicker configuration 5",
            offset      =  (0x008D<<2),
            bitSize     =  2,
            bitOffset   =  10,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXLPM_LF_CFG2",
            description = "RX LPM low-frequency configuration 2",
            offset      =  (0x008D<<2),
            bitSize     =  5,
            bitOffset   =  5,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXLPM_HF_CFG2",
            description = "RX LPM high-frequency configuration 2",
            offset      =  (0x008D<<2),
            bitSize     =  5,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXLPM_IPCM_CFG",
            description = "RX LPM input path common-mode configuration",
            offset      =  (0x008E<<2),
            bitSize     =  1,
            bitOffset   =  15,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXLPM_INCM_CFG",
            description = "RX LPM input non-common-mode configuration",
            offset      =  (0x008E<<2),
            bitSize     =  1,
            bitOffset   =  14,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CFOK_CFG4",
            description = "CDR frequency offset kicker configuration 4",
            offset      =  (0x008E<<2),
            bitSize     =  1,
            bitOffset   =  13,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CFOK_CFG6",
            description = "CDR frequency offset kicker configuration 6",
            offset      =  (0x008E<<2),
            bitSize     =  4,
            bitOffset   =  9,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXLPM_GC_CFG",
            description = "RX LPM gain control configuration register",
            offset      =  (0x008E<<2),
            bitSize     =  9,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXLPM_GC_CFG2",
            description = "RX LPM gain control configuration 2",
            offset      =  (0x008F<<2),
            bitSize     =  3,
            bitOffset   =  5,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXPI_CFG1",
            description = "RX phase interpolator configuration 1",
            offset      =  (0x008F<<2),
            bitSize     =  1,
            bitOffset   =  4,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXPI_CFG2",
            description = "RX phase interpolator configuration 2",
            offset      =  (0x008F<<2),
            bitSize     =  1,
            bitOffset   =  3,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXLPM_OSINT_CFG",
            description = "RX LPM offset integration configuration",
            offset      =  (0x008F<<2),
            bitSize     =  3,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ES_CLK_PHASE_SEL",
            description = "Eye scan clock phase selection",
            offset      =  (0x0091<<2),
            bitSize     =  1,
            bitOffset   =  15,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "USE_PCS_CLK_PHASE_SEL",
            description = "Use PCS clock for eye scan phase selection",
            offset      =  (0x0091<<2),
            bitSize     =  1,
            bitOffset   =  14,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "CFOK_CFG2",
            description = "CDR frequency offset kicker configuration 2",
            offset      =  (0x0091<<2),
            bitSize     =  7,
            bitOffset   =  6,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ADAPT_CFG0_WRD0",
            description = "RX adaptation configuration 0 word 0",
            offset      =  (0x0092<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ADAPT_CFG0_WRD1",
            description = "RX adaptation configuration 0 word 1",
            offset      =  (0x0093<<2),
            bitSize     =  4,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXPI_PPM_CFG",
            description = "TX phase interpolator PPM configuration register",
            offset      =  (0x0095<<2),
            bitSize     =  8,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXPI_GREY_SEL",
            description = "TX phase interpolator gray-code selection",
            offset      =  (0x0096<<2),
            bitSize     =  1,
            bitOffset   =  5,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXPI_INVSTROBE_SEL",
            description = "TX phase interpolator invert strobe selection",
            offset      =  (0x0096<<2),
            bitSize     =  1,
            bitOffset   =  4,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXPI_PPMCLK_SEL",
            description = "TX phase interpolator PPM clock selection",
            offset      =  (0x0096<<2),
            bitSize     =  1,
            bitOffset   =  3,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXPI_SYNFREQ_PPM",
            description = "TX phase interpolator sync frequency PPM setting",
            offset      =  (0x0096<<2),
            bitSize     =  3,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TST_RSV_WRD0",
            description = "Test reserved attribute word 0",
            offset      =  (0x0097<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TST_RSV_WRD1",
            description = "Test reserved attribute word 1",
            offset      =  (0x0098<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PMA_RSV_WRD0",
            description = "PMA reserved attribute word 0",
            offset      =  (0x0099<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "PMA_RSV_WRD1",
            description = "PMA reserved attribute word 1",
            offset      =  (0x009A<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_BUFFER_CFG",
            description = "RX buffer configuration register",
            offset      =  (0x009B<<2),
            bitSize     =  6,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXBUF_THRESH_OVRD",
            description = "Override RX buffer threshold levels",
            offset      =  (0x009C<<2),
            bitSize     =  1,
            bitOffset   =  8,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXBUF_RESET_ON_EIDLE",
            description = "Reset RX buffer on electrical idle detection",
            offset      =  (0x009C<<2),
            bitSize     =  1,
            bitOffset   =  6,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXBUF_THRESH_UNDFLW",
            description = "RX buffer underflow threshold setting",
            offset      =  (0x009C<<2),
            bitSize     =  6,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXBUF_EIDLE_HI_CNT",
            description = "RX buffer electrical idle high count threshold",
            offset      =  (0x009D<<2),
            bitSize     =  4,
            bitOffset   =  12,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXBUF_EIDLE_LO_CNT",
            description = "RX buffer electrical idle low count threshold",
            offset      =  (0x009D<<2),
            bitSize     =  4,
            bitOffset   =  8,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXBUF_ADDR_MODE",
            description = "RX buffer address mode selection",
            offset      =  (0x009D<<2),
            bitSize     =  1,
            bitOffset   =  7,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXBUF_THRESH_OVFLW",
            description = "RX buffer overflow threshold setting",
            offset      =  (0x009D<<2),
            bitSize     =  6,
            bitOffset   =  1,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_DEFER_RESET_BUF_EN",
            description = "Enable deferred reset of RX buffer",
            offset      =  (0x009D<<2),
            bitSize     =  1,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXBUF_RESET_ON_COMMAALIGN",
            description = "Reset RX buffer on comma alignment event",
            offset      =  (0x009E<<2),
            bitSize     =  1,
            bitOffset   =  2,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXBUF_RESET_ON_RATE_CHANGE",
            description = "Reset RX buffer on rate change",
            offset      =  (0x009E<<2),
            bitSize     =  1,
            bitOffset   =  1,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXBUF_RESET_ON_CB_CHANGE",
            description = "Reset RX buffer on channel bonding change",
            offset      =  (0x009E<<2),
            bitSize     =  1,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "TXDLY_LCFG",
            description = "TX delay line load configuration",
            offset      =  (0x009F<<2),
            bitSize     =  9,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXDLY_LCFG",
            description = "RX delay line load configuration",
            offset      =  (0x00A0<<2),
            bitSize     =  9,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXPH_CFG_WRD0",
            description = "RX phase configuration word 0",
            offset      =  (0x00A1<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXPH_CFG_WRD1",
            description = "RX phase configuration word 1",
            offset      =  (0x00A2<<2),
            bitSize     =  8,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXPHDLY_CFG_WRD0",
            description = "RX phase delay configuration word 0",
            offset      =  (0x00A3<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXPHDLY_CFG_WRD1",
            description = "RX phase delay configuration word 1",
            offset      =  (0x00A4<<2),
            bitSize     =  8,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RX_DEBUG_CFG",
            description = "RX debug configuration register",
            offset      =  (0x00A5<<2),
            bitSize     =  14,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "ES_PMA_CFG",
            description = "Eye scan PMA configuration register",
            offset      =  (0x00A6<<2),
            bitSize     =  10,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXCDR_PH_RESET_ON_EIDLE",
            description = "Reset CDR phase on electrical idle",
            offset      =  (0x00A7<<2),
            bitSize     =  1,
            bitOffset   =  13,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXCDR_FR_RESET_ON_EIDLE",
            description = "Reset CDR frequency on electrical idle",
            offset      =  (0x00A7<<2),
            bitSize     =  1,
            bitOffset   =  12,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXCDR_HOLD_DURING_EIDLE",
            description = "Hold CDR state during electrical idle",
            offset      =  (0x00A7<<2),
            bitSize     =  1,
            bitOffset   =  11,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXCDR_LOCK_CFG",
            description = "CDR lock detection configuration register",
            offset      =  (0x00A7<<2),
            bitSize     =  6,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXCDR_CFG_WRD0",
            description = "CDR configuration word 0",
            offset      =  (0x00A8<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXCDR_CFG_WRD1",
            description = "CDR configuration word 1",
            offset      =  (0x00A9<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXCDR_CFG_WRD2",
            description = "CDR configuration word 2",
            offset      =  (0x00AA<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXCDR_CFG_WRD3",
            description = "CDR configuration word 3",
            offset      =  (0x00AB<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXCDR_CFG_WRD4",
            description = "CDR configuration word 4",
            offset      =  (0x00AC<<2),
            bitSize     =  16,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))

        self.add(pr.RemoteVariable(
            name        = "RXCDR_CFG_WRD5",
            description = "CDR configuration word 5",
            offset      =  (0x00AD<<2),
            bitSize     =  3,
            bitOffset   =  0,
            base        = pr.UInt,
            mode        = "RW",
        ))
