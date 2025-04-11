#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import time

import pyrogue as pr
import rogue

class Ads54J54(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        # Allow array variables to be set from yaml by a dict of index/value pairs add in rogue v6.6.0
        rogue.Version.minVersion('6.6.0')
        self.add(pr.RemoteVariable(
            name        = 'Reg',
            offset      = 0x00,
            mode        = 'RW',
            numValues   = 0x6D,
            valueBits   = 16,
            valueStride = 32,
            verify      = False,
            hidden      = True,
            overlapEn   = True,
        ))

        ######################################################
        # Figure 72. Register Address 0, Reset 0x0000, Hex = 0
        ######################################################

        self.add(pr.RemoteVariable(
            name         = "WIRE_MODE",
            description  = "Enables 4-bit serial interface when set",
            offset       = (4*0x00),
            bitSize      = 1,
            bitOffset    = 15,
            mode         = "WO",
            overlapEn    = True,
            enum         = {
                0x0 : "3-wire",
                0x1 : "4-wire",
            },
        ))

        self.add(pr.RemoteVariable(
            name         = "FORMAT",
            description  = "Selects digital output format",
            offset       = (4*0x00),
            bitSize      = 1,
            bitOffset    = 14,
            mode         = "RW",
            overlapEn    = True,
            enum         = {
                0x0 : "twos_complement",
                0x1 : "offset_binary",
            },
        ))

        self.add(pr.RemoteVariable(
            name         = "DEC_EN_AB",
            description  = "Enables decimation filter for channel AB",
            offset       = (4*0x00),
            bitSize      = 1,
            bitOffset    = 13,
            mode         = "RW",
            overlapEn    = True,
            enum         = {
                0x0 : "Normal_operation",
                0x1 : "Decimation_filter_enabled",
            },
        ))

        self.add(pr.RemoteVariable(
            name         = "HP_LP_AB",
            description  = "Determines high-pass or low-pass configuration of decimation filter for channel AB",
            offset       = (4*0x00),
            bitSize      = 1,
            bitOffset    = 12,
            mode         = "RW",
            overlapEn    = True,
            enum         = {
                0x0 : "Low_pass",
                0x1 : "High_pass",
            },
        ))

        self.add(pr.RemoteVariable(
            name         = "DEC_EN_CD",
            description  = "Enables dcimation filter for channel CD",
            offset       = (4*0x00),
            bitSize      = 1,
            bitOffset    = 10,
            mode         = "RW",
            overlapEn    = True,
            enum         = {
                0x0 : "Normal_operation",
                0x1 : "Decimation_filter_enabled",
            },
        ))

        self.add(pr.RemoteVariable(
            name         = "HP_LP_CD",
            description  = "Determines high-pass or low-pass configuration of decimation filter for channel CD",
            offset       = (4*0x00),
            bitSize      = 1,
            bitOffset    = 9,
            mode         = "RW",
            overlapEn    = True,
            enum         = {
                0x0 : "Low_pass",
                0x1 : "High_pass",
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'RESET',
            description  = 'Software reset, self clears to 0',
            offset       = (4*0x00),
            bitSize      = 1,
            bitOffset    = 0,
            mode         = 'WO',
            overlapEn    = True,
        ))

        ######################################################
        # Figure 73. Register Address 1, Reset 0xAF7A, Hex = 1
        ######################################################

        self.add(pr.RemoteVariable(
            name         = 'MODE_1',
            description  = 'Set bit D15 to 0 for optimum performance',
            offset       = (4*0x01),
            bitSize      = 1,
            bitOffset    = 15,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'FOVR_THRESH_AB',
            description  = 'Sets fast OVR thresholds for channel A and B',
            offset       = (4*0x01),
            bitSize      = 3,
            bitOffset    = 9,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'FOVR_LENGTH_AB',
            description  = 'Determines minimum pulse length for FOVR output',
            offset       = (4*0x01),
            bitSize      = 2,
            bitOffset    = 7,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'FOVR_THRESH_CD',
            description  = 'Sets fast OVR thresholds for channel C and D',
            offset       = (4*0x01),
            bitSize      = 3,
            bitOffset    = 4,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'FOVR_LENGTH_CD',
            description  = 'Determines minimum pulse length for FOVR output',
            offset       = (4*0x01),
            bitSize      = 2,
            bitOffset    = 2,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################################################
        # Figure 75. Register Address 3, Reset: 0x4040, Hex = 3
        #######################################################

        self.add(pr.RemoteVariable(
            name         = 'CLK_SEL_CD',
            description  = 'Clock source selection for channel C and D',
            offset       = (4*0x03),
            bitSize      = 1,
            bitOffset    = 14,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'CLK_DIV_CD',
            description  = 'Channel CD clock divider setting',
            offset       = (4*0x03),
            bitSize      = 2,
            bitOffset    = 12,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'CLK_PHASE_SELECT_CD',
            description  = 'Selects phase of channel divided clock',
            offset       = (4*0x03),
            bitSize      = 3,
            bitOffset    = 8,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'SYSREF_SEL_CD',
            description  = 'Selects phase of channel divided clock',
            offset       = (4*0x03),
            bitSize      = 1,
            bitOffset    = 7,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'CLK_SEL_AB',
            description  = 'Clock source selection for channel A and B',
            offset       = (4*0x03),
            bitSize      = 1,
            bitOffset    = 6,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'CLK_DIV_AB',
            description  = 'Channel AB clock divider setting',
            offset       = (4*0x03),
            bitSize      = 2,
            bitOffset    = 4,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'CLK_PHASE_SELECT_AB',
            description  = 'Selects phase of channel divided clock',
            offset       = (4*0x03),
            bitSize      = 3,
            bitOffset    = 0,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################################################
        # Figure 76. Register Address 4, Reset: 0x000F, Hex = 4
        #######################################################

        self.add(pr.RemoteVariable(
            name         = 'OVRA_OUT_EN',
            description  = 'OVRA pin output enable',
            offset       = (4*0x04),
            bitSize      = 1,
            bitOffset    = 15,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'OVRB_OUT_EN',
            description  = 'OVRB pin output enable',
            offset       = (4*0x04),
            bitSize      = 1,
            bitOffset    = 14,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'OVRC_OUT_EN',
            description  = 'OVRC pin output enable',
            offset       = (4*0x04),
            bitSize      = 1,
            bitOffset    = 13,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'OVRD_OUT_EN',
            description  = 'OVRD pin output enable',
            offset       = (4*0x04),
            bitSize      = 1,
            bitOffset    = 12,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'SYSREF_AB_DELAY',
            description  = 'Programmable input delay on SYSREFAB input',
            offset       = (4*0x04),
            bitSize      = 2,
            bitOffset    = 10,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'SYSREF_CD_DELAY',
            description  = 'Programmable input delay on SYSREFCD input',
            offset       = (4*0x04),
            bitSize      = 2,
            bitOffset    = 8,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'SYNCb_AB_EN',
            description  = 'SYNCbAB input buffer enable',
            offset       = (4*0x04),
            bitSize      = 1,
            bitOffset    = 3,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'SYNCb_CD_EN',
            description  = 'SYNCbCD input buffer enable',
            offset       = (4*0x04),
            bitSize      = 1,
            bitOffset    = 2,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################################################
        # Figure 77. Register Address 5, Reset: 0x0000, Hex = 5
        #######################################################

        self.add(pr.RemoteVariable(
            name         = 'ANALOG_SLEEP_MODES_ENABLE',
            description  = 'Power-down function assigned to ENABLE pin',
            offset       = (4*0x05),
            bitSize      = 16,
            bitOffset    = 0,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################################################
        # Figure 78. Register Address 6, Reset: 0xFFFF, Hex = 6
        #######################################################

        self.add(pr.RemoteVariable(
            name         = 'ANALOG_SLEEP_MODES',
            description  = 'Power-down function controlled via SPI',
            offset       = (4*0x06),
            bitSize      = 16,
            bitOffset    = 0,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################################################
        # Figure 79. Register Address 7, Reset: 0x0144, Hex = 7
        #######################################################

        self.add(pr.RemoteVariable(
            name         = 'CLK_SW_AB',
            description  = 'User should set this bit to 1 when changing the clock phase of the clock divider AB. After the change is complete user needs to write this bit back to 0.',
            offset       = (4*0x07),
            bitSize      = 1,
            bitOffset    = 9,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################################################
        # Figure 80. Register Address 8, Reset: 0x0144, Hex = 8
        #######################################################

        self.add(pr.RemoteVariable(
            name         = 'CLK_SW_CD',
            description  = 'User should set this bit to 1 when changing the clock phase of the clock divider CD. After the change is complete user needs to write this bit back to 0.',
            offset       = (4*0x08),
            bitSize      = 1,
            bitOffset    = 9,
            mode         = 'RW',
            overlapEn    = True,
        ))

        ########################################################
        # Figure 81. Register Address 12, Reset: 0x31E4, Hex = C
        ########################################################

        self.add(pr.RemoteVariable(
            name         = 'SYSREF_JESD_MODE_CD',
            description  = 'Determines how SYSREF is used in the JESD block for channel CD',
            offset       = (4*0x0C),
            bitSize      = 3,
            bitOffset    = 3,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'SYSREF_JESD_MODE_AB',
            description  = 'Determines how SYSREF is used in the JESD block for channel AB',
            offset       = (4*0x0C),
            bitSize      = 3,
            bitOffset    = 0,
            mode         = 'RW',
            overlapEn    = True,
        ))

        ########################################################
        # Figure 82. Register Address 13, Reset: 0x0202, Hex = D
        ########################################################

        self.add(pr.RemoteVariable(
            name         = 'JESD_INIT_CD',
            description  = 'Puts the JESD block in INITIALIZATION state when set high',
            offset       = (4*0x0D),
            bitSize      = 1,
            bitOffset    = 9,
            mode         = 'RW',
            overlapEn    = True,
        ))


        self.add(pr.RemoteVariable(
            name         = 'JESD_RESET_CD',
            description  = 'Resets the JESD block when low',
            offset       = (4*0x0D),
            bitSize      = 1,
            bitOffset    = 8,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'JESD_INIT_AB',
            description  = 'Puts the JESD block in INITIALIZATION state when set high',
            offset       = (4*0x0D),
            bitSize      = 1,
            bitOffset    = 1,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'JESD_RESET_AB',
            description  = 'Resets the JESD block when low',
            offset       = (4*0x0D),
            bitSize      = 1,
            bitOffset    = 0,
            mode         = 'RW',
            overlapEn    = True,
        ))

        ########################################################
        # Figure 83. Register Address 14, Reset: 0x00FF, Hex = E
        ########################################################

        self.add(pr.RemoteVariable(
            name         = 'TX_LANE_EN_CD',
            description  = 'Enables JESD204B transmitter for channel C and D',
            offset       = (4*0x0E),
            bitSize      = 4,
            bitOffset    = 4,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TX_LANE_EN_AB',
            description  = 'Enables JESD204B transmitter for channel A and B',
            offset       = (4*0x0E),
            bitSize      = 4,
            bitOffset    = 0,
            mode         = 'RW',
            overlapEn    = True,
        ))

        ########################################################
        # Figure 84. Register Address 15, Reset: 0x0001, Hex = F
        ########################################################

        self.add(pr.RemoteVariable(
            name         = 'CTRL_F_AB',
            description  = 'Controls number of octets per frame for channel AB',
            offset       = (4*0x0F),
            bitSize      = 2,
            bitOffset    = 8,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'CTRL_M_AB',
            description  = 'Controls number of converters per link for channel AB',
            offset       = (4*0x0F),
            bitSize      = 2,
            bitOffset    = 0,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #########################################################
        # Figure 85. Register Address 16, Reset: 0x03E3, Hex = 10
        #########################################################

        self.add(pr.RemoteVariable(
            name         = 'CTRL_K_AB',
            description  = 'Controls number of frames per multi-frame for channel AB',
            offset       = (4*0x10),
            bitSize      = 5,
            bitOffset    = 5,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'CTRL_L_AB',
            description  = 'Controls number of lanes for channel AB.',
            offset       = (4*0x10),
            bitSize      = 2,
            bitOffset    = 0,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #########################################################
        # Figure 86. Register Address 19, Reset: 0x0020, Hex = 13
        #########################################################

        self.add(pr.RemoteVariable(
            name         = 'INV_SYNCb_AB',
            description  = 'Inverts polarity of SYNCbAB input',
            offset       = (4*0x13),
            bitSize      = 1,
            bitOffset    = 6,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'HD_AB',
            description  = 'Enables high density mode for channel AB',
            offset       = (4*0x13),
            bitSize      = 1,
            bitOffset    = 5,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'SCR_EN_AB',
            description  = 'Enables scramble mode for channel AB',
            offset       = (4*0x13),
            bitSize      = 1,
            bitOffset    = 4,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #########################################################
        # Figure 87. Register Address 22, Reset: 0x0001, Hex = 16
        #########################################################

        self.add(pr.RemoteVariable(
            name         = 'CTRL_F_CD',
            description  = 'Controls number of octets per frame for channel CD',
            offset       = (4*0x16),
            bitSize      = 2,
            bitOffset    = 8,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'CTRL_M_CD',
            description  = 'Controls number of converters per link for channel CD',
            offset       = (4*0x16),
            bitSize      = 2,
            bitOffset    = 0,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #########################################################
        # Figure 88. Register Address 23, Reset: 0x03E3, Hex = 17
        #########################################################

        self.add(pr.RemoteVariable(
            name         = 'CTRL_K_CD',
            description  = 'Controls number of frames per multi-frame for channel CD',
            offset       = (4*0x17),
            bitSize      = 5,
            bitOffset    = 5,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'CTRL_L_CD',
            description  = 'Controls number of lanes for channel CD',
            offset       = (4*0x17),
            bitSize      = 2,
            bitOffset    = 0,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #########################################################
        # Figure 89. Register Address 26, Reset: 0x0020, Hex = 1A
        #########################################################

        self.add(pr.RemoteVariable(
            name         = 'INV_SYNCb_CD',
            description  = 'Inverts polarity of SYNCbCD input',
            offset       = (4*0x1A),
            bitSize      = 1,
            bitOffset    = 6,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'HD_CD',
            description  = 'Enables high density mode for channel CD',
            offset       = (4*0x1A),
            bitSize      = 1,
            bitOffset    = 5,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'SCR_EN_CD',
            description  = 'Enables scramble mode for channel CD',
            offset       = (4*0x1A),
            bitSize      = 1,
            bitOffset    = 4,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #########################################################
        # Figure 90. Register Address 29, Reset: 0x0000, Hex = 1D
        #########################################################

        self.add(pr.RemoteVariable(
            name         = 'TEST_PATTERN_EN_CD',
            description  = 'Enables test pattern output for channel C and D',
            offset       = (4*0x1D),
            bitSize      = 1,
            bitOffset    = 6,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TEST_PATTERN_EN_AB',
            description  = 'Enables test pattern output for channel A and B',
            offset       = (4*0x1D),
            bitSize      = 1,
            bitOffset    = 5,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'TEST_PATTERN',
            description  = 'Selects test pattern',
            offset       = (4*0x1D),
            bitSize      = 1,
            bitOffset    = 4,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #########################################################
        # Figure 91. Register Address 30, Reset: 0x0000, Hex = 1E
        #########################################################

        self.add(pr.RemoteVariable(
            name         = 'JESD_SLEEP_MODES_ENABLE',
            description  = 'Power-down function assigned to ENABLE pin',
            offset       = (4*0x1E),
            bitSize      = 10,
            bitOffset    = 0,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #########################################################
        # Figure 92. Register Address 31, Reset: 0xFFFF, Hex = 1F
        #########################################################

        self.add(pr.RemoteVariable(
            name         = 'JESD_SLEEP_MODES',
            description  = 'Power-down function controlled via SPI',
            offset       = (4*0x1F),
            bitSize      = 10,
            bitOffset    = 0,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #########################################################
        # Figure 93. Register Address 32, Reset: 0x0000, Hex = 20
        #########################################################

        self.add(pr.RemoteVariable(
            name         = 'JESD_LANE_POLARITY_INVERT',
            description  = 'Set to 1 for polarity inversion',
            offset       = (4*0x20),
            bitSize      = 8,
            bitOffset    = 8,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'PRBS_EN',
            description  = 'Outputs PRBS pattern selected in address 0x21 on the selected serial output lanes',
            offset       = (4*0x20),
            bitSize      = 8,
            bitOffset    = 0,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #########################################################
        # Figure 94. Register Address 33, Reset: 0x0000, Hex = 21
        #########################################################

        self.add(pr.RemoteVariable(
            name         = 'PRBS_SEL',
            description  = 'Selects different PRBS output pattern (these are not 8b/10b encoded)',
            offset       = (4*0x21),
            bitSize      = 2,
            bitOffset    = 13,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'VREF_SEL',
            description  = 'Selects different input full-scale amplitude by adjusting voltage reference setting',
            offset       = (4*0x21),
            bitSize      = 3,
            bitOffset    = 0,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #########################################################
        # Figure 95. Register Address 99,Reset: 0x0000, Hex = 63
        #########################################################

        self.add(pr.RemoteVariable(
            name         = 'TEMP_SENSOR',
            description  = 'Value of on chip temperature sensor (read only)',
            offset       = (4*0x63),
            bitSize      = 8,
            bitOffset    = 0,
            mode         = 'RO',
            units        = 'degC',
            base         = pr.Int,
            disp         = '{:d}',
            overlapEn    = True,
        ))

        ##########################################################
        # Figure 96. Register Address 100, Reset: 0x0000, Hex = 64
        ##########################################################

        self.add(pr.RemoteVariable(
            name         = 'PRE_EMP_SEL_AB',
            description  = 'Selects pre-emphasis of serializers for channel A and B',
            offset       = (4*0x64),
            bitSize      = 4,
            bitOffset    = 12,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'PRE_EMP_EN_AB',
            description  = 'Selects pre-emphasis of serializers for channel C and D',
            offset       = (4*0x64),
            bitSize      = 4,
            bitOffset    = 8,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'DCC_EN_AB',
            description  = 'Enables the duty cycle correction circuit for each of the serializers',
            offset       = (4*0x64),
            bitSize      = 4,
            bitOffset    = 4,
            mode         = 'RW',
            overlapEn    = True,
        ))

        ##########################################################
        # Figure 97. Register Address 103, Reset: 0x0000, Hex = 67
        ##########################################################

        self.add(pr.RemoteVariable(
            name         = 'OUTPUT_CURRENT_CONTROL_AB',
            description  = 'Selects pre-emphasis current for the serializers',
            offset       = (4*0x67),
            bitSize      = 16,
            bitOffset    = 0,
            mode         = 'RW',
            overlapEn    = True,
        ))

        ##########################################################
        # Figure 98. Register Address 104, Reset: 0x0000, Hex = 68
        ##########################################################

        self.add(pr.RemoteVariable(
            name         = 'PRE_EMP_SEL_CD',
            description  = 'Selects pre-emphasis of serializers for channel C and D',
            offset       = (4*0x68),
            bitSize      = 4,
            bitOffset    = 12,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'PRE_EMP_EN_CD',
            description  = 'Selects pre-emphasis of serializers for channel C and D',
            offset       = (4*0x68),
            bitSize      = 4,
            bitOffset    = 8,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'DCC_EN_CD',
            description  = 'Enables the duty cycle correction circuit for each of the serializers',
            offset       = (4*0x68),
            bitSize      = 4,
            bitOffset    = 4,
            mode         = 'RW',
            overlapEn    = True,
        ))

        ##########################################################
        # Figure 99. Register Address 107, Reset: 0x0000, Hex = 6B
        ##########################################################

        self.add(pr.RemoteVariable(
            name         = 'OUTPUT_CURRENT_CONTROL_CD',
            description  = 'Selects pre-emphasis current for the serializers',
            offset       = (4*0x6B),
            bitSize      = 16,
            bitOffset    = 0,
            mode         = 'RW',
            overlapEn    = True,
        ))

        ##########################################################
        # Figure 100. Register Address 108, Hex = 6C
        ##########################################################

        self.add(pr.RemoteVariable(
            name         = 'JESD_PLL_CD',
            description  = 'JESD PLL for channel CD lost lock when flag is set high',
            offset       = (4*0x6C),
            bitSize      = 1,
            bitOffset    = 1,
            mode         = 'RO',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'JESD_PLL_AB',
            description  = 'JESD PLL for channel AB lost lock when flag is set high',
            offset       = (4*0x6C),
            bitSize      = 1,
            bitOffset    = 0,
            mode         = 'RO',
            overlapEn    = True,
        ))

        @self.command(name= "Init", description  = "Device Initiation after the YAML configuration load")
        def Init():
            self.Reg.set(index=0x44, value=0x0074)
            self.Reg.set(index=0x47, value=0x0074)
            self.Reg.set(index=0x4C, value=0x4000)
            self.Reg.set(index=0x50, value=0x0800)
            self.Reg.set(index=0x51, value=0x0074)
            self.Reg.set(index=0x54, value=0x0074)
            self.Reg.set(index=0x59, value=0x4000)
            self.Reg.set(index=0x5D, value=0x0800)
            self.Reg.set(index=0x0D, value=0x0202)
            self.Reg.set(index=0x0D, value=0x0303)
            time.sleep(0.001)
            self.Reg.set(index=0x0D, value=0x0101)
