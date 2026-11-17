#-----------------------------------------------------------------------------
# Description:
# PyRogue Gthe4Common
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

class Gthe4Common(pr.Device):
    """GTHE4_COMMON DRP register map (UG576 Table C-1)."""

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        ##############################
        # Variables
        ##############################

        def addVar(description='GTHE4 common attribute register', **kwargs):
            kwargs['offset'] = kwargs['offset'] << 2
            self.add(pr.RemoteVariable(description=description, **kwargs))

        addVar(
            offset = 0x0008,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL0_CFG0',
            description = 'QPLL0 configuration register 0')

        addVar(
            offset = 0x0009,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'COMMON_CFG0',
            description = 'Common block configuration register 0')

        addVar(
            offset = 0x000D,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'PPF0_CFG',
            description = 'QPLL0 post-PLL filter configuration')

        addVar(
            offset = 0x000E,
            bitSize = 1,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL0CLKOUT_RATE',
            description = 'QPLL0 clock output rate selection (HALF or FULL)',
            enum = {
                0 : 'HALF',
                1 : 'FULL'})

        addVar(
            offset = 0x0010,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL0_CFG1',
            description = 'QPLL0 configuration register 1')

        addVar(
            offset = 0x0011,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL0_CFG2',
            description = 'QPLL0 configuration register 2')

        addVar(
            offset = 0x0012,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL0_LOCK_CFG',
            description = 'QPLL0 lock detector configuration')

        addVar(
            offset = 0x0013,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL0_INIT_CFG0',
            description = 'QPLL0 initialization configuration register 0')

        addVar(
            offset = 0x0014,
            bitSize = 8,
            bitOffset = 8,
            mode = 'RW',
            name = 'QPLL0_INIT_CFG1',
            description = 'QPLL0 initialization configuration register 1')

        addVar(
            offset = 0x0014,
            bitSize = 8,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL0_FBDIV',
            description = 'QPLL0 feedback divider value')

        addVar(
            offset = 0x0015,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL0_CFG3',
            description = 'QPLL0 configuration register 3')

        addVar(
            offset = 0x0016,
            bitSize = 10,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL0_CP',
            description = 'QPLL0 charge pump current control')

        addVar(
            offset = 0x0018,
            bitSize = 5,
            bitOffset = 7,
            mode = 'RW',
            name = 'QPLL0_REFCLK_DIV',
            description = 'QPLL0 reference clock input divider')

        addVar(
            offset = 0x0019,
            bitSize = 10,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL0_LPF',
            description = 'QPLL0 loop filter configuration')

        addVar(
            offset = 0x001A,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL0_CFG1_G3',
            description = 'QPLL0 configuration register 1 for Gen3 rate')

        addVar(
            offset = 0x001B,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL0_CFG2_G3',
            description = 'QPLL0 configuration register 2 for Gen3 rate')

        addVar(
            offset = 0x001C,
            bitSize = 10,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL0_LPF_G3',
            description = 'QPLL0 loop filter configuration for Gen3 rate')

        addVar(
            offset = 0x001D,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL0_LOCK_CFG_G3',
            description = 'QPLL0 lock detector configuration for Gen3 rate')

        addVar(
            offset = 0x001E,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RSVD_ATTR0',
            description = 'Reserved. Use the recommended value from the Wizard')

        addVar(
            offset = 0x001F,
            bitSize = 8,
            bitOffset = 8,
            mode = 'RW',
            name = 'QPLL0_FBDIV_G3',
            description = 'QPLL0 feedback divider value for Gen3 rate')

        addVar(
            offset = 0x001F,
            bitSize = 1,
            bitOffset = 3,
            mode = 'RW',
            name = 'QPLL0_RATE_SW_USE_DRP',
            description = 'QPLL0 rate switching via DRP enable')

        addVar(
            offset = 0x001F,
            bitSize = 1,
            bitOffset = 2,
            mode = 'RW',
            name = 'QPLL0_PCI_EN',
            description = 'QPLL0 PCIe mode enable')

        addVar(
            offset = 0x001F,
            bitSize = 2,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXRECCLKOUT0_SEL',
            description = 'QPLL0 recovered clock output selection')

        addVar(
            offset = 0x0020,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL0_SDM_CFG0',
            description = 'QPLL0 sigma-delta modulator configuration register 0')

        addVar(
            offset = 0x0021,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL0_SDM_CFG1',
            description = 'QPLL0 sigma-delta modulator configuration register 1')

        addVar(
            offset = 0x0022,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'SDM0INITSEED0_0',
            description = 'SDM0 initial seed value bits [15:0]')

        addVar(
            offset = 0x0023,
            bitSize = 9,
            bitOffset = 0,
            mode = 'RW',
            name = 'SDM0INITSEED0_1',
            description = 'SDM0 initial seed value bits [23:16]')

        addVar(
            offset = 0x0024,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL0_SDM_CFG2',
            description = 'QPLL0 sigma-delta modulator configuration register 2')

        addVar(
            offset = 0x0025,
            bitSize = 10,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL0_CP_G3',
            description = 'QPLL0 charge pump current control for Gen3 rate')

        addVar(
            offset = 0x0029,
            bitSize = 1,
            bitOffset = 15,
            mode = 'RW',
            name = 'AEN_QPLL0_FBDIV',
            description = 'QPLL0 feedback divider attribute enable (1 selects the A_ override)')

        addVar(
            offset = 0x0029,
            bitSize = 1,
            bitOffset = 14,
            mode = 'RW',
            name = 'AEN_SDM0TOGGLE',
            description = 'SDM0 toggle attribute enable (1 selects A_SDM0TOGGLE over the port)')

        addVar(
            offset = 0x0029,
            bitSize = 1,
            bitOffset = 13,
            mode = 'RW',
            name = 'A_SDM0TOGGLE',
            description = 'SDM0 toggle attribute override')

        addVar(
            offset = 0x002D,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RSVD_ATTR1',
            description = 'Reserved. Use the recommended value from the Wizard')

        addVar(
            offset = 0x0030,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL0_CFG4',
            description = 'QPLL0 configuration register 4')

        addVar(
            offset = 0x0081,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'BIAS_CFG0',
            description = 'Common block bias configuration register 0')

        addVar(
            offset = 0x0082,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'BIAS_CFG1',
            description = 'Common block bias configuration register 1')

        addVar(
            offset = 0x0083,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'BIAS_CFG2',
            description = 'Common block bias configuration register 2')

        addVar(
            offset = 0x0084,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'BIAS_CFG3',
            description = 'Common block bias configuration register 3')

        addVar(
            offset = 0x0086,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'BIAS_CFG4',
            description = 'Common block bias configuration register 4')

        addVar(
            offset = 0x0088,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL1_CFG0',
            description = 'QPLL1 configuration register 0')

        addVar(
            offset = 0x0089,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'COMMON_CFG1',
            description = 'Common block configuration register 1')

        addVar(
            offset = 0x008B,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'POR_CFG',
            description = 'Power-on reset configuration')

        addVar(
            offset = 0x008D,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'PPF1_CFG',
            description = 'QPLL1 post-PLL filter configuration')

        addVar(
            offset = 0x008E,
            bitSize = 1,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL1CLKOUT_RATE',
            description = 'QPLL1 clock output rate selection (HALF or FULL)',
            enum = {
                0 : 'HALF',
                1 : 'FULL'})

        addVar(
            offset = 0x008F,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'BIAS_CFG_RSVD',
            description = 'Common block bias reserved configuration')

        addVar(
            offset = 0x0090,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL1_CFG1',
            description = 'QPLL1 configuration register 1')

        addVar(
            offset = 0x0091,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL1_CFG2',
            description = 'QPLL1 configuration register 2')

        addVar(
            offset = 0x0092,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL1_LOCK_CFG',
            description = 'QPLL1 lock detector configuration')

        addVar(
            offset = 0x0093,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL1_INIT_CFG0',
            description = 'QPLL1 initialization configuration register 0')

        addVar(
            offset = 0x0094,
            bitSize = 8,
            bitOffset = 8,
            mode = 'RW',
            name = 'QPLL1_INIT_CFG1',
            description = 'QPLL1 initialization configuration register 1')

        addVar(
            offset = 0x0094,
            bitSize = 8,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL1_FBDIV',
            description = 'QPLL1 feedback divider value')

        addVar(
            offset = 0x0095,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL1_CFG3',
            description = 'QPLL1 configuration register 3')

        addVar(
            offset = 0x0096,
            bitSize = 10,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL1_CP',
            description = 'QPLL1 charge pump current control')

        addVar(
            offset = 0x0098,
            bitSize = 1,
            bitOffset = 13,
            mode = 'RW',
            name = 'SARC_SEL',
            description = 'Spread-spectrum aware reference clock selection')

        addVar(
            offset = 0x0098,
            bitSize = 1,
            bitOffset = 12,
            mode = 'RW',
            name = 'SARC_ENB',
            description = 'Common block SAR calibration disable')

        addVar(
            offset = 0x0098,
            bitSize = 5,
            bitOffset = 7,
            mode = 'RW',
            name = 'QPLL1_REFCLK_DIV',
            description = 'QPLL1 reference clock input divider')

        addVar(
            offset = 0x0099,
            bitSize = 10,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL1_LPF',
            description = 'QPLL1 loop filter configuration')

        addVar(
            offset = 0x009A,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL1_CFG1_G3',
            description = 'QPLL1 configuration register 1 for Gen3 rate')

        addVar(
            offset = 0x009B,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL1_CFG2_G3',
            description = 'QPLL1 configuration register 2 for Gen3 rate')

        addVar(
            offset = 0x009C,
            bitSize = 10,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL1_LPF_G3',
            description = 'QPLL1 loop filter configuration for Gen3 rate')

        addVar(
            offset = 0x009D,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL1_LOCK_CFG_G3',
            description = 'QPLL1 lock detector configuration for Gen3 rate')

        addVar(
            offset = 0x009E,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RSVD_ATTR2',
            description = 'Reserved. Use the recommended value from the Wizard')

        addVar(
            offset = 0x009F,
            bitSize = 8,
            bitOffset = 8,
            mode = 'RW',
            name = 'QPLL1_FBDIV_G3',
            description = 'QPLL1 feedback divider value for Gen3 rate')

        addVar(
            offset = 0x009F,
            bitSize = 1,
            bitOffset = 3,
            mode = 'RW',
            name = 'QPLL1_RATE_SW_USE_DRP',
            description = 'QPLL1 rate switching via DRP enable')

        addVar(
            offset = 0x009F,
            bitSize = 1,
            bitOffset = 2,
            mode = 'RW',
            name = 'QPLL1_PCI_EN',
            description = 'QPLL1 PCIe mode enable')

        addVar(
            offset = 0x009F,
            bitSize = 2,
            bitOffset = 0,
            mode = 'RW',
            name = 'RXRECCLKOUT1_SEL',
            description = 'QPLL1 recovered clock output selection')

        addVar(
            offset = 0x00A0,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL1_SDM_CFG0',
            description = 'QPLL1 sigma-delta modulator configuration register 0')

        addVar(
            offset = 0x00A1,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL1_SDM_CFG1',
            description = 'QPLL1 sigma-delta modulator configuration register 1')

        addVar(
            offset = 0x00A2,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'SDM1INITSEED0_0',
            description = 'SDM1 initial seed value bits [15:0]')

        addVar(
            offset = 0x00A3,
            bitSize = 9,
            bitOffset = 0,
            mode = 'RW',
            name = 'SDM1INITSEED0_1',
            description = 'SDM1 initial seed value bits [23:16]')

        addVar(
            offset = 0x00A4,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL1_SDM_CFG2',
            description = 'QPLL1 sigma-delta modulator configuration register 2')

        addVar(
            offset = 0x00A5,
            bitSize = 10,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL1_CP_G3',
            description = 'QPLL1 charge pump current control for Gen3 rate')

        addVar(
            offset = 0x00A8,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'A_SDM1DATA_LOW',
            description = 'SDM1 data attribute override bits [15:0]')

        addVar(
            offset = 0x00A9,
            bitSize = 1,
            bitOffset = 15,
            mode = 'RW',
            name = 'AEN_QPLL1_FBDIV',
            description = 'QPLL1 feedback divider attribute enable (1 selects the A_ override)')

        addVar(
            offset = 0x00A9,
            bitSize = 1,
            bitOffset = 14,
            mode = 'RW',
            name = 'AEN_SDM1TOGGLE',
            description = 'SDM1 toggle attribute enable (1 selects A_SDM1TOGGLE over the port)')

        addVar(
            offset = 0x00A9,
            bitSize = 1,
            bitOffset = 13,
            mode = 'RW',
            name = 'A_SDM1TOGGLE',
            description = 'SDM1 toggle attribute override')

        addVar(
            offset = 0x00A9,
            bitSize = 9,
            bitOffset = 0,
            mode = 'RW',
            name = 'A_SDM1DATA_HIGH',
            description = 'SDM1 data attribute override bits [24:16]')

        addVar(
            offset = 0x00AD,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'RSVD_ATTR3',
            description = 'Reserved. Use the recommended value from the Wizard')

        addVar(
            offset = 0x00B0,
            bitSize = 16,
            bitOffset = 0,
            mode = 'RW',
            name = 'QPLL1_CFG4',
            description = 'QPLL1 configuration register 4')
