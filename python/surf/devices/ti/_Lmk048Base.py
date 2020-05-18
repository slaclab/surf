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
import re
import ast
import time

class Lmk048Base(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.sysrefMode = 2 # 2 pulse sysref mode, 3 continuous sysref mode

        ##############################
        # Variables
        ##############################

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0100',
            description  = 'CLKout0_1_ODL, CLKout0_1_IDL, DCLKout0_DIV',
            offset       = (0x0100 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0101',
            description  = 'DCLKout0_DDLY_CNTH, DCLKout0_DDLY_CNTL',
            offset       = (0x0101 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0103',
            description  = 'DCLKout0_ADLY, DCLKout0_ADLY_MUX, DCLKout_MUX',
            offset       = (0x0103 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0104',
            description  = 'DCLKout0_HS, SDCLKout1_MUX, SDCLKout1_DDLY, SDCLKout1_HS',
            offset       = (0x0104 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0105',
            description  = 'SDCLKout1_ADLY_EN, SDCLKout1_ADLY',
            offset       = (0x0105 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0106',
            description  = 'DCLKout0_DDLY_PD, DCLKout0_HSg_PD, DCLKout_ADLYg_PD, DCLKout_ADLY_PD, DCLKout0_Y_PD, SDCLKout1_DIS_MODE, SDCLKout1_PD',
            offset       = (0x0106 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0107',
            description  = 'SDCLKout1_POL, SDCLKout1_FMT, DCLKout0_POL, DCLKout0_FMT',
            offset       = (0x0107 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0108',
            description  = 'CLKout2_3_ODL, CLKout2_3_IDL, DCLKout2_DIV',
            offset       = (0x0108 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0109',
            description  = 'DCLKout2_DDLY_CNTH, DCLKout2_DDLY_CNTL',
            offset       = (0x0109 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x010B',
            description  = 'DCLKout2_ADLY, DCLKout2_ADLY_MUX, DCLKout_MUX',
            offset       = (0x010B << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x010C',
            description  = 'DCLKout2_HS, SDCLKout3_MUX, SDCLKout3_DDLY, SDCLKout3_HS',
            offset       = (0x010C << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x010D',
            description  = 'SDCLKout3_ADLY_EN, SDCLKout3_ADLY',
            offset       = (0x010D << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x010E',
            description  = 'DCLKout2_DDLY_PD, DCLKout2_HSg_PD, DCLKout_ADLYg_PD, DCLKout_ADLY_PD, DCLKout2_3_PD, SDCLKout3_DIS_MODE, SDCLKout3_PD',
            offset       = (0x010E << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x010F',
            description  = 'SDCLKout3_POL, SDCLKout3_FMT, DCLKout2_POL, DCLKout2_FMT',
            offset       = (0x010F << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0110',
            description  = 'CLKout4_5_ODL, CLKout4_5_IDL, DCLKout4_DIV',
            offset       = (0x0110 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0111',
            description  = 'DCLKout4_DDLY_CNTH, DCLKout4_DDLY_CNTL',
            offset       = (0x0111 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0113',
            description  = 'DCLKout4_ADLY, DCLKout4_ADLY_MUX, DCLKout_MUX',
            offset       = (0x0113 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0114',
            description  = 'DCLKout4_HS, SDCLKout5_MUX, SDCLKout5_DDLY, SDCLKout5_HS',
            offset       = (0x0114 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0115',
            description  = 'SDCLKout5_ADLY_EN, SDCLKout5_ADLY',
            offset       = (0x0115 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0116',
            description  = 'DCLKout4_DDLY_PD, DCLKout4_HSg_PD, DCLKout_ADLYg_PD, DCLKout_ADLY_PD, DCLKout4_5_PD, SDCLKout5_DIS_MODE, SDCLKout5_PD',
            offset       = (0x0116 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0117',
            description  = 'SDCLKout5_POL, SDCLKout5_FMT, DCLKout4_POL, DCLKout4_FMT',
            offset       = (0x0117 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0118',
            description  = 'CLKout6_7_ODL, CLKout6_7_IDL, DCLKout6_DIV',
            offset       = (0x0118 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0119',
            description  = 'DCLKout6_DDLY_CNTH, DCLKout6_DDLY_CNTL',
            offset       = (0x0119 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x011B',
            description  = 'DCLKout6_ADLY, DCLKout6_ADLY_MUX, DCLKout_MUX',
            offset       = (0x011B << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x011C',
            description  = 'DCLKout6_HS, SDCLKout7_MUX, SDCLKout7_DDLY, SDCLKout7_HS',
            offset       = (0x011C << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x011D',
            description  = 'SDCLKout7_ADLY_EN, SDCLKout7_ADLY',
            offset       = (0x011D << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x011E',
            description  = 'DCLKout6_DDLY_PD, DCLKout6_HSg_PD, DCLKout_ADLYg_PD, DCLKout_ADLY_PD, DCLKout6_7_PD, SDCLKout7_DIS_MODE, SDCLKout7_PD',
            offset       = (0x011E << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x011F',
            description  = 'SDCLKout7_POL, SDCLKout7_FMT, DCLKout6_POL, DCLKout6_FMT',
            offset       = (0x011F << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0120',
            description  = 'CLKout8_9_ODL, CLKout8_9_IDL, DCLKout8_DIV',
            offset       = (0x0120 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0121',
            description  = 'DCLKout8_DDLY_CNTH, DCLKout8_DDLY_CNTL',
            offset       = (0x0121 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0123',
            description  = 'DCLKout8_ADLY, DCLKout8_ADLY_MUX, DCLKout_MUX',
            offset       = (0x0123 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0124',
            description  = 'DCLKout8_HS, SDCLKout9_MUX, SDCLKout9_DDLY, SDCLKout9_HS',
            offset       = (0x0124 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0125',
            description  = 'SDCLKout9_ADLY_EN, SDCLKout9_ADLY',
            offset       = (0x0125 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0126',
            description  = 'DCLKout8_DDLY_PD, DCLKout8_HSg_PD, DCLKout_ADLYg_PD, DCLKout_ADLY_PD, DCLKout8_9_PD, SDCLKout9_DIS_MODE, SDCLKout9_PD',
            offset       = (0x0126 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0127',
            description  = 'SDCLKout9_POL, SDCLKout9_FMT, DCLKout8_POL, DCLKout8_FMT',
            offset       = (0x0127 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0128',
            description  = 'CLKout10_11_ODL, CLKout10_11_IDL, DCLKout10_DIV',
            offset       = (0x0128 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0129',
            description  = 'DCLKout10_DDLY_CNTH, DCLKout10_DDLY_CNTL',
            offset       = (0x0129 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x012B',
            description  = 'DCLKout10_ADLY, DCLKout10_ADLY_MUX, DCLKout_MUX',
            offset       = (0x012B << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x012C',
            description  = 'DCLKout10_HS, SDCLKout11_MUX, SDCLKout11_DDLY, SDCLKout11_HS',
            offset       = (0x012C << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x012D',
            description  = 'SDCLKout11_ADLY_EN, SDCLKout11_ADLY',
            offset       = (0x012D << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x012E',
            description  = 'DCLKout10_DDLY_PD, DCLKout10_HSg_PD, DCLKout_ADLYg_PD, DCLKout_ADLY_PD, DCLKout10_11_PD, SDCLKout11_DIS_MODE, SDCLKout11_PD',
            offset       = (0x012E << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x012F',
            description  = 'SDCLKout11_POL, SDCLKout11_FMT, DCLKout10_POL, DCLKout10_FMT',
            offset       = (0x012F << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0130',
            description  = 'CLKout12_13_ODL, CLKout12_13_IDL, DCLKout12_DIV',
            offset       = (0x0130 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0131',
            description  = 'DCLKout12_DDLY_CNTH, DCLKout12_DDLY_CNTL',
            offset       = (0x0131 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0133',
            description  = 'DCLKout12_ADLY, DCLKout12_ADLY_MUX, DCLKout_MUX',
            offset       = (0x0133 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0134',
            description  = 'DCLKout12_HS, SDCLKout13_MUX, SDCLKout13_DDLY, SDCLKout13_HS',
            offset       = (0x0134 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0135',
            description  = 'SDCLKout13_ADLY_EN, SDCLKout13_ADLY',
            offset       = (0x0135 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0136',
            description  = 'DCLKout12_DDLY_PD, DCLKout12_HSg_PD, DCLKout_ADLYg_PD, DCLKout_ADLY_PD, DCLKout12_13_PD, SDCLKout13_DIS_MODE, SDCLKout13_PD',
            offset       = (0x0136 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0137',
            description  = 'SDCLKout13_POL, SDCLKout13_FMT, DCLKout12_POL, DCLKout12_FMT',
            offset       = (0x0137 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0138',
            description  = 'VCO_MUX, OSCout_MUX, OSCout_FMT',
            offset       = (0x0138 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0139',
            description  = 'SYSREF_CLKin0_MUX, SYSREF_MUX',
            offset       = (0x0139 << 2),
            bitSize      = 8,
            mode         = 'RW',
            verify       = False, # Don't verify because changes during JesdReset() JesdInit() commands
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x013A',
            description  = 'SYSREF_DIV[12:8]',
            offset       = (0x013A << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x013B',
            description  = 'SYSREF_DIV[7:0]',
            offset       = (0x013B << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x013C',
            description  = 'SYSREF_DDLY[12:8]',
            offset       = (0x013C << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x013D',
            description  = 'SYSREF_DDLY[7:0]',
            offset       = (0x013D << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x013E',
            description  = 'SYSREF_PULSE_CNT',
            offset       = (0x013E << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x013F',
            description  = 'PLL2_NCLK_MUX, PLL1_NCLK_MUX, FB_MUX, FB_MUX_EN',
            offset       = (0x013F << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0140',
            description  = 'PLL1_PD, VCO_LDO_PD, VCO_PD, OSCin_PD, SYSREF_GBL_PD, SYSREF_PD, SYSREF_DDLY_PD, SYSREF_PLSR_PD',
            offset       = (0x0140 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0141',
            description  = 'DDLYdSYSREF_EN, DDLYdX_EN',
            offset       = (0x0141 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0142',
            description  = 'DDLYd_STEP_CNT',
            offset       = (0x0142 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0143',
            description  = 'SYSREF_CLR, SYNC_1SHOT_EN, SYNC_POL, SYNC_EN, SYNC_PLL2_DLD, SYNC_PLL1_DLD, SYNC_MODE',
            offset       = (0x0143 << 2),
            bitSize      = 8,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0144',
            description  = 'SYNC_DISSYSREF, SYNC_DISX',
            offset       = (0x0144 << 2),
            bitSize      = 8,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0145',
            description  = 'Always program to 127 (0x7F)',
            offset       = (0x0145 << 2),
            bitSize      = 8,
            mode         = 'WO',
            value        = 0x7F,
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0171',
            description  = 'Always program to 170 (0xAA)',
            offset       = (0x0171 << 2),
            bitSize      = 8,
            mode         = 'WO',
            value        = 0xAA,
        ))
        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0172',
            description  = 'Always program to 2 (0x02)',
            offset       = (0x0172 << 2),
            bitSize      = 8,
            mode         = 'WO',
            value        = 0x02,
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0146',
            description  = 'CLKin2_EN, CLKin1_EN, CLKin0_EN, CLKin2_TYPE, CLKin1_TYPE, CLKin0_TYPE',
            offset       = (0x0146 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0147',
            description  = 'CLKin_SEL_POL, CLKin_SEL_MODE, CLKin1_OUT_MUX, CLKin0_OUT_MUX',
            offset       = (0x0147 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0148',
            description  = 'CLKin_SEL0_MUX, CLKin_SEL0_TYPE',
            offset       = (0x0148 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0149',
            description  = 'SDIO_RDBK_TYPE, CLKin_SEL1_MUX, CLKin_SEL1_TYPE',
            offset       = (0x0149 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x014A',
            description  = 'RESET_MUX, RESET_TYPE',
            offset       = (0x014A << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x014B',
            description  = 'LOS_TIMEOUT, LOS_EN, TRACK_EN, HOLDOVER_FORCE, MAN_DAC_EN, MAN_DAC[9:8]',
            offset       = (0x014B << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x014C',
            description  = 'MAN_DAC[9:8], MAN_DAC[7:0]',
            offset       = (0x014C << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x014D',
            description  = 'DAC_TRIP_LOW',
            offset       = (0x014D << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x014E',
            description  = 'DAC_CLK_MULT, DAC_TRIP_HIGH',
            offset       = (0x014E << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x014F',
            description  = 'DAC_CLK_CNTR',
            offset       = (0x014F << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0150',
            description  = 'CLKin_OVERRIDE, HOLDOVER_PLL1_DET, HOLDOVER_LOS_DET, HOLDOVER_VTUNE_DET, HOLDOVER_HITLESS_SWITCH, HOLDOVER_EN',
            offset       = (0x0150 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0151',
            description  = 'HOLDOVER_DLD_CNT[13:8]',
            offset       = (0x0151 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0152',
            description  = 'HOLDOVER_DLD_CNT[7:0]',
            offset       = (0x0152 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0153',
            description  = 'CLKin0_R[13:8]',
            offset       = (0x0153 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0154',
            description  = 'CLKin0_R[7:0]',
            offset       = (0x0154 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0155',
            description  = 'CLKin1_R[13:8]',
            offset       = (0x0155 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0156',
            description  = 'CLKin1_R[7:0]',
            offset       = (0x0156 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0157',
            description  = 'CLKin2_R[13:8]',
            offset       = (0x0157 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0158',
            description  = 'CLKin2_R[7:0]',
            offset       = (0x0158 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0159',
            description  = 'PLL1_N[13:8]',
            offset       = (0x0159 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x015A',
            description  = 'PLL1_N[7:0]',
            offset       = (0x015A << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x015B',
            description  = 'PLL1_WND_SIZE, PLL1_CP_TRI, PLL1_CP_POL, PLL1_CP_GAIN',
            offset       = (0x015B << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x015C',
            description  = 'PLL1_DLD_CNT[13:8]',
            offset       = (0x015C << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x015D',
            description  = 'PLL1_DLD_CNT[7:0]',
            offset       = (0x015D << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x015E',
            description  = 'PLL1_R_DLY, PLL1_N_DLY',
            offset       = (0x015E << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x015F',
            description  = 'PLL1_LD_MUX, PLL1_LD_TYPE',
            offset       = (0x015F << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0160',
            description  = 'PLL2_R[11:8]',
            offset       = (0x0160 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0161',
            description  = 'PLL2_R[7:0]',
            offset       = (0x0161 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0162',
            description  = 'PLL2_P, OSCin_FREQ, PLL2_XTAL_EN, PLL2_REF_2X_EN',
            offset       = (0x0162 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0163',
            description  = 'PLL2_N_CAL[17:16]',
            offset       = (0x0163 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0164',
            description  = 'PLL2_N_CAL[15:8]',
            offset       = (0x0164 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0165',
            description  = 'PLL2_N_CAL[7:0]',
            offset       = (0x0165 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0166',
            description  = 'PLL2_FCAL_DIS, PLL2_N[17:16]',
            offset       = (0x0166 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0167',
            description  = 'PLL2_N[15:8]',
            offset       = (0x0167 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0168',
            description  = 'PLL2_N[7:0]',
            offset       = (0x0168 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0169',
            description  = 'PLL2_WND_SIZE, PLL2_CP_GAIN, PLL2_CP_POL, PLL2_CP_TRI',
            offset       = (0x0169 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x016A',
            description  = 'SYSREF_REQ_EN, PLL2_DLD_CNT[13:8]',
            offset       = (0x016A << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x016B',
            description  = 'PLL2_DLD_CNT[7:0]',
            offset       = (0x016B << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x016C',
            description  = 'PLL2_LF_R4, PLL2_LF_R3',
            offset       = (0x016C << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0173',
            description  = 'PLL2_PRE_PD, PLL2_PD',
            offset       = (0x0173 << 2),
            bitSize      = 8,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0182',
            description  = 'RB_PLL1_LD_LOST, RB_PLL1_LD, CLR_PLL1_LD_LOST',
            offset       = (0x0182 << 2),
            bitSize      = 8,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0183',
            description  = 'RB_PLL2_LD_LOST, RB_PLL2_LD, CLR_PLL2_LD_LOST',
            offset       = (0x0183 << 2),
            bitSize      = 8,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0184',
            description  = 'RB_DAC_VALUE[9:8], RB_CLKinX_SEL, RB_CLKinX_LOS',
            offset       = (0x0184 << 2),
            bitSize      = 8,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0185',
            description  = 'RB_DAC_VALUE[7:0]',
            offset       = (0x0185 << 2),
            bitSize      = 8,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LmkReg_0x0188',
            description  = 'RB_HOLDOVER',
            offset       = (0x0188 << 2),
            bitSize      = 8,
            mode         = 'RO',
        ))

        ######################################
        #        Aliased Registers
        ######################################

        self.add(pr.RemoteVariable(
            name         = 'SYNC_MODE',
            description  = 'SYNC MODE',
            offset       = (0x0143 << 2),
            bitSize      = 2,
            bitOffset    = 0,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'SYNC_PLL1_DLD',
            description  = 'SyncBit',
            offset       = (0x0143 << 2),
            bitSize      = 1,
            bitOffset    = 2,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'SYNC_PLL2_DLD',
            description  = 'SyncBit',
            offset       = (0x0143 << 2),
            bitSize      = 1,
            bitOffset    = 2,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'SYNC_EN',
            description  = 'Enable the SYNC functionality',
            offset       = (0x0143 << 2),
            bitSize      = 1,
            bitOffset    = 4,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'SyncBit',
            description  = 'Sets the polarity of the SYNC pin',
            offset       = (0x0143 << 2),
            bitSize      = 1,
            bitOffset    = 5,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'SYNC_1SHOT_EN',
            description  = '0 - SYNC is level sensitive, 1 - SYNC is edge sensitive',
            offset       = (0x0143 << 2),
            bitSize      = 1,
            bitOffset    = 6,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'SYSREF_CLR',
            description  = 'SYSREF clear',
            offset       = (0x0143 << 2),
            bitSize      = 1,
            bitOffset    = 0x07,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'EnableSync',
            description  = 'EnableSync',
            offset       = (0x0144 << 2),
            bitSize      = 8,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'EnableSysRef',
            description  = 'EnableSysRef',
            offset       = (0x0139 << 2),
            bitSize      = 2,
            mode         = 'RW',
            verify       = False, # Don't verify because changes during JesdReset() JesdInit() commands
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'ID_VNDR_LOWER',
            description  = 'ID_VNDR_LOWER',
            offset       = (0x000D << 2),
            bitSize      = 8,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'ID_VNDR_UPPER',
            description  = 'ID_VNDR_UPPER',
            offset       = (0x000C << 2),
            bitSize      = 8,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'ID_MASKREV',
            description  = 'ID_MASKREV',
            offset       = (0x0006 << 2),
            bitSize      = 8,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'ID_PROD_LOWER',
            description  = 'ID_PROD_LOWER',
            offset       = (0x0005 << 2),
            bitSize      = 8,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'ID_PROD_UPPER',
            description  = 'ID_PROD_UPPER',
            offset       = (0x0004 << 2),
            bitSize      = 8,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'ID_DEVICE_TYPE',
            description  = 'ID_DEVICE_TYPE',
            offset       = (0x0003 << 2),
            bitSize      = 8,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'POWER_DOWN',
            description  = 'POWER_DOWN',
            offset       = (0x0002 << 2),
            bitSize      = 1,
            mode         = 'RW',
        ))

        ##############################
        # Commands
        ##############################
        @self.command(description='Load the CodeLoader .MAC file',value='',)
        def LoadCodeLoaderMacFile(arg):
            addr = 0
            # Open the input file
            with open(arg, 'r') as ifd:
                for i, line in enumerate(ifd):
                    line = line.strip()
                    if (i<18):
                        if (i==0) and ( line != '[SETUP]'):
                            print ('invalid file detected at line#1')
                            break
                        elif (i==5) and ( line != 'PART=LMK04828B'):
                            print ('invalid file detected at line#6')
                            break
                        elif (i==11) and ( line != '[MODES]'):
                            print ('invalid file detected at line#12')
                            break
                        elif (i==12) and ( line != 'NAME00=R0 (INIT)'):
                            print ('invalid file detected at line#13')
                            break
                    elif (i<232):
                        if(i%2):
                            pat = re.compile('[=]')
                            fields=pat.split(line)
                            data = (ast.literal_eval(fields[1])&0xFF)
                            v = getattr(self, 'LmkReg_0x%04X'%addr)
                            v.set(data)
                            if(addr==357):
                                self.LmkReg_0x0171.set(0xAA)
                                self.LmkReg_0x0172.set(0x02)
                                self.LmkReg_0x0173.set(0x00)
                                self.LmkReg_0x0174.set(0x00)
                        else:
                            pat = re.compile('[R\t\n]')
                            fields=pat.split(line)
                            addr = ast.literal_eval(fields[1])
                    else:
                        pass
            ifd.close()

        @self.command(description='Powerdown the sysref lines',)
        def PwrDwnSysRef():
            self.EnableSysRef.set(0)
            time.sleep(0.010) # TODO: Optimize this timeout

        @self.command(description='Powerup the sysref lines',)
        def PwrUpSysRef():
            self.EnableSysRef.set(self.sysrefMode)
            self.LmkReg_0x0143.set(0x12)
            time.sleep(0.010) # TODO: Optimize this timeout
            self.LmkReg_0x0143.set(0x32)
            time.sleep(0.010) # TODO: Optimize this timeout
            self.LmkReg_0x0143.set(0x12)
            time.sleep(0.010) # TODO: Optimize this timeout

        @self.command(description='1: Powerdown',)
        def PwrDwnLmkChip():
            self.POWER_DOWN.set(1)
            time.sleep(0.010) # TODO: Optimize this timeout

        @self.command(description='0: Normal Operation',)
        def PwrUpLmkChip():
            self.POWER_DOWN.set(0)
            time.sleep(0.010) # TODO: Optimize this timeout

        @self.command(description='Synchronize LMK internal counters. Warning this function will power off and power on all the system clocks',)
        def Init():
            self.sysrefMode = self.EnableSysRef.get()
            time.sleep(0.010) # TODO: Optimize this timeout
            self.LmkReg_0x0139.set(0x0)
            time.sleep(0.010) # TODO: Optimize this timeout
            self.LmkReg_0x0143.set(0x11)
            time.sleep(0.010) # TODO: Optimize this timeout
            self.LmkReg_0x0140.set(0x0)
            time.sleep(0.010) # TODO: Optimize this timeout
            self.LmkReg_0x0144.set(0x74)
            time.sleep(0.010) # TODO: Optimize this timeout
            self.LmkReg_0x0143.set(0x11)
            time.sleep(0.010) # TODO: Optimize this timeout
            self.LmkReg_0x0143.set(0x31)
            time.sleep(0.010) # TODO: Optimize this timeout
            self.LmkReg_0x0143.set(0x11)
            time.sleep(0.010) # TODO: Optimize this timeout
            self.LmkReg_0x0144.set(0xFF)
            time.sleep(0.010) # TODO: Optimize this timeout
            self.LmkReg_0x0139.set(0x2)
            time.sleep(0.010) # TODO: Optimize this timeout
            self.LmkReg_0x013E.set(0x3)
            time.sleep(0.010) # TODO: Optimize this timeout
            self.LmkReg_0x0143.set(0x12)
            time.sleep(0.010) # TODO: Optimize this timeout
            self.LmkReg_0x0143.set(0x32)
            time.sleep(0.010) # TODO: Optimize this timeout
            self.LmkReg_0x0143.set(0x12)
            time.sleep(0.010) # TODO: Optimize this timeout

            # Fixed Register:
            self.LmkReg_0x0145.set(0x7F) # Always program this register to value 127 (0x7F)
            time.sleep(0.010) # TODO: Optimize this timeout
            self.LmkReg_0x0171.set(0xAA) # Always program to 170 (0xAA)
            time.sleep(0.010) # TODO: Optimize this timeout
            self.LmkReg_0x0172.set(0x02) # Always program to 2 (0x02)
            time.sleep(0.010) # TODO: Optimize this timeout
