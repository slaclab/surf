#-----------------------------------------------------------------------------
# Description:
# PyRogue Gtye4Channel
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

class Gtye4Channel(pr.Device):

    def _start(self):
        super()._start()
        print(f'{self.path} - {len(self.variables)=}')

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        ##############################
        # Variables
        ##############################

        def addVar(**kwargs):
            kwargs['offset'] = kwargs['offset'] << 2
            self.add(pr.RemoteVariable(**kwargs))

        addVar(
            name         = "CDR_SWAP_MODE_EN",
            offset       =  0x02,
            bitSize      =  1,
            mode         = "RW")

        addVar(
            name         = "RXBUFRESET_TIME",
            offset       =  0x03,
            bitSize      =  5,
            bitOffset    =  11,
            mode         = "RW")


        addVar(
            name         = "CFOK_PWRSVE_EN",
            offset       =  0x03,
            bitSize      =  1,
            bitOffset    =  10,
            mode         = "RW")

        addVar(
            name         = "EYE_SCAN_SWAP_EN",
            offset       = 0x3,
            bitSize      =  1,
            bitOffset    =  9,
            mode         = "RW")

        addVar(
            name         = "RX_DATA_WIDTH",
            offset       =  0x03,
            bitSize      =  4,
            bitOffset    =  5,
            mode         = "RW",
            enum         = {
                0 : '-',
                2 : '16',
                3 : '20',
                4 : '32',
                5 : '40',
                6 : '64',
                7 : '80',
                8 : '128',
                9 : '160'})

        addVar(
            name         = "RXCDRFREQRESET_TIME",
            offset       =  0x03,
            bitSize      =  5,
            bitOffset    =  0,
            mode         = "RW")

        addVar(
            offset = 0x0004,
            bitSize = 5,
            bitOffset =11,
            mode = 'RW',
            name = 'RXCDRPHRESET_TIME')

        addVar(
            offset = 0x0004,
            bitSize = 3,
            bitOffset = 8,
            mode = 'RW',
            name = 'PCI3_RX_ELECIDLE_H2L_DISABLE')

        addVar(
            offset = 0x0004,
            bitSize = 7,
            bitOffset = 1,
            mode = 'RW',
            name = 'RXDFELPMRESET_TIME')

        addVar(
            offset = 0x0004,
            bitSize = 1,
            bitOffset = 0,
            mode = 'RW',
            name = 'RX_FABINT_USRCLK_FLOP')

        addVar(
            offset = 0x0005,
            bitSize = 5,
            bitOffset = 11,
            mode = 'RW',
            name = 'RXPMARESET_TIME')

        addVar(
            offset = 0x0005,
            bitSize = 1,
            bitOffset = 10,
            mode = 'RW',
            name = 'PCI3_RX_ELECIDLE_LP4_DISABLE')

        addVar(
            offset = 0x0005,
            bitSize = 1,
            bitOffset = 8,
            mode = 'RW',
            name = 'PCI3_RX_FIFO_DISABLE')

        addVar(
            offset = 0x0005,
            bitSize = 1,
            bitOffset = 9,
            mode = 'RW',
            name = 'PCI3_RX_ELECIDLE_EI2_ENABLE')

        addVar(
            offset = 0x0005,
            bitSize = 5,
            bitOffset = 3,
            mode = 'RW',
            name = 'RXPCSRESET_TIME')

        addVar(
            offset = 0x0005,
            bitSize = 3,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXELECIDLE_CFG',
            enum = {
                0 : 'SIGCFG_1',
                1 : 'SIGCFG_2',
                2 : 'SIGCFG_3',
                3 : 'SIGCFG_4',
                4 : 'SIGCFG_6',
                5 : 'SIGCFG_8',
                6 : 'SIGCFG_12',
                7 : 'SIGCFG_16'})

        addVar(
            offset = 0x0006,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_HB_CFG1')

        addVar(
            offset = 0x0009,
            bitSize = 5,
            bitOffset = 11,
            mode = 'RW',
            name = 'TXPMARESET_TIME')

        addVar(
            offset = 0x0009,
            bitSize = 5,
            bitOffset = 3,
            mode = 'RW',
            name = 'TXPCSRESET_TIME')

        addVar(
            offset = 0x0009,
            bitSize = 1,
            bitOffset = 10,
            mode = 'RW',
            name = 'RX_PMA_POWER_SAVE')

        addVar(
            offset = 0x0009,
            bitSize = 1,
            bitOffset = 9,
            mode = 'RW',
            name = 'TX_PMA_POWER_SAVE')

        addVar(
            offset = 0x0009,
            bitSize = 1,
            bitOffset = 8,
            mode = 'RW',
            name = 'SRSTMODE')

        addVar(
            offset = 0x000A,
            bitSize = 1,
            bitOffset = 3,
            mode = 'RW',
            name = 'TX_FIFO_BYP_EN')

        addVar(
            offset = 0x000B,
            bitSize = 1,
            bitOffset = 4,
            mode = 'RW',
            name = 'TX_FABINT_USRCLK_FLOP')


        addVar(
            offset = 0x000B,
            bitSize = 2,
            bitOffset = 8,
            mode = 'RW',
            name = 'RXPMACLK_SEL',
            enum = {
                2 : 'CROSSING',
                0 : 'DATA',
                1 : 'EYESCAN'})

        addVar(
            offset = 0x000C,
            bitSize = 2,
            bitOffset = 10,
            mode = 'RW',
            name = 'TX_PROGCLK_SEL',
            enum = {
                0 : 'POSTPI',
                1 : 'PREPI',
                2 : 'CPLL'})

        addVar(
            offset = 0x000C,
            bitSize = 5,
            bitOffset = 5,
            mode = 'RW',
            name = 'RXISCANRESET_TIME')

        addVar(
            offset = 0x000D,
            bitSize = 6,
            bitOffset = 2,
            mode = 'RW',
            name = 'TXAMONSEL')

        addVar(
            offset = 0x000D,
            bitSize = 2,
            bitOffset = 0,
            mode = 'RW',
            name = 'BLOCKSEL')

        addVar(
            offset = 0x000E,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXCDR_CFG0')

        addVar(
            offset = 0x000F,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXCDR_CFG1')

        addVar(
            offset = 0x0010,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXCDR_CFG2')

        addVar(
            overlapEn = True,
            offset = 0x0011,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXCDR_CFG3')

        addVar(
            overlapEn = True,
            offset = 0x0011,
            bitSize = 1,
            bitOffset = 7,
            mode = 'RW',
            name = 'SELCKOK')

        addVar(
            offset = 0x0012,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXCDR_CFG4')

        addVar(
            offset = 0x0013,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'CPLL_LOCK_CFG')

        addVar(
            offset = 0x0014,
            bitSize = 4,
            bitOffset = 12,
            mode = 'RW',
            name = 'CHAN_BOND_MAX_SKEW')

        addVar(
            offset = 0x0014,
            bitSize = 2,
            bitOffset = 10,
            mode = 'RW',
            name = 'CHAN_BOND_SEQ_LEN',
            enum = {
                0 : '1',
                1 : '2',
                2 : '3',
                3 : '4'})

        addVar(
            offset = 0x0014,
            bitSize = 10,
            bitOffset = 0,
            mode = 'RW',
            name = 'CHAN_BOND_SEQ_1_1')

        addVar(
            offset = 0x0015,
            bitSize = 6,
            bitOffset = 10,
            mode = 'RW',
            name = 'PCI3_RX_ELECIDLE_HI_COUNT')

        addVar(
            offset = 0x0015,
            bitSize = 10,
            bitOffset = 0,
            mode = 'RW',
            name = 'CHAN_BOND_SEQ_1_3')

        addVar(
            offset = 0x0016,
            bitSize = 6,
            bitOffset = 10,
            mode = 'RW',
            name = 'PCI3_RX_ELECIDLE_H2L_COUNT')

        addVar(
            offset = 0x0016,
            bitSize = 10,
            bitOffset = 0,
            mode = 'RW',
            name = 'CHAN_BOND_SEQ_1_4')

        addVar(
            offset = 0x0017,
            bitSize = 6,
            bitOffset = 10,
            mode = 'RW',
            name = 'RX_BUFFER_CFG')

        addVar(
            offset = 0x0017,
            bitSize = 1,
            bitOffset = 9,
            mode = 'RW',
            name = 'RX_DEFER_RESET_BUF_EN',
            enum = {
                0 : 'FALSE',
                1 : 'TRUE'})

        addVar(
            offset = 0x0017,
            bitSize = 2,
            bitOffset = 7,
            mode = 'RW',
            name = 'OOBDIVCTL')

        addVar(
            offset = 0x0017,
            bitSize = 2,
            bitOffset = 5,
            mode = 'RW',
            name = 'PCI3_AUTO_REALIGN',
            enum = {
                0 : 'FRST_SMPL',
                1 : 'OVR_8_BLK',
                2 : 'OVR_64_BLK',
                3 : 'OVR_1K_BLK'})


        addVar(
            offset = 0x0017,
            bitSize = 1,
            bitOffset = 4,
            mode = 'RW',
            name = 'PCI3_PIPE_RX_ELECIDLE')

        addVar(
            offset = 0x0018,
            bitSize = 4,
            bitOffset = 12,
            mode = 'RW',
            name = 'CHAN_BOND_SEQ_1_ENABLE')

        addVar(
            offset = 0x0018,
            bitSize = 2,
            bitOffset = 10,
            mode = 'RW',
            name = 'PCI3_RX_ASYNC_EBUF_BYPASS')

        addVar(
            offset = 0x0018,
            bitSize = 10,
            bitOffset = 0,
            mode = 'RW',
            name = 'CHAN_BOND_SEQ_2_1')

        addVar(
            offset = 0x0019,
            bitSize = 10,
            bitOffset = 0,
            mode = 'RW',
            name = 'CHAN_BOND_SEQ_2_2')

        addVar(
            offset = 0x001A,
            bitSize = 10,
            bitOffset = 0,
            mode = 'RW',
            name = 'CHAN_BOND_SEQ_2_3')

        addVar(
            offset = 0x001B,
            bitSize = 10,
            bitOffset = 0,
            mode = 'RW',
            name = 'CHAN_BOND_SEQ_2_4')

        addVar(
            offset = 0x001C,
            bitSize = 4,
            bitOffset = 12,
            mode = 'RW',
            name = 'CHAN_BOND_SEQ_2_ENABLE')

        addVar(
            offset = 0x001C,
            bitSize = 1,
            bitOffset = 11,
            mode = 'RW',
            name = 'CHAN_BOND_SEQ_2_USE',
            enum = {
                0 : 'FALSE',
                1 : 'TRUE'})

        addVar(
            offset = 0x001C,
            bitSize = 1,
            bitOffset = 6,
            mode = 'RW',
            name = 'CLK_COR_KEEP_IDLE',
            enum = {
                0 : 'FALSE',
                1 : 'TRUE'})

        addVar(
            offset = 0x001C,
            bitSize = 6,
            bitOffset = 0,
            mode = 'RW',
            name = 'CLK_COR_MIN_LAT')

        addVar(
            offset = 0x001D,
            bitSize = 6,
            bitOffset = 10,
            mode = 'RW',
            name = 'CLK_COR_MAX_LAT')

        addVar(
            offset = 0x001D,
            bitSize = 1,
            bitOffset = 9,
            mode = 'RW',
            name = 'CLK_COR_PRECEDENCE',
            enum = {
                0 : 'FALSE',
                1 : 'TRUE'})

        addVar(
            offset = 0x001D,
            bitSize = 5,
            bitOffset = 4,
            mode = 'RW',
            name = 'CLK_COR_REPEAT_WAIT')

        addVar(
            offset = 0x001D,
            bitSize = 2,
            bitOffset = 2,
            mode = 'RW',
            name = 'CLK_COR_SEQ_LEN',
            enum = {
                0 : '1',
                1 : '2',
                2 : '3',
                3 : '4'})

        addVar(
            offset = 0x001D,
            bitSize = 1,
            bitOffset = 0,
            mode = 'RW',
            name = 'CHAN_BOND_KEEP_ALIGN',
            enum = {
                0 : 'FALSE',
                1 : 'TRUE'})

        addVar(
            offset = 0x001E,
            bitSize = 10,
            bitOffset = 0,
            mode = 'RW',
            name = 'CLK_COR_SEQ_1_1')

        addVar(
            offset = 0x001F,
            bitSize = 10,
            bitOffset = 0,
            mode = 'RW',
            name = 'CLK_COR_SEQ_1_2')

        addVar(
            offset = 0x0020,
            bitSize = 10,
            bitOffset = 0,
            mode = 'RW',
            name = 'CLK_COR_SEQ_1_3')

        addVar(
            offset = 0x0021,
            bitSize = 10,
            bitOffset = 0,
            mode = 'RW',
            name = 'CLK_COR_SEQ_1_4')

        addVar(
            offset = 0x0022,
            bitSize = 4,
            bitOffset = 12,
            mode = 'RW',
            name = 'CLK_COR_SEQ_1_ENABLE')

        addVar(
            offset = 0x0022,
            bitSize = 10,
            bitOffset = 0,
            mode = 'RW',
            name = 'CLK_COR_SEQ_2_1')

        addVar(
            offset = 0x0023,
            bitSize = 10,
            bitOffset = 0,
            mode = 'RW',
            name = 'CLK_COR_SEQ_2_2')

        addVar(
            offset = 0x0024,
            bitSize = 4,
            bitOffset = 12,
            mode = 'RW',
            name = 'CLK_COR_SEQ_2_ENABLE')

        addVar(
            offset = 0x0024,
            bitSize = 1,
            bitOffset = 11,
            mode = 'RW',
            name = 'CLK_COR_SEQ_2_USE',
            enum = {
                0 : 'FALSE',
                1 : 'TRUE'})

        addVar(
            offset = 0x0024,
            bitSize = 1,
            bitOffset = 10,
            mode = 'RW',
            name = 'CLK_CORRECT_USE',
            enum = {
                0 : 'FALSE',
                1 : 'TRUE'})

        addVar(
            offset = 0x0024,
            bitSize = 10,
            bitOffset = 0,
            mode = 'RW',
            name = 'CLK_COR_SEQ_2_3')

        addVar(
            offset = 0x0025,
            bitSize = 10,
            bitOffset = 0,
            mode = 'RW',
            name = 'CLK_COR_SEQ_2_4')

        addVar(
            offset = 0x0026,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_HE_CFG0')

        addVar(
            offset = 0x0027,
            bitSize = 3,
            bitOffset = 13,
            mode = 'RW',
            name = 'ALIGN_COMMA_WORD',
            enum = {
                0 : '-',
                1 : '1',
                2 : '2',
                4 : '4'})

        addVar(
            offset = 0x0027,
            bitSize = 1,
            bitOffset = 12,
            mode = 'RW',
            name = 'ALIGN_COMMA_DOUBLE',
            enum = {
                0 : 'FALSE',
                1 : 'TRUE'})

        addVar(
            offset = 0x0027,
            bitSize = 1,
            bitOffset = 11,
            mode = 'RW',
            name = 'SHOW_REALIGN_COMMA',
            enum = {
                0 : 'FALSE',
                1 : 'TRUE'})

        addVar(
            offset = 0x0027,
            bitSize = 10,
            bitOffset = 0,
            mode = 'RW',
            name = 'ALIGN_COMMA_ENABLE')

        addVar(
            offset = 0x0028,
            bitSize = 8,
            bitOffset = 8,
            mode = 'RW',
            name = 'CPLL_FBDIV',
            enum = {
                0 : '2',
                1 : '3',
                2 : '4',
                3 : '5',
                16 : '1'})

        addVar(
            offset = 0x0028,
            bitSize = 1,
            bitOffset = 7,
            mode = 'RW',
            name = 'CPLL_FBDIV_45',
            enum = {
                0 : '4',
                1 : '5'})

        addVar(
            offset = 0x0029,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXCDR_LOCK_CFG0')

        addVar(
            offset = 0x002A,
            bitSize = 5,
            bitOffset = 11,
            mode = 'RW',
            name = 'CPLL_REFCLK_DIV',
            enum = {
                0 : '2',
                16 : '1'})

        addVar(
            offset = 0x002A,
            bitSize = 1,
            bitOffset = 10,
            mode = 'RW',
            name = 'CPLL_IPS_EN')

        addVar(
            offset = 0x002A,
            bitSize = 3,
            bitOffset = 7,
            mode = 'RW',
            name = 'CPLL_IPS_REFCLK_SEL')

        addVar(
            offset = 0x002A,
            bitSize = 2,
            bitOffset = 5,
            mode = 'RW',
            name = 'SATA_CPLL_CFG',
            enum = {
                0 : 'VCO_3000MHZ',
                1 : 'VCO_1500MHZ',
                2 : 'VCO_750MHZ'})

        addVar(
            offset = 0x002A,
            bitSize = 5,
            bitOffset = 0,
            mode = 'RW',
            name = 'A_TXDIFFCTRL')

        addVar(
            offset = 0x002B,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'CPLL_INIT_CFG0')

        addVar(
            offset = 0x002C,
            bitSize = 1,
            bitOffset = 15,
            mode = 'RW',
            name = 'DEC_PCOMMA_DETECT',
            enum = {
                0 : 'FALSE',
                1 : 'TRUE'})

        addVar(
            offset = 0x002C,
            bitSize = 5,
            bitOffset = 7,
            mode = 'RW',
            name = 'TX_DIVRESET_TIME')

        addVar(
            offset = 0x002C,
            bitSize = 5,
            bitOffset = 2,
            mode = 'RW',
            name = 'RX_DIVRESET_TIME')

        addVar(
            offset = 0x002C,
            bitSize = 1,
            bitOffset = 1,
            mode = 'RW',
            name = 'A_TXPROGDIVRESET')

        addVar(
            offset = 0x002C,
            bitSize = 1,
            bitOffset = 0,
            mode = 'RW',
            name = 'A_RXPROGDIVRESET')

        addVar(
            offset = 0x002D,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXCDR_LOCK_CFG1')

        addVar(
            offset = 0x002E,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXCFOK_CFG1')

        addVar(
            offset = 0x002F,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_H2_CFG0')

        addVar(
            offset = 0x0030,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_H2_CFG1')

        addVar(
            offset = 0x0031,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXCFOK_CFG2')

        addVar(
            offset = 0x0032,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXLPM_CFG')

        addVar(
            offset = 0x0033,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXLPM_KH_CFG0')

        addVar(
            offset = 0x0034,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXLPM_KH_CFG1')

        addVar(
            offset = 0x0035,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFELPM_KL_CFG0')

        addVar(
            offset = 0x0036,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFELPM_KL_CFG1')

        addVar(
            offset = 0x0037,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXLPM_OS_CFG0')

        addVar(
            offset = 0x0038,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXLPM_OS_CFG1')

        addVar(
            offset = 0x0039,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXLPM_GC_CFG')

        addVar(
            offset = 0x003A,
            bitSize = 8,
            bitOffset = 8,
            mode = 'RW',
            name = 'DMONITOR_CFG1')

        addVar(
            offset = 0x003C,
            bitSize = 6,
            bitOffset = 10,
            mode = 'RW',
            name = 'ES_CONTROL')

        addVar(
            offset = 0x003C,
            bitSize = 5,
            bitOffset = 0,
            mode = 'RW',
            name = 'ES_PRESCALE')

        addVar(
            offset = 0x003C,
            bitSize = 1,
            bitOffset = 8,
            mode = 'RW',
            name = 'ES_EYE_SCAN_EN',
            enum = {
                0 : 'FALSE',
                1 : 'TRUE'})

        addVar(
            offset = 0x003C,
            bitSize = 1,
            bitOffset = 9,
            mode = 'RW',
            name = 'ES_ERRDET_EN',
            enum = {
                0 : 'FALSE',
                1 : 'TRUE'})

        addVar(
            offset = 0x003D,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_GC_CFG2')

        addVar(
            offset = 0x003E,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'TXDLY_LCFG')

        addVar(
            offset = 0x003F,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'ES_QUALIFIER0')

        addVar(
            offset = 0x0040,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'ES_QUALIFIER1')

        addVar(
            offset = 0x0041,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'ES_QUALIFIER2')

        addVar(
            offset = 0x0042,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'ES_QUALIFIER3')

        addVar(
            offset = 0x0043,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'ES_QUALIFIER4')

        addVar(
            offset = 0x0044,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'ES_QUAL_MASK0')

        addVar(
            offset = 0x0045,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'ES_QUAL_MASK1')

        addVar(
            offset = 0x0046,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'ES_QUAL_MASK2')

        addVar(
            offset = 0x0047,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'ES_QUAL_MASK3')

        addVar(
            offset = 0x0048,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'ES_QUAL_MASK4')

        addVar(
            offset = 0x0049,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'ES_SDATA_MASK0')

        addVar(
            offset = 0x004A,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'ES_SDATA_MASK1')

        addVar(
            offset = 0x004B,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'ES_SDATA_MASK2')

        addVar(
            offset = 0x004C,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'ES_SDATA_MASK3')

        addVar(
            offset = 0x004D,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'ES_SDATA_MASK4')

        addVar(
            offset = 0x004E,
            bitSize = 1,
            bitOffset = 4,
            mode = 'RW',
            name = 'FTS_LANE_DESKEW_EN',
            enum = {
                0 : 'FALSE',
                1 : 'TRUE'})

        addVar(
            offset = 0x004E,
            bitSize = 4,
            bitOffset = 0,
            mode = 'RW',
            name = 'FTS_DESKEW_SEQ_ENABLE')

        addVar(
            offset = 0x004F,
            bitSize = 12,
            bitOffset = 4,
            mode = 'RW',
            name = 'ES_HORZ_OFFSET')

        addVar(
            offset = 0x004F,
            bitSize = 4,
            bitOffset = 0,
            mode = 'RW',
            name = 'FTS_LANE_DESKEW_CFG')

        addVar(
            offset = 0x0050,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_HC_CFG1')

        addVar(
            offset = 0x0051,
            bitSize = 10,
            bitOffset = 0,
            mode = 'RW',
            name = 'ES_PMA_CFG')

        addVar(
            offset = 0x0052,
            bitSize = 3,
            bitOffset = 2,
            mode = 'RW',
            name = 'RX_DFE_AGC_CFG1')

        addVar(
            offset = 0x0053,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'TXFE_CFG2')

        addVar(
            offset = 0x0054,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'TXFE_CFG3')

        addVar(
            offset = 0x0055,
            bitSize = 1,
            bitOffset = 14,
            mode = 'RW',
            name = 'PCIE_64B_DYN_CLKSW_DIS',
            enum = {
                0 : 'FALSE',
                1 : 'TRUE'})

        addVar(
            offset = 0x0055,
            bitSize = 1,
            bitOffset = 13,
            mode = 'RW',
            name = 'LOCAL_MASTER')

        addVar(
            offset = 0x0055,
            bitSize = 1,
            bitOffset = 12,
            mode = 'RW',
            name = 'PCS_PCIE_EN',
            enum = {
                0 : 'FALSE',
                1 : 'TRUE'})

        addVar(
            offset = 0x0055,
            bitSize = 1,
            bitOffset = 11,
            mode = 'RW',
            name = 'PCIE_GEN4_64BIT_INT_EN',
            enum = {
                0 : 'FALSE',
                1 : 'TRUE'})

        addVar(
            offset = 0x0055,
            bitSize = 1,
            bitOffset = 10,
            mode = 'RW',
            name = 'ALIGN_MCOMMA_DET',
            enum = {
                0 : 'FALSE',
                1 : 'TRUE'})

        addVar(
            offset = 0x0055,
            bitSize = 10,
            bitOffset = 0,
            mode = 'RW',
            name = 'ALIGN_MCOMMA_VALUE')

        addVar(
            offset = 0x0056,
            bitSize = 1,
            bitOffset = 10,
            mode = 'RW',
            name = 'ALIGN_PCOMMA_DET',
            enum = {
                0 : 'FALSE',
                1 : 'TRUE'})

        addVar(
            offset = 0x0056,
            bitSize = 10,
            bitOffset = 0,
            mode = 'RW',
            name = 'ALIGN_PCOMMA_VALUE')



        addVar(
            offset = 0x0057,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'TX_PROGDIV_CFG',
            enum = {
                0 : '-',
                32768 : '0',
                57440 : '10',
                57455 : '100',
                24654 : '128',
                57862 : '132',
                57410 : '16',
                16.57880 : '5',
                57442 : '20',
                57414 : '32',
                57856 : '33',
                57432 : '4',
                57415 : '40',
                57464 : '5',
                57422 : '64',
                57858 : '66',
                57408 : '8',
                57423 : '80'})

        addVar(
            offset = 0x0058,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_OS_CFG0')

        addVar(
            offset = 0x0059,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXPHDLY_CFG')

        addVar(
            offset = 0x005A,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_OS_CFG1')

        addVar(
            offset = 0x005B,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDLY_CFG')

        addVar(
            offset = 0x005C,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDLY_LCFG')

        addVar(
            offset = 0x005D,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_HF_CFG0')

        addVar(
            offset = 0x005E,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_HD_CFG0')

        addVar(
            offset = 0x005F,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RX_BIAS_CFG0')

        addVar(
            overlapEn = True,
            offset = 0x0060,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'PCS_RSVD0')

        addVar(
            overlapEn = True,
            offset = 0x0060,
            bitSize = 5,
            bitOffset = 4,
            mode = 'RW',
            name = 'PCIE_GEN4_NEW_EIEOS_DET_EN')

        addVar(
            overlapEn = True,
            offset = 0x0060,
            bitSize = 2,
            bitOffset = 0,
            mode = 'RW',
             name = 'USB3_RXTERMINATION_CTRL')

        addVar(
            offset = 0x0061,
            bitSize = 5,
            bitOffset = 11,
            mode = 'RW',
            name = 'RXPH_MONITOR_SEL')

        addVar(
            offset = 0x0061,
            bitSize = 1,
            bitOffset = 10,
            mode = 'RW',
            name = 'RX_CM_BUF_PD')

        addVar(
            offset = 0x0061,
            bitSize = 4,
            bitOffset = 6,
            mode = 'RW',
            name = 'RX_CM_BUF_CFG')

        addVar(
            offset = 0x0061,
            bitSize = 4,
            bitOffset = 2,
            mode = 'RW',
            name = 'RX_CM_TRIM')

        addVar(
            offset = 0x0061,
            bitSize = 2,
            bitOffset = 0,
            mode = 'RW',
            name = 'RX_CM_SEL')

        addVar(
            offset = 0x0062,
            bitSize = 1,
            bitOffset = 15,
            mode = 'RW',
            name = 'RX_I2V_FILTER_EN')


        addVar(
            offset = 0x0062,
            bitSize = 1,
            bitOffset = 14,
            mode = 'RW',
            name = 'RX_SUM_DFETAPREP_EN')

        addVar(
            offset = 0x0062,
            bitSize = 1,
            bitOffset = 13,
            mode = 'RW',
            name = 'RX_SUM_VCM_OVWR')

        addVar(
            offset = 0x0062,
            bitSize = 4,
            bitOffset = 9,
            mode = 'RW',
            name = 'RX_SUM_IREF_TUNE')

        addVar(
            offset = 0x0062,
            bitSize = 2,
            bitOffset = 7,
            mode = 'RW',
            name = 'EYESCAN_VP_RANGE')

        addVar(
            offset = 0x0062,
            bitSize = 4,
            bitOffset = 3,
            mode = 'RW',
            name = 'RX_SUM_VCMTUNE')

        addVar(
            offset = 0x0062,
            bitSize = 3,
            bitOffset = 0,
            mode = 'RW',
            name = 'RX_SUM_VREF_TUNE')

        addVar(
            offset = 0x0063,
            bitSize = 1,
            bitOffset = 15,
            mode = 'RW',
            name = 'CBCC_DATA_SOURCE_SEL',
            enum = {
                1 : 'DECODED',
                0 : 'ENCODED'})

        addVar(
            offset = 0x0063,
            bitSize = 1,
            bitOffset = 14,
            mode = 'RW',
            name = 'OOB_PWRUP')

        addVar(
            offset = 0x0063,
            bitSize = 9,
            bitOffset = 5,
            mode = 'RW',
            name = 'RXOOB_CFG')

        addVar(
            offset = 0x0063,
            bitSize = 3,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXOUT_DIV',
            enum = {
                0 : '1',
                1 : '2',
                2 : '4',
                3 : '8',
                4 : '16',
                5 : '32'})

        addVar(
            offset = 0x0064,
            bitSize = 5,
            bitOffset = 11,
            mode = 'RW',
            name = 'RX_SIG_VALID_DLY',
            enum = {
                0 : '1',
                1 : '2',
                2 : '3',
                3 : '4',
                4 : '5',
                5 : '6',
                6 : '7',
                7 : '8',
                8 : '9',
                9 : '10',
                10 : '11',
                11 : '12',
                12 : '13',
                13 : '14',
                14 : '15',
                15 : '16',
                16 : '17',
                17 : '18',
                18 : '19',
                19 : '20',
                20 : '21',
                21 : '22',
                22 : '23',
                23 : '24',
                24 : '25',
                25 : '26',
                26 : '27',
                27 : '28',
                28 : '29',
                29 : '30',
                30 : '31',
                31 : '32'})

        addVar(
            offset = 0x0064,
            bitSize = 2,
            bitOffset = 9,
            mode = 'RW',
            name = 'RXSLIDE_MODE',
            enum = {
                0 : 'OFF',
                1 : 'AUTO',
                2 : 'PCS',
                3 : 'PMA'})

        addVar(
            offset = 0x0064,
            bitSize = 1,
            bitOffset = 8,
            mode = 'RW',
            name = 'RXPRBS_ERR_LOOPBACK')

        addVar(
            offset = 0x0064,
            bitSize = 4,
            bitOffset = 4,
            mode = 'RW',
            name = 'RXSLIDE_AUTO_WAIT')

        addVar(
            offset = 0x0064,
            bitSize = 1,
            bitOffset = 3,
            mode = 'RW',
            name = 'RXBUF_EN',
            enum = {
                0 : 'FALSE',
                1 : 'TRUE'})

        addVar(
            offset = 0x0064,
            bitSize = 2,
            bitOffset = 1,
            mode = 'RW',
            name = 'RX_XCLK_SEL',
            enum = {
                0 : 'RXDES',
                1 : 'RXUSR',
                2 : 'RXPMA'})

        addVar(
            offset = 0x0064,
            bitSize = 1,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXGEARBOX_EN',
            enum = {
                0 : 'FALSE',
                1 : 'TRUE'})

        addVar(
            offset = 0x0065,
            bitSize = 6,
            bitOffset = 10,
            mode = 'RW',
            name = 'RXBUF_THRESH_OVFLW')

        addVar(
            offset = 0x0065,
            bitSize = 10,
            bitOffset = 0,
            mode = 'RW',
            name = 'DMONITOR_CFG0')

        addVar(
            offset = 0x0066,
            bitSize = 1,
            bitOffset = 15,
            mode = 'RW',
            name = 'RXBUF_THRESH_OVRD',
            enum = {
                0 : 'FALSE',
                1 : 'TRUE'})

        addVar(
            offset = 0x0066,
            bitSize = 1,
            bitOffset = 14,
            mode = 'RW',
            name = 'RXBUF_RESET_ON_COMMAALIGN',
            enum = {
                0 : 'FALSE',
                1 : 'TRUE'})

        addVar(
            offset = 0x0066,
            bitSize = 1,
            bitOffset = 13,
            mode = 'RW',
            name = 'RXBUF_RESET_ON_RATE_CHANGE',
            enum = {
                0 : 'FALSE',
                1 : 'TRUE'})

        addVar(
            offset = 0x0066,
            bitSize = 1,
            bitOffset = 12,
            mode = 'RW',
            name = 'RXBUF_RESET_ON_CB_CHANGE',
            enum = {
                0 : 'FALSE',
                1 : 'TRUE'})

        addVar(
            offset = 0x0066,
            bitSize = 6,
            bitOffset = 6,
            mode = 'RW',
            name = 'RXBUF_THRESH_UNDFLW')

        addVar(
            offset = 0x0066,
            bitSize = 1,
            bitOffset = 5,
            mode = 'RW',
            name = 'RX_CLKMUX_EN')

        addVar(
            offset = 0x0066,
            bitSize = 1,
            bitOffset = 4,
            mode = 'RW',
            name = 'RX_DISPERR_SEQ_MATCH',
            enum = {
                0 : 'FALSE',
                1 : 'TRUE'})

        addVar(
            offset = 0x0066,
            bitSize = 2,
            bitOffset = 2,
            mode = 'RW',
            name = 'RX_WIDEMODE_CDR')

        addVar(
            offset = 0x0066,
            bitSize = 2,
            bitOffset = 0,
            mode = 'RW',
            name = 'RX_INT_DATAWIDTH')

        addVar(
            offset = 0x0067,
            bitSize = 4,
            bitOffset = 12,
            mode = 'RW',
            name = 'RXBUF_EIDLE_HI_CNT')

        addVar(
            offset = 0x0067,
            bitSize = 1,
            bitOffset = 11,
            mode = 'RW',
            name = 'RXCDR_HOLD_DURING_EIDLE')

        addVar(
            offset = 0x0067,
            bitSize = 1,
            bitOffset = 10,
            mode = 'RW',
            name = 'RX_DFE_LPM_HOLD_DURING_EIDLE')

        addVar(
            offset = 0x0067,
            bitSize = 2,
            bitOffset = 8,
            mode = 'RW',
            name = 'RX_WIDEMODE_CDR_GEN3')

        addVar(
            offset = 0x0067,
            bitSize = 4,
            bitOffset = 4,
            mode = 'RW',
            name = 'RXBUF_EIDLE_LO_CNT')

        addVar(
            offset = 0x0067,
            bitSize = 1,
            bitOffset = 3,
            mode = 'RW',
            name = 'RXBUF_RESET_ON_EIDLE',
            enum = {
                0 : 'FALSE',
                1 : 'TRUE'})

        addVar(
            offset = 0x0067,
            bitSize = 1,
            bitOffset = 2,
            mode = 'RW',
            name = 'RXCDR_FR_RESET_ON_EIDLE')

        addVar(
            offset = 0x0067,
            bitSize = 1,
            bitOffset = 1,
            mode = 'RW',
            name = 'RXCDR_PH_RESET_ON_EIDLE')

        addVar(
            offset = 0x0067,
            bitSize = 1,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXBUF_ADDR_MODE',
            enum = {
                1 : 'FAST',
                0 : 'FULL'})

        addVar(
            offset = 0x0068,
            bitSize = 3,
            bitOffset = 13,
            mode = 'RW',
            name = 'SATA_BURST_VAL')

        addVar(
            offset = 0x0068,
            bitSize = 1,
            bitOffset = 10,
            mode = 'RW',
            name = 'SAS_12G_MODE')

        addVar(
            offset = 0x0068,
            bitSize = 1,
            bitOffset = 9,
            mode = 'RW',
            name = 'USB_TXIDLE_TUNE_ENABLE')

        addVar(
            offset = 0x0068,
            bitSize = 1,
            bitOffset = 8,
            mode = 'RW',
            name = 'USB_RXIDLE_P0_CTRL')

        addVar(
            offset = 0x0068,
            bitSize = 4,
            bitOffset = 4,
            mode = 'RW',
            name = 'SATA_BURST_SEQ_LEN')

        addVar(
            offset = 0x0068,
            bitSize = 3,
            bitOffset = 0,
            mode = 'RW',
            name = 'SATA_EIDLE_VAL')

        addVar(
            offset = 0x0069,
            bitSize = 7,
            bitOffset = 9,
            mode = 'RW',
            name = 'USB_POLL_SATA_MIN_BURST')

        addVar(
            offset = 0x0069,
            bitSize = 2,
            bitOffset = 7,
            mode = 'RW',
            name = 'RX_WIDEMODE_CDR_GEN4')

        addVar(
            offset = 0x0069,
            bitSize = 7,
            bitOffset = 0,
            mode = 'RW',
            name = 'USB_U2_SAS_MIN_COM')

        addVar(
            offset = 0x006A,
            bitSize = 7,
            bitOffset = 9,
            mode = 'RW',
            name = 'USB_PING_SATA_MIN_INIT')

        addVar(
            offset = 0x006A,
            bitSize = 7,
            bitOffset = 0,
            mode = 'RW',
            name = 'USB_U1_SATA_MIN_WAKE')

        addVar(
            offset = 0x006B,
            bitSize = 7,
            bitOffset = 9,
            mode = 'RW',
            name = 'USB_POLL_SATA_MAX_BURST')

        addVar(
            offset = 0x006B,
            bitSize = 7,
            bitOffset = 0,
            mode = 'RW',
            name = 'USB_U2_SAS_MAX_COM')

        addVar(
            offset = 0x006C,
            bitSize = 7,
            bitOffset = 9,
            mode = 'RW',
            name = 'USB_PING_SATA_MAX_INIT')

        addVar(
            offset = 0x006C,
            bitSize = 7,
            bitOffset = 0,
            mode = 'RW',
            name = 'USB_U1_SATA_MAX_WAKE')

        addVar(
            offset = 0x006D,
            bitSize = 5,
            bitOffset = 3,
            mode = 'RW',
            name = 'RX_CLK25_DIV',
            enum = {
                0 : '1',
                1 : '2',
                2 : '3',
                3 : '4',
                4 : '5',
                5 : '6',
                6 : '7',
                7 : '8',
                8 : '9',
                9 : '10',
                10 : '11',
                11 : '12',
                12 : '13',
                13 : '14',
                14 : '15',
                15 : '16',
                16 : '17',
                17 : '18',
                18 : '19',
                19 : '20',
                20 : '21',
                21 : '22',
                22 : '23',
                23 : '24',
                24 : '25',
                25 : '26',
                26 : '27',
                27 : '28',
                28 : '29',
                29 : '30',
                30 : '31',
                31 : '32'})

        addVar(
            offset = 0x006E,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_UT_CFG1')

        addVar(
            offset = 0x006F,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'TXPHDLY_CFG1')

        addVar(
            offset = 0x0070,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_VP_CFG0')

        addVar(
            offset = 0x0071,
            bitSize = 5,
            bitOffset = 2,
            mode = 'RW',
            name = 'TXPH_MONITOR_SEL')

        addVar(
            offset = 0x0071,
            bitSize = 2,
            bitOffset = 0,
            mode = 'RW',
            name = 'TAPDLY_SET_TX')

        addVar(
            offset = 0x0072,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'ADAPT_CFG2')

        addVar(
            offset = 0x0073,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_VP_CFG1')

        addVar(
            offset = 0x0074,
            bitSize = 15,
            bitOffset = 0,
            mode = 'RW',
            name = 'TERM_RCAL_CFG')

        addVar(
            offset = 0x0075,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXPI_CFG0')

        addVar(
            offset = 0x0076,
            bitSize = 12,
            bitOffset = 4,
            mode = 'RW',
            name = 'PD_TRANS_TIME_FROM_P2')

        addVar(
            offset = 0x0076,
            bitSize = 3,
            bitOffset = 1,
            mode = 'RW',
            name = 'TERM_RCAL_OVRD')

        addVar(
            offset = 0x0077,
            bitSize = 8,
            bitOffset = 8,
            mode = 'RW',
            name = 'PD_TRANS_TIME_NONE_P2')

        addVar(
            offset = 0x0077,
            bitSize = 8,
            bitOffset = 0,
            mode = 'RW',
            name = 'PD_TRANS_TIME_TO_P2')

        addVar(
            offset = 0x0078,
            bitSize = 8,
            bitOffset = 8,
            mode = 'RW',
            name = 'TRANS_TIME_RATE')

        addVar(
            offset = 0x0079,
            bitSize = 8,
            bitOffset = 8,
            mode = 'RW',
            name = 'TST_RSV0')

        addVar(
            offset = 0x0079,
            bitSize = 8,
            bitOffset = 0,
            mode = 'RW',
            name = 'TST_RSV1')

        addVar(
            offset = 0x007A,
            bitSize = 5,
            bitOffset = 11,
            mode = 'RW',
            name = 'TX_CLK25_DIV',
            enum = {
                0 : '1',
                1 : '2',
                2 : '3',
                3 : '4',
                4 : '5',
                5 : '6',
                6 : '7',
                7 : '8',
                8 : '9',
                9 : '10',
                10 : '11',
                11 : '12',
                12 : '13',
                13 : '14',
                14 : '15',
                15 : '16',
                16 : '17',
                17 : '18',
                18 : '19',
                19 : '20',
                20 : '21',
                21 : '22',
                22 : '23',
                23 : '24',
                24 : '25',
                25 : '26',
                26 : '27',
                27 : '28',
                28 : '29',
                29 : '30',
                30 : '31',
                31 : '32'})

        addVar(
            offset = 0x007A,
            bitSize = 1,
            bitOffset = 10,
            mode = 'RW',
            name = 'TX_XCLK_SEL',
            enum = {
                0 : 'TXOUT',
                1 : 'TXUSR'})

        addVar(
            offset = 0x007A,
            bitSize = 4,
            bitOffset = 0,
            mode = 'RW',
            name = 'TX_DATA_WIDTH',
            enum = {
                0 : '-',
                2 : '16',
                3 : '20',
                4 : '32',
                5 : '40',
                6 : '64',
                7 : '80',
                8 : '128',
                9 : '160'})

        addVar(
            offset = 0x007B,
            bitSize = 6,
            bitOffset = 10,
            mode = 'RW',
            name = 'TX_DEEMPH0')

        addVar(
            offset = 0x007B,
            bitSize = 6,
            bitOffset = 2,
            mode = 'RW',
            name = 'TX_DEEMPH1')

        addVar(
            offset = 0x007C,
            bitSize = 1,
            bitOffset = 14,
            mode = 'RW',
            name = 'TX_MAINCURSOR_SEL')

        addVar(
            offset = 0x007C,
            bitSize = 1,
            bitOffset = 13,
            mode = 'RW',
            name = 'TXGEARBOX_EN',
            enum = {
                0 : 'FALSE',
                1 : 'TRUE'})

        addVar(
            offset = 0x007C,
            bitSize = 3,
            bitOffset = 8,
            mode = 'RW',
            name = 'TXOUT_DIV',
            enum = {
                0 : '1',
                1 : '2',
                2 : '4',
                3 : '8',
                4 : '16',
                5 : '32'})

        addVar(
            offset = 0x007C,
            bitSize = 1,
            bitOffset = 7,
            mode = 'RW',
            name = 'TXBUF_EN',
            enum = {
                0 : 'FALSE',
                1 : 'TRUE'})

        addVar(
            offset = 0x007C,
            bitSize = 1,
            bitOffset = 6,
            mode = 'RW',
            name = 'TXBUF_RESET_ON_RATE_CHANGE',
            enum = {
                0 : 'FALSE',
                1 : 'TRUE'})

        addVar(
            offset = 0x007C,
            bitSize = 3,
            bitOffset = 3,
            mode = 'RW',
            name = 'TX_RXDETECT_REF')

        addVar(
            offset = 0x007C,
            bitSize = 1,
            bitOffset = 2,
            mode = 'RW',
            name = 'TXFIFO_ADDR_CFG',
            enum = {
                1 : 'HIGH',
                0 : 'LOW'})

        addVar(
            offset = 0x007C,
            bitSize = 2,
            bitOffset = 0,
            mode = 'RW',
            name = 'TX_SW_MEAS')

        addVar(
            offset = 0x007D,
            bitSize = 14,
            bitOffset = 2,
            mode = 'RW',
            name = 'TX_RXDETECT_CFG')

        addVar(
            offset = 0x007E,
            bitSize = 1,
            bitOffset = 15,
            mode = 'RW',
            name = 'TX_CLKMUX_EN')

        addVar(
            offset = 0x007E,
            bitSize = 1,
            bitOffset = 14,
            mode = 'RW',
            name = 'TX_LOOPBACK_DRIVE_HIZ',
            enum = {
                0 : 'FALSE',
                1 : 'TRUE'})

        addVar(
            offset = 0x007E,
            bitSize = 5,
            bitOffset = 8,
            mode = 'RW',
            name = 'TX_DRIVE_MODE',
            enum = {
                0 : 'DIRECT',
                1 : 'PIPE',
                2 : 'PIPEGEN3'})

        addVar(
            offset = 0x007E,
            bitSize = 3,
            bitOffset = 5,
            mode = 'RW',
            name = 'TX_EIDLE_ASSERT_DELAY')

        addVar(
            offset = 0x007E,
            bitSize = 3,
            bitOffset = 2,
            mode = 'RW',
            name = 'TX_EIDLE_DEASSERT_DELAY')

        addVar(
            offset = 0x007F,
            bitSize = 7,
            bitOffset = 9,
            mode = 'RW',
            name = 'TX_MARGIN_FULL_0')

        addVar(
            offset = 0x007F,
            bitSize = 7,
            bitOffset = 1,
            mode = 'RW',
            name = 'TX_MARGIN_FULL_1')

        addVar(
            offset = 0x0080,
            bitSize = 7,
            bitOffset = 9,
            mode = 'RW',
            name = 'TX_MARGIN_FULL_2')

        addVar(
            offset = 0x0080,
            bitSize = 7,
            bitOffset = 1,
            mode = 'RW',
            name = 'TX_MARGIN_FULL_3')

        addVar(
            offset = 0x0081,
            bitSize = 7,
            bitOffset = 9,
            mode = 'RW',
            name = 'TX_MARGIN_FULL_4')

        addVar(
            offset = 0x0081,
            bitSize = 7,
            bitOffset = 1,
            mode = 'RW',
            name = 'TX_MARGIN_LOW_0')

        addVar(
            offset = 0x0082,
            bitSize = 7,
            bitOffset = 9,
            mode = 'RW',
            name = 'TX_MARGIN_LOW_1')

        addVar(
            offset = 0x0082,
            bitSize = 7,
            bitOffset = 1,
            mode = 'RW',
            name = 'TX_MARGIN_LOW_2')

        addVar(
            offset = 0x0083,
            bitSize = 7,
            bitOffset = 9,
            mode = 'RW',
            name = 'TX_MARGIN_LOW_3')

        addVar(
            offset = 0x0083,
            bitSize = 7,
            bitOffset = 1,
            mode = 'RW',
            name = 'TX_MARGIN_LOW_4')

        addVar(
            offset = 0x0084,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_H3_CFG0')

        addVar(
            offset = 0x0085,
            bitSize = 2,
            bitOffset = 10,
            mode = 'RW',
            name = 'TX_INT_DATAWIDTH')

        addVar(
            offset = 0x0089,
            bitSize = 8,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXPRBS_LINKACQ_CNT')

        addVar(
            offset = 0x008A,
            bitSize = 1,
            bitOffset = 15,
            mode = 'RW',
            name = 'TX_PMADATA_OPT')

        addVar(
            offset = 0x008A,
            bitSize = 1,
            bitOffset = 14,
            mode = 'RW',
            name = 'RXSYNC_OVRD')

        addVar(
            offset = 0x008A,
            bitSize = 1,
            bitOffset = 13,
            mode = 'RW',
            name = 'TXSYNC_OVRD')

        addVar(
            offset = 0x008A,
            bitSize = 1,
            bitOffset = 12,
            mode = 'RW',
            name = 'TX_IDLE_DATA_ZERO')

        addVar(
            offset = 0x008A,
            bitSize = 1,
            bitOffset = 11,
            mode = 'RW',
            name = 'A_RXOSCALRESET')

        addVar(
            offset = 0x008A,
            bitSize = 1,
            bitOffset = 10,
            mode = 'RW',
            name = 'RXOOB_CLK_CFG',
            enum = {
                1 : 'FABRIC',
                0 : 'PMA'})

        addVar(
            offset = 0x008A,
            bitSize = 1,
            bitOffset = 9,
            mode = 'RW',
            name = 'TXSYNC_SKIP_DA')

        addVar(
            offset = 0x008A,
            bitSize = 1,
            bitOffset = 8,
            mode = 'RW',
            name = 'RXSYNC_SKIP_DA')

        addVar(
            offset = 0x008A,
            bitSize = 5,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXOSCALRESET_TIME')

        addVar(
            offset = 0x008B,
            bitSize = 1,
            bitOffset = 10,
            mode = 'RW',
            name = 'TXSYNC_MULTILANE')

        addVar(
            offset = 0x008B,
            bitSize = 1,
            bitOffset = 9,
            mode = 'RW',
            name = 'RXSYNC_MULTILANE')

        addVar(
            offset = 0x008C,
            bitSize = 1,
            bitOffset = 15,
            mode = 'RW',
            name = 'ACJTAG_MODE')

        addVar(
            offset = 0x008C,
            bitSize = 1,
            bitOffset = 14,
            mode = 'RW',
            name = 'ACJTAG_DEBUG_MODE')

        addVar(
            offset = 0x008C,
            bitSize = 1,
            bitOffset = 13,
            mode = 'RW',
            name = 'ACJTAG_RESET')

        addVar(
            offset = 0x008C,
            bitSize = 1,
            bitOffset = 12,
            mode = 'RW',
            name = 'RX_SUM_VCM_BIAS_TUNE_EN')

        addVar(
            offset = 0x008C,
            bitSize = 2,
            bitOffset = 10,
            mode = 'RW',
            name = 'RX_TUNE_AFE_OS')

        addVar(
            offset = 0x008C,
            bitSize = 2,
            bitOffset = 8,
            mode = 'RW',
            name = 'RX_DFE_KL_LPM_KL_CFG0')

        addVar(
            offset = 0x008C,
            bitSize = 3,
            bitOffset = 5,
            mode = 'RW',
            name = 'RX_DFE_KL_LPM_KL_CFG1')


        addVar(
            offset = 0x008C,
            bitSize = 1,
            bitOffset = 4,
            mode = 'RW',
            name = 'RX_SUM_DEGEN_AVTT_OVERITE')

        addVar(
            offset = 0x008C,
            bitSize = 1,
            bitOffset = 3,
            mode = 'RW',
            name = 'RX_SUM_PWR_SAVING')

        addVar(
            offset = 0x008C,
            bitSize = 1,
            bitOffset = 2,
            mode = 'RW',
            name = 'RX_EN_SUM_RCAL_B')

        addVar(
            offset = 0x008D,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFELPM_KL_CFG2')

        addVar(
            offset = 0x008E,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'TXDLY_CFG')

        addVar(
            offset = 0x008F,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'TXPH_CFG')

        addVar(
            offset = 0x0090,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'TXPHDLY_CFG0')

        addVar(
            offset = 0x0091,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'ADAPT_CFG0')

        addVar(
            offset = 0x0092,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'ADAPT_CFG1')

        addVar(
            offset = 0x0093,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXCFOK_CFG0')

        addVar(
            offset = 0x0094,
            bitSize = 1,
            bitOffset = 11,
            mode = 'RW',
            name = 'ES_CLK_PHASE_SEL')

        addVar(
            offset = 0x0094,
            bitSize = 1,
            bitOffset = 10,
            mode = 'RW',
            name = 'USE_PCS_CLK_PHASE_SEL')

        addVar(
            offset = 0x0094,
            bitSize = 1,
            bitOffset = 9,
            mode = 'RW',
            name = 'SAMPLE_CLK_PHASE')

        addVar(
            offset = 0x0095,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'TX_PMA_RSV0')

        addVar(
            offset = 0x0097,
            bitSize = 1,
            bitOffset = 12,
            mode = 'RW',
            name = 'RX_AFE_CM_EN')

        addVar(
            offset = 0x0097,
            bitSize = 1,
            bitOffset = 11,
            mode = 'RW',
            name = 'RX_CAPFF_SARC_ENB')

        addVar(
            offset = 0x0097,
            bitSize = 1,
            bitOffset = 10,
            mode = 'RW',
            name = 'RX_EYESCAN_VS_NEG_DIR')

        addVar(
            offset = 0x0097,
            bitSize = 1,
            bitOffset = 9,
            mode = 'RW',
            name = 'RX_EYESCAN_VS_UT_SIGN')

        addVar(
            offset = 0x0097,
            bitSize = 7,
            bitOffset = 2,
            mode = 'RW',
            name = 'RX_EYESCAN_VS_CODE')

        addVar(
            offset = 0x0097,
            bitSize = 2,
            bitOffset = 0,
            mode = 'RW',
            name = 'RX_EYESCAN_VS_RANGE')

        addVar(
            offset = 0x0098,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_H5_CFG1')

        addVar(
            offset = 0x0099,
            bitSize = 5,
            bitOffset = 11,
            mode = 'RW',
            name = 'GEARBOX_MODE')

        addVar(
            offset = 0x0099,
            bitSize = 3,
            bitOffset = 8,
            mode = 'RW',
            name = 'TXPI_SYNFREQ_PPM')

        addVar(
            offset = 0x0099,
            bitSize = 1,
            bitOffset = 6,
            mode = 'RW',
            name = 'TXPI_INVSTROBE_SEL')

        addVar(
            offset = 0x0099,
            bitSize = 1,
            bitOffset = 5,
            mode = 'RW',
            name = 'TXPI_GRAY_SEL')

        addVar(
            offset = 0x009A,
            bitSize = 8,
            bitOffset = 0,
            mode = 'RW',
            name = 'TXPI_PPM_CFG')

        addVar(
            offset = 0x009B,
            bitSize = 1,
            bitOffset = 15,
            mode = 'RW',
            name = 'RX_DFELPM_KLKH_AGC_STUP_EN')

        addVar(
            offset = 0x009B,
            bitSize = 4,
            bitOffset = 11,
            mode = 'RW',
            name = 'RX_DFELPM_CFG0')

        addVar(
            offset = 0x009B,
            bitSize = 1,
            bitOffset = 10,
            mode = 'RW',
            name = 'RX_DFELPM_CFG1')

        addVar(
            offset = 0x009B,
            bitSize = 2,
            bitOffset = 8,
            mode = 'RW',
            name = 'RX_DFE_KL_LPM_KH_CFG0')

        addVar(
            offset = 0x009B,
            bitSize = 3,
            bitOffset = 5,
            mode = 'RW',
            name = 'RX_DFE_KL_LPM_KH_CFG1')

        addVar(
            offset = 0x009D,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'TXFE_CFG0')

        addVar(
            offset = 0x009E,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_UT_CFG0')

        addVar(
            offset = 0x009F,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'CPLL_CFG0')


        addVar(
            offset = 0x00A0,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'CPLL_CFG1')

        addVar(
            offset = 0x00A1,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'TXFE_CFG1')

        addVar(
            offset = 0x00A2,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXCDR_CFG0_GEN3')

        addVar(
            offset = 0x00A3,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXCDR_CFG1_GEN3')

        addVar(
            offset = 0x00A4,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXCDR_CFG2_GEN3')

        addVar(
            offset = 0x00A5,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXCDR_CFG3_GEN3')

        addVar(
            offset = 0x00A6,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXCDR_CFG4_GEN3')

        addVar(
            offset = 0x00A7,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'TXPI_CFG0')

        addVar(
            offset = 0x00A8,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'TXPI_CFG1')

        addVar(
            offset = 0x00A9,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'PCIE_RXPMA_CFG')

        addVar(
            offset = 0x00AA,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'PCIE_TXPCS_CFG_GEN3')

        addVar(
            offset = 0x00AB,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'PCIE_TXPMA_CFG')

        addVar(
            offset = 0x00AC,
            bitSize = 5,
            bitOffset = 3,
            mode = 'RW',
            name = 'RX_CLK_SLIP_OVRD')

        addVar(
            offset = 0x00AC,
            bitSize = 1,
            bitOffset = 0,
            mode = 'RW',
            name = 'TXPI_PPM')

        addVar(
            offset = 0x00AD,
            bitSize = 2,
            bitOffset = 13,
            mode = 'RW',
            name = 'PCIE_PLL_SEL_MODE_GEN4')

        addVar(
            offset = 0x00AD,
            bitSize = 2,
            bitOffset = 11,
            mode = 'RW',
            name = 'PCIE_PLL_SEL_MODE_GEN3')

        addVar(
            offset = 0x00AD,
            bitSize = 2,
            bitOffset = 9,
            mode = 'RW',
            name = 'PCIE_PLL_SEL_MODE_GEN12')

        addVar(
            offset = 0x00AD,
            bitSize = 1,
            bitOffset = 8,
            mode = 'RW',
            name = 'RATE_SW_USE_DRP')

        addVar(
            offset = 0x00AE,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_HD_CFG1')

        addVar(
            offset = 0x00AF,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXCDR_CFG5_GEN3')

        addVar(
            offset = 0x00B0,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_KH_CFG3')

        addVar(
            offset = 0x00B1,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_KH_CFG2')

        addVar(
            offset = 0x00B2,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_KH_CFG1')

        addVar(
            offset = 0x00B3,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_H5_CFG0')

        addVar(
            offset = 0x00B4,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXCDR_CFG5')

        addVar(
            offset = 0x00B5,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_HE_CFG1')

        addVar(
            offset = 0x00B6,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'CPLL_CFG3')

        addVar(
            offset = 0x00B7,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_H6_CFG0')

        addVar(
            offset = 0x00B8,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_H6_CFG1')

        addVar(
            offset = 0x00B9,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_H7_CFG0')

        addVar(
            offset = 0x00BA,
            bitSize = 5,
            bitOffset = 2,
            mode = 'RW',
            name = 'DDI_REALIGN_WAIT')

        addVar(
            offset = 0x00BA,
            bitSize = 2,
            bitOffset = 0,
            mode = 'RW',
            name = 'DDI_CTRL')

        addVar(
            offset = 0x00BB,
            bitSize = 3,
            bitOffset = 9,
            mode = 'RW',
            name = 'TXGBOX_FIFO_INIT_RD_ADDR')

        addVar(
            offset = 0x00BB,
            bitSize = 3,
            bitOffset = 6,
            mode = 'RW',
            name = 'TX_SAMPLE_PERIOD')


        addVar(
            offset = 0x00BB,
            bitSize = 3,
            bitOffset = 3,
            mode = 'RW',
            name = 'RXGBOX_FIFO_INIT_RD_ADDR')

        addVar(
            offset = 0x00BB,
            bitSize = 3,
            bitOffset = 0,
            mode = 'RW',
            name = 'RX_SAMPLE_PERIOD')

        addVar(
            offset = 0x00BC,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'CPLL_CFG2')

        addVar(
            offset = 0x00BD,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXPHSAMP_CFG')

        addVar(
            offset = 0x00BE,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXPHSLIP_CFG')

        addVar(
            offset = 0x00BF,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXPHBEACON_CFG')

        addVar(
            offset = 0x00C0,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_H7_CFG1')

        addVar(
            offset = 0x00C1,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_H8_CFG0')

        addVar(
            offset = 0x00C2,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_H8_CFG1')

        addVar(
            offset = 0x00C3,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'PCIE_BUFG_DIV_CTRL')

        addVar(
            offset = 0x00C4,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'PCIE_RXPCS_CFG_GEN3')

        addVar(
            offset = 0x00C5,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_H9_CFG0')

        addVar(
            offset = 0x00C6,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RX_PROGDIV_CFG',
            enum = {
                0 : '-',
                32768 : '0',
                57440 : '10',
                57455 : '100',
                24654 : '128',
                57862 : '132',
                57410 : '16',
                16.57880 : '5',
                57442 : '20',
                57414 : '32',
                57856 : '33',
                57432 : '4',
                57415 : '40',
                57464 : '5',
                57422 : '64',
                57858 : '66',
                57408 : '8',
                57423 : '80'})

        addVar(
            offset = 0x00C7,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_H9_CFG1')

        addVar(
            offset = 0x00C8,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_HA_CFG0')

        addVar(
            offset = 0x00CA,
            bitSize = 10,
            bitOffset = 0,
            mode = 'RW',
            name = 'CHAN_BOND_SEQ_1_2')

        addVar(
            offset = 0x00CB,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_GC_CFG0')

        addVar(
            offset = 0x00CC,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_GC_CFG1')


        addVar(
            offset = 0x00CD,
            bitSize = 6,
            bitOffset = 2,
            mode = 'RW',
            name = 'RX_DDI_SEL')

        addVar(
            offset = 0x00CD,
            bitSize = 1,
            bitOffset = 1,
            mode = 'RW',
            name = 'DEC_VALID_COMMA_ONLY',
            enum = {
                0 : 'FALSE',
                1 : 'TRUE'})

        addVar(
            offset = 0x00CD,
            bitSize = 1,
            bitOffset = 0,
            mode = 'RW',
            name = 'DEC_MCOMMA_DETECT',
            enum = {
                0 : 'FALSE',
                1 : 'TRUE'})


        addVar(
            offset = 0x00CE,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_CFG0')

        addVar(
            offset = 0x00CF,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_CFG1')

        addVar(
            offset = 0x00D0,
            bitSize = 1,
            bitOffset = 8,
            mode = 'RW',
            name = 'RX_RESLOAD_OVRD')

        addVar(
            offset = 0x00D0,
            bitSize = 1,
            bitOffset = 7,
            mode = 'RW',
            name = 'RX_CTLE_PWR_SAVING')

        addVar(
            offset = 0x00D0,
            bitSize = 3,
            bitOffset = 4,
            mode = 'RW',
            name = 'RX_DEGEN_CTRL')

        addVar(
            offset = 0x00D0,
            bitSize = 4,
            bitOffset = 0,
            mode = 'RW',
            name = 'RX_RESLOAD_CTRL')

        addVar(
            offset = 0x00D1,
            bitSize = 1,
            bitOffset = 12,
            mode = 'RW',
            name = 'RX_EN_CTLE_RCAL_B')

        addVar(
            offset = 0x00D1,
            bitSize = 4,
            bitOffset = 8,
            mode = 'RW',
            name = 'RX_CTLE_RES_CTRL')

        addVar(
            offset = 0x00D1,
            bitSize = 4,
            bitOffset = 0,
            mode = 'RW',
            name = 'RX_SUM_RES_CTRL')

        addVar(
            offset = 0x00D2,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXPI_CFG1')

        addVar(
            offset = 0x00D3,
            bitSize = 1,
            bitOffset = 13,
            mode = 'RW',
            name = 'LPBK_EN_RCAL_B')

        addVar(
            offset = 0x00D3,
            bitSize = 3,
            bitOffset = 5,
            mode = 'RW',
            name = 'LPBK_IND_CTRL2')

        addVar(
            offset = 0x00D3,
            bitSize = 3,
            bitOffset = 2,
            mode = 'RW',
            name = 'LPBK_BIAS_CTRL')

        addVar(
            offset = 0x00D3,
            bitSize = 1,
            bitOffset = 1,
            mode = 'RW',
            name = 'RX_XMODE_SEL')

        addVar(
            offset = 0x00D3,
            bitSize = 1,
            bitOffset = 0,
            mode = 'RW',
            name = 'ISCAN_CK_PH_SEL2')

        addVar(
            offset = 0x00D4,
            bitSize = 3,
            bitOffset = 11,
            mode = 'RW',
            name = 'LPBK_IND_CTRL1')

        addVar(
            offset = 0x00D4,
            bitSize = 4,
            bitOffset = 7,
            mode = 'RW',
            name = 'LPBK_RG_CTRL')

        addVar(
            offset = 0x00D4,
            bitSize = 3,
            bitOffset = 0,
            mode = 'RW',
            name = 'LPBK_IND_CTRL0')

        addVar(
            overlapEn = True,
            offset = 0x00D5,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'CKCAL1_CFG_3')

        addVar(
            overlapEn = True,
            offset = 0x00D5,
            bitSize = 2,
            bitOffset = 1,
            mode = 'RW',
            name = 'CKCAL1_DCC_PWRDN')

        addVar(
            overlapEn = True,
            offset = 0x00D5,
            bitSize = 1,
            bitOffset = 0,
            mode = 'RW',
            name = 'CKCAL1_IQ_PWRDN')

        addVar(
            offset = 0x00D6,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'CKCAL2_CFG_3')

        addVar(
            offset = 0x00D7,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'CKCAL2_CFG_4')

        addVar(
            offset = 0x00D8,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RX_PMA_RSV0')

        addVar(
            offset = 0x00D9,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'CKCAL2_CFG_2')

        addVar(
            offset = 0x00DA,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXCDR_LOCK_CFG2')

        addVar(
            offset = 0x00DB,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'CKCAL1_CFG_2')

        addVar(
            offset = 0x00DD,
            bitSize = 2,
            bitOffset = 3,
            mode = 'RW',
            name = 'RTX_BUF_TERM_CTRL')

        addVar(
            offset = 0x00DD,
            bitSize = 3,
            bitOffset = 0,
            mode = 'RW',
            name = 'RTX_BUF_CML_CTRL')


        addVar(
            offset = 0x00DE,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'TXPH_CFG2')

        addVar(
            offset = 0x00DF,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXCDR_LOCK_CFG4')

        addVar(
            offset = 0x00E0,
            bitSize = 3,
            bitOffset = 6,
            mode = 'RW',
            name = 'CTLE3_OCAP_EXT_CTRL')

        addVar(
            offset = 0x00E0,
            bitSize = 1,
            bitOffset = 5,
            mode = 'RW',
            name = 'CTLE3_OCAP_EXT_EN')

        addVar(
            offset = 0x00E2,
            bitSize = 2,
            bitOffset = 12,
            mode = 'RW',
            name = 'TX_VREG_VREFSEL')

        addVar(
            offset = 0x00E2,
            bitSize = 3,
            bitOffset = 9,
            mode = 'RW',
            name = 'TX_VREG_CTRL')

        addVar(
            offset = 0x00E2,
            bitSize = 1,
            bitOffset = 8,
            mode = 'RW',
            name = 'TX_VREG_PDB')

        addVar(
            offset = 0x00E7,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'ES_QUALIFIER5')

        addVar(
            offset = 0x00E8,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'ES_QUALIFIER6')

        addVar(
            offset = 0x00E9,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'ES_QUALIFIER7')

        addVar(
            offset = 0x00EA,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'ES_QUALIFIER8')

        addVar(
            offset = 0x00EB,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'ES_QUALIFIER9')

        addVar(
            offset = 0x00EC,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'ES_QUAL_MASK5')

        addVar(
            offset = 0x00ED,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'ES_QUAL_MASK6')

        addVar(
            offset = 0x00EE,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'ES_QUAL_MASK7')

        addVar(
            offset = 0x00EF,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'ES_QUAL_MASK8')

        addVar(
            offset = 0x00F0,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'ES_QUAL_MASK9')

        addVar(
            offset = 0x00F1,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'ES_SDATA_MASK5')

        addVar(
            offset = 0x00F2,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'ES_SDATA_MASK6')

        addVar(
            offset = 0x00F3,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'ES_SDATA_MASK7')

        addVar(
            offset = 0x00F4,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'ES_SDATA_MASK8')

        addVar(
            offset = 0x00F5,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'ES_SDATA_MASK9')

        addVar(
            offset = 0x00F6,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'TX_PMA_RSV1')

        addVar(
            offset = 0x00F7,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'CKCAL1_CFG_0')

        addVar(
            offset = 0x00F8,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'CKCAL1_CFG_1')

        addVar(
            offset = 0x00F9,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'CKCAL2_CFG_0')

        addVar(
            offset = 0x00FA,
            bitSize = 3,
            bitOffset = 13,
            mode = 'RW',
            name = 'TXSWBST_MAG')

        addVar(
            offset = 0x00FA,
            bitSize = 2,
            bitOffset = 9,
            mode = 'RW',
            name = 'TXDRV_FREQBAND')

        addVar(
            offset = 0x00FA,
            bitSize = 2,
            bitOffset = 7,
            mode = 'RW',
            name = 'TXSWBST_BST')

        addVar(
            offset = 0x00FA,
            bitSize = 1,
            bitOffset = 6,
            mode = 'RW',
            name = 'TXSWBST_EN')

        addVar(
            offset = 0x00FA,
            bitSize = 3,
            bitOffset = 1,
            mode = 'RW',
            name = 'RX_VREG_CTRL')

        addVar(
            offset = 0x00FA,
            bitSize = 1,
            bitOffset = 0,
            mode = 'RW',
            name = 'RX_VREG_PDB')

        addVar(
            offset = 0x00FB,
            bitSize = 4,
            bitOffset = 6,
            mode = 'RW',
            name = 'LPBK_EXT_RCAL')

        addVar(
            offset = 0x00FB,
            bitSize = 2,
            bitOffset = 4,
            mode = 'RW',
            name = 'PREIQ_FREQ_BST')


        addVar(
            offset = 0x00FB,
            bitSize = 2,
            bitOffset = 1,
            mode = 'RW',
            name = 'TX_PI_BIASSET')

        addVar(
            offset = 0x00FC,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'TX_PHICAL_CFG0')

        addVar(
            offset = 0x00FD,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'TX_PHICAL_CFG1')

        addVar(
            offset = 0x00FE,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXCDR_LOCK_CFG3')

        addVar(
            offset = 0x0100,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_UT_CFG2')

        addVar(
            offset = 0x0101,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'CKCAL2_CFG_1')

        addVar(
            offset = 0x0102,
            bitSize = 1,
            bitOffset = 2,
            mode = 'RW',
            name = 'Y_ALL_MODE')

        addVar(
            offset = 0x0102,
            bitSize = 1,
            bitOffset = 1,
            mode = 'RW',
            name = 'RCLK_SIPO_DLY_ENB')

        addVar(
            offset = 0x0102,
            bitSize = 1,
            bitOffset = 0,
            mode = 'RW',
            name = 'RCLK_SIPO_INV_EN')

        addVar(
            offset = 0x0103,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RX_PROGDIV_RATE')

        addVar(
            offset = 0x0104,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_HF_CFG1')

        addVar(
            offset = 0x0105,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'TX_PROGDIV_RATE')

        addVar(
            offset = 0x0106,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'TX_DCC_LOOP_RST_CFG')

        addVar(
            offset = 0x0107,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_HC_CFG0')

        addVar(
            offset = 0x0108,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXCKCAL1_I_LOOP_RST_CFG')

        addVar(
            offset = 0x0109,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXCKCAL1_Q_LOOP_RST_CFG')

        addVar(
            offset = 0x010A,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXCKCAL1_IQ_LOOP_RST_CFG')

        addVar(
            offset = 0x010B,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXCKCAL2_D_LOOP_RST_CFG')

        addVar(
            offset = 0x010C,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXCKCAL2_X_LOOP_RST_CFG')

        addVar(
            offset = 0x010D,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXCKCAL2_S_LOOP_RST_CFG')

        addVar(
            offset = 0x010E,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXCKCAL2_DX_LOOP_RST_CFG')

        addVar(
            offset = 0x0110,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_KH_CFG0')

        addVar(
            offset = 0x0111,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_H4_CFG1')

        addVar(
            offset = 0x0112,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_H4_CFG0')

        addVar(
            offset = 0x0113,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_H3_CFG1')

        addVar(
            offset = 0x0116,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'CH_HSPMUX')

        addVar(
            offset = 0x0117,
            bitSize = 5,
            bitOffset = 11,
            mode = 'RW',
            name = 'PCIE3_CLK_COR_MIN_LAT')

        addVar(
            offset = 0x0117,
            bitSize = 5,
            bitOffset = 6,
            mode = 'RW',
            name = 'PCIE3_CLK_COR_MAX_LAT')

        addVar(
            offset = 0x0117,
            bitSize = 6,
            bitOffset = 0,
            mode = 'RW',
            name = 'PCIE3_CLK_COR_THRSH_TIMER')

        addVar(
            offset = 0x0118,
            bitSize = 1,
            bitOffset = 15,
            mode = 'RW',
            name = 'USB_MODE')

        addVar(
            offset = 0x0118,
            bitSize = 1,
            bitOffset = 14,
            mode = 'RW',
            name = 'USB_EXT_CNTL')

        addVar(
            offset = 0x0118,
            bitSize = 1,
            bitOffset = 13,
            mode = 'RW',
            name = 'USB_CLK_COR_EQ_EN')

        addVar(
            offset = 0x0118,
            bitSize = 1,
            bitOffset = 12,
            mode = 'RW',
            name = 'USB_PCIE_ERR_REP_DIS')

        addVar(
            offset = 0x0118,
            bitSize = 6,
            bitOffset = 6,
            mode = 'RW',
            name = 'PCIE3_CLK_COR_FULL_THRSH')


        addVar(
            offset = 0x0118,
            bitSize = 5,
            bitOffset = 0,
            mode = 'RW',
            name = 'PCIE3_CLK_COR_EMPTY_THRSH')

        addVar(
            offset = 0x0119,
            bitSize = 1,
            bitOffset = 15,
            mode = 'RW',
            name = 'USB_RAW_ELEC')

        addVar(
            offset = 0x0119,
            bitSize = 1,
            bitOffset = 14,
            mode = 'RW',
            name = 'DELAY_ELEC')

        addVar(
            offset = 0x0119,
            bitSize = 1,
            bitOffset = 13,
            mode = 'RW',
            name = 'USB_BOTH_BURST_IDLE')

        addVar(
            offset = 0x0119,
            bitSize = 1,
            bitOffset = 12,
            mode = 'RW',
            name = 'TXREFCLKDIV2_SEL')

        addVar(
            offset = 0x0119,
            bitSize = 6,
            bitOffset = 6,
            mode = 'RW',
            name = 'TX_DEEMPH2')

        addVar(
            offset = 0x0119,
            bitSize = 6,
            bitOffset = 0,
            mode = 'RW',
            name = 'TX_DEEMPH3')

        addVar(
            offset = 0x011A,
            bitSize = 1,
            bitOffset = 6,
            mode = 'RW',
            name = 'RXREFCLKDIV2_SEL')

        addVar(
            offset = 0x011A,
            bitSize = 1,
            bitOffset = 5,
            mode = 'RW',
            name = 'A_RXTERMINATION')

        addVar(
            offset = 0x011A,
            bitSize = 4,
            bitOffset = 1,
            mode = 'RW',
            name = 'USB_LFPS_TPERIOD')

        addVar(
            offset = 0x011A,
            bitSize = 1,
            bitOffset = 0,
            mode = 'RW',
            name = 'USB_LFPS_TPERIOD_ACCURATE')

        addVar(
            offset = 0x011B,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXCDR_CFG2_GEN4')

        addVar(
            offset = 0x011C,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXCDR_CFG3_GEN4')

        addVar(
            offset = 0x011D,
            bitSize = 7,
            bitOffset = 8,
            mode = 'RW',
            name = 'USB_BURSTMIN_U3WAKE')

        addVar(
            offset = 0x011D,
            bitSize = 7,
            bitOffset = 0,
            mode = 'RW',
            name = 'USB_BURSTMAX_U3WAKE')

        addVar(
            offset = 0x011E,
            bitSize = 10,
            bitOffset = 0,
            mode = 'RW',
            name = 'USB_IDLEMIN_POLLING')

        addVar(
            offset = 0x011F,
            bitSize = 10,
            bitOffset = 0,
            mode = 'RW',
            name = 'USB_IDLEMAX_POLLING')

        addVar(
            offset = 0x0120,
            bitSize = 9,
            bitOffset = 0,
            mode = 'RW',
            name = 'USB_LFPSPOLLING_BURST')

        addVar(
            offset = 0x0121,
            bitSize = 9,
            bitOffset = 0,
            mode = 'RW',
            name = 'USB_LFPSPING_BURST')

        addVar(
            offset = 0x0122,
            bitSize = 9,
            bitOffset = 0,
            mode = 'RW',
            name = 'USB_LFPSU1EXIT_BURST')

        addVar(
            offset = 0x0123,
            bitSize = 9,
            bitOffset = 0,
            mode = 'RW',
            name = 'USB_LFPSU2LPEXIT_BURST_MS')

        addVar(
            offset = 0x0124,
            bitSize = 9,
            bitOffset = 0,
            mode = 'RW',
            name = 'USB_LFPSU3WAKE_BURST_MS')

        addVar(
            offset = 0x0125,
            bitSize = 9,
            bitOffset = 0,
            mode = 'RW',
            name = 'USB_LFPSPOLLING_IDLE_MS')

        addVar(
            offset = 0x0126,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_HA_CFG1')

        addVar(
            offset = 0x0127,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXDFE_HB_CFG0')

        addVar(
            offset = 0x0135,
            bitSize = 6,
            bitOffset = 10,
            mode = 'RW',
            name = 'RXCDR_CFG3_GEN2')

        addVar(
            offset = 0x0135,
            bitSize = 10,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXCDR_CFG2_GEN2')

        addVar(
            offset = 0x0250,
            bitSize = 7,
            bitOffset = 0,
            mode = 'RO',
            name = 'COMMA_ALIGN_LATENCY')

        addVar(
            offset = 0x0251,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RO',
            name = 'es_error_count')

        addVar(
            offset = 0x0252,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RO',
            name = 'es_sample_count')

        addVar(
            offset = 0x0253,
            bitSize = 4,
            bitOffset = 0,
            mode = 'RO',
            name = 'es_control_status')

        addVar(
            offset = 0x0254,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RO',
            name = 'es_rdata_byte4')

        addVar(
            offset = 0x0255,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RO',
            name = 'es_rdata_byte3')

        addVar(
            offset = 0x0256,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RO',
            name = 'es_rdata_byte2')


        addVar(
            offset = 0x0257,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RO',
            name = 'es_rdata_byte1')

        addVar(
            offset = 0x0258,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RO',
            name = 'es_rdata_byte0')

        addVar(
            offset = 0x0259,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RO',
            name = 'es_sdata_byte4')

        addVar(
            offset = 0x025A,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RO',
            name = 'es_sdata_byte3')

        addVar(
            offset = 0x025B,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RO',
            name = 'es_sdata_byte2')

        addVar(
            offset = 0x025C,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RO',
            name = 'es_sdata_byte1')

        addVar(
            offset = 0x025D,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RO',
            name = 'es_sdata_byte0')

        self.add(pr.RemoteVariable(
            offset = [0x025E << 2, 0x025f << 2],
            bitSize = [16, 16],
            bitOffset = [0, 0],
            mode = 'RO',
            name = 'RX_PRBS_ERR_CNT'))


        addVar(
            offset = 0x0263,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RO',
            name = 'TXGBOX_FIFO_LATENCY')

        addVar(
            offset = 0x0269,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RO',
            name = 'RXGBOX_FIFO_LATENCY')

        addVar(
            offset = 0x0283,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RO',
            name = 'es_sdata_byte5')

        addVar(
            offset = 0x0284,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RO',
            name = 'es_sdata_byte6')

        addVar(
            offset = 0x0285,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RO',
            name = 'es_sdata_byte7')

        addVar(
            offset = 0x0286,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RO',
            name = 'es_sdata_byte8')

        addVar(
            offset = 0x0287,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RO',
            name = 'es_sdata_byte9')

        addVar(
            offset = 0x0288,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RO',
            name = 'es_rdata_byte5')

        addVar(
            offset = 0x0289,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RO',
            name = 'es_rdata_byte6')

        addVar(
            offset = 0x028A,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RO',
            name = 'es_rdata_byte7')

        addVar(
            offset = 0x028B,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RO',
            name = 'es_rdata_byte8')

        addVar(
            offset = 0x028C,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RO',
            name = 'es_rdata_byte9')
