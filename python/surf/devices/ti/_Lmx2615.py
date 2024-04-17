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

class Lmx2615(pr.Device):
    def __init__(self, **kwargs):

        #####################################################################
        # Address = 0x00 (R0)
        # Write only because MUXOUT_LD_SEL's default is not readback SPI mode
        #####################################################################
        super().__init__(**kwargs)

        self.add(pr.RemoteVariable(
            name         = "DataBlock",
            description  = "",
            offset       = 0,
            bitSize      = 32 * 1024,
            bitOffset    = 0,
            numValues    = 1024,
            valueBits    = 32,
            valueStride  = 32,
            updateNotify = True,
            bulkOpEn     = False, # FALSE for large variables
            overlapEn    = True,
            verify       = False, # FALSE due to a mix of RO/WO/RW variables
            hidden       = True,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.RemoteVariable(
            name         = 'VCO_PHASE_SYNC',
            offset       = (0x00 << 2),
            bitOffset    = 14,
            bitSize      = 1,
            mode         = 'WO',
            value        = 1,
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'OUT_MUTE',
            offset       = (0x00 << 2),
            bitOffset    = 9,
            bitSize      = 1,
            mode         = 'WO',
            value        = 1,
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'FCAL_HPFD_ADJ',
            offset       = (0x00 << 2),
            bitOffset    = 7,
            bitSize      = 2,
            mode         = 'WO',
            value        = 0,
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'FCAL_EN',
            offset       = (0x00 << 2),
            bitOffset    = 3,
            bitSize      = 1,
            mode         = 'WO',
            value        = 1,
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'MUXOUT_LD_SEL',
            offset       = (0x00 << 2),
            bitOffset    = 2,
            bitSize      = 1,
            mode         = 'RW',
            value        = 0,
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'RESET',
            offset       = (0x00 << 2),
            bitOffset    = 1,
            bitSize      = 1,
            mode         = 'WO',
            value        = 0,
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'POWERDOWN',
            offset       = (0x00 << 2),
            bitOffset    = 0,
            bitSize      = 1,
            mode         = 'WO',
            value        = 0,
            overlapEn    = True,
        ))

        #######################
        # Address = 0x01 (R1)
        #######################

        self.add(pr.RemoteVariable(
            name         = 'CAL_CLK_DIV',
            offset       = (0x01 << 2),
            bitOffset    = 0,
            bitSize      = 3,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################
        # Address = 0x08 (R8)
        #######################

        self.add(pr.RemoteVariable(
            name         = 'VCO_DACISET_FORCE',
            offset       = (0x08 << 2),
            bitOffset    = 14,
            bitSize      = 1,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'VCO_CAPCTRL_FORCE',
            offset       = (0x08 << 2),
            bitOffset    = 11,
            bitSize      = 1,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################
        # Address = 0x09 (R9)
        #######################

        self.add(pr.RemoteVariable(
            name         = 'OSC_2X',
            offset       = (0x09 << 2),
            bitOffset    = 12,
            bitSize      = 1,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################
        # Address = 0x0B (R11)
        #######################

        self.add(pr.RemoteVariable(
            name         = 'PLL_R',
            offset       = (0x0B << 2),
            bitOffset    = 4,
            bitSize      = 8,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################
        # Address = 0x0C (R12)
        #######################

        self.add(pr.RemoteVariable(
            name         = 'PLL_R_PRE',
            offset       = (0x0C << 2),
            bitOffset    = 0,
            bitSize      = 8,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################
        # Address = 0x0E (R14)
        #######################

        self.add(pr.RemoteVariable(
            name         = 'CPG',
            offset       = (0x0E << 2),
            bitOffset    = 4,
            bitSize      = 3,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################
        # Address = 0x10 (R16)
        #######################

        self.add(pr.RemoteVariable(
            name         = 'VCO_DACISET',
            offset       = (0x10 << 2),
            bitOffset    = 0,
            bitSize      = 9,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################
        # Address = 0x13 (R19)
        #######################

        self.add(pr.RemoteVariable(
            name         = 'VCO_CAPCTRL',
            offset       = (0x13 << 2),
            bitOffset    = 0,
            bitSize      = 8,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################
        # Address = 0x14 (R20)
        #######################

        self.add(pr.RemoteVariable(
            name         = 'VCO_SEL',
            offset       = (0x14 << 2),
            bitOffset    = 11,
            bitSize      = 3,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'VCO_SEL_FORCE',
            offset       = (0x14 << 2),
            bitOffset    = 10,
            bitSize      = 1,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################
        # Address = 0x1F (R31)
        #######################

        self.add(pr.RemoteVariable(
            name         = 'SEG1_EN',
            offset       = (0x1F << 2),
            bitOffset    = 14,
            bitSize      = 1,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################
        # Address = 0x22 (R34)
        #######################

        self.add(pr.RemoteVariable(
            name         = 'PLL_N_18_16',
            offset       = (0x22 << 2),
            bitOffset    = 0,
            bitSize      = 3,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################
        # Address = 0x24 (R36)
        #######################

        self.add(pr.RemoteVariable(
            name         = 'PLL_N',
            offset       = (0x24 << 2),
            bitOffset    = 0,
            bitSize      = 16,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################
        # Address = 0x25 (R37)
        #######################

        self.add(pr.RemoteVariable(
            name         = 'PFD_DLY_SEL',
            offset       = (0x25 << 2),
            bitOffset    = 8,
            bitSize      = 6,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################
        # Address = 0x26 (R38)
        #######################

        self.add(pr.RemoteVariable(
            name         = 'PLL_DEN_31_16',
            offset       = (0x26 << 2),
            bitOffset    = 0,
            bitSize      = 16,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################
        # Address = 0x27 (R39)
        #######################

        self.add(pr.RemoteVariable(
            name         = 'PLL_DEN',
            offset       = (0x27 << 2),
            bitOffset    = 0,
            bitSize      = 16,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################
        # Address = 0x28 (R40)
        #######################

        self.add(pr.RemoteVariable(
            name         = 'MASH_SEED_31_16',
            offset       = (0x28 << 2),
            bitOffset    = 0,
            bitSize      = 16,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################
        # Address = 0x29 (R41)
        #######################

        self.add(pr.RemoteVariable(
            name         = 'MASH_SEED',
            offset       = (0x29 << 2),
            bitOffset    = 0,
            bitSize      = 16,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################
        # Address = 0x2A (R42)
        #######################

        self.add(pr.RemoteVariable(
            name         = 'PLL_NUM_31_16',
            offset       = (0x2A << 2),
            bitOffset    = 0,
            bitSize      = 16,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################
        # Address = 0x2B (R43)
        #######################

        self.add(pr.RemoteVariable(
            name         = 'PLL_NUM',
            offset       = (0x2B << 2),
            bitOffset    = 0,
            bitSize      = 16,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################
        # Address = 0x2C (R44)
        #######################

        self.add(pr.RemoteVariable(
            name         = 'OUTA_PWR',
            offset       = (0x2C << 2),
            bitOffset    = 8,
            bitSize      = 6,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'OUTB_PD',
            offset       = (0x2C << 2),
            bitOffset    = 7,
            bitSize      = 1,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'OUTA_PD',
            offset       = (0x2C << 2),
            bitOffset    = 6,
            bitSize      = 1,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'MASH_RESET_N',
            offset       = (0x2C << 2),
            bitOffset    = 5,
            bitSize      = 1,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'MASH_ORDER',
            offset       = (0x2C << 2),
            bitOffset    = 0,
            bitSize      = 3,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################
        # Address = 0x2D (R45)
        #######################

        self.add(pr.RemoteVariable(
            name         = 'OUTA_MUX',
            offset       = (0x2D << 2),
            bitOffset    = 11,
            bitSize      = 2,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'OUTB_PWR',
            offset       = (0x2D << 2),
            bitOffset    = 0,
            bitSize      = 6,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################
        # Address = 0x2E (R46)
        #######################

        self.add(pr.RemoteVariable(
            name         = 'OUTB_MUX',
            offset       = (0x2E << 2),
            bitOffset    = 0,
            bitSize      = 2,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################
        # Address = 0x3A (R58)
        #######################

        self.add(pr.RemoteVariable(
            name         = 'INPIN_IGNORE',
            offset       = (0x3A << 2),
            bitOffset    = 15,
            bitSize      = 1,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################
        # Address = 0x3B (R59)
        #######################

        self.add(pr.RemoteVariable(
            name         = 'LD_TYPE',
            offset       = (0x3B << 2),
            bitOffset    = 0,
            bitSize      = 1,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################
        # Address = 0x3C (R60)
        #######################

        self.add(pr.RemoteVariable(
            name         = 'LD_DLY',
            offset       = (0x3C << 2),
            bitOffset    = 0,
            bitSize      = 16,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################
        # Address = 0x45 (R69)
        #######################

        self.add(pr.RemoteVariable(
            name         = 'MASH_RST_COUNT_31_16',
            offset       = (0x45 << 2),
            bitOffset    = 0,
            bitSize      = 16,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################
        # Address = 0x46 (R70)
        #######################

        self.add(pr.RemoteVariable(
            name         = 'MASH_RST_COUNT',
            offset       = (0x46 << 2),
            bitOffset    = 0,
            bitSize      = 16,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################
        # Address = 0x47 (R71)
        #######################

        self.add(pr.RemoteVariable(
            name         = 'SYSREF_DIV_PRE',
            offset       = (0x47 << 2),
            bitOffset    = 5,
            bitSize      = 3,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'SYSREF_PULSE',
            offset       = (0x47 << 2),
            bitOffset    = 4,
            bitSize      = 1,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'SYSREF_EN',
            offset       = (0x47 << 2),
            bitOffset    = 3,
            bitSize      = 1,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'SYSREF_REPEAT',
            offset       = (0x47 << 2),
            bitOffset    = 2,
            bitSize      = 1,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################
        # Address = 0x48 (R72)
        #######################

        self.add(pr.RemoteVariable(
            name         = 'SYSREF_DIV',
            offset       = (0x48 << 2),
            bitOffset    = 0,
            bitSize      = 11,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################
        # Address = 0x49 (R73)
        #######################

        self.add(pr.RemoteVariable(
            name         = 'JESD_DAC2_CTRL',
            offset       = (0x49 << 2),
            bitOffset    = 6,
            bitSize      = 6,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'JESD_DAC1_CTRL',
            offset       = (0x49 << 2),
            bitOffset    = 0,
            bitSize      = 6,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################
        # Address = 0x4A (R74)
        #######################

        self.add(pr.RemoteVariable(
            name         = 'SYSREF_PULSE_CNT',
            offset       = (0x4A << 2),
            bitOffset    = 12,
            bitSize      = 4,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'JESD_DAC4_CTRL',
            offset       = (0x4A << 2),
            bitOffset    = 6,
            bitSize      = 6,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'JESD_DAC3_CTRL',
            offset       = (0x4A << 2),
            bitOffset    = 0,
            bitSize      = 6,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################
        # Address = 0x4B (R75)
        #######################

        self.add(pr.RemoteVariable(
            name         = 'CHDIV',
            offset       = (0x4B << 2),
            bitOffset    = 6,
            bitSize      = 5,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################
        # Address = 0x6E (R110)
        #######################

        self.add(pr.RemoteVariable(
            name         = 'rb_LD_VTUNE',
            offset       = (0x6E << 2),
            bitOffset    = 9,
            bitSize      = 2,
            mode         = 'RO',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'rb_VCO_SEL',
            offset       = (0x6E << 2),
            bitOffset    = 5,
            bitSize      = 3,
            mode         = 'RO',
            overlapEn    = True,
        ))

        #######################
        # Address = 0x6F (R111)
        #######################

        self.add(pr.RemoteVariable(
            name         = 'rb_VCO_CAPCTRL',
            offset       = (0x6F << 2),
            bitOffset    = 0,
            bitSize      = 8,
            mode         = 'RO',
            overlapEn    = True,
        ))

        #######################
        # Address = 0x70 (R112)
        #######################

        self.add(pr.RemoteVariable(
            name         = 'rb_VCO_DACISET',
            offset       = (0x70 << 2),
            bitOffset    = 0,
            bitSize      = 9,
            mode         = 'RO',
            overlapEn    = True,
        ))

        #######################
        # Address = 0x71 (R113)
        #######################

        self.add(pr.RemoteVariable(
            name         = 'rb_IO_STATUS',
            offset       = (0x71 << 2),
            bitOffset    = 0,
            bitSize      = 16,
            mode         = 'RO',
            overlapEn    = True,
        ))

        #######################
        # Address = 0x72 (R114)
        #######################

        self.add(pr.RemoteVariable(
            name         = 'WD_DLY',
            offset       = (0x72 << 2),
            bitOffset    = 3,
            bitSize      = 7,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'WD_CNTRL',
            offset       = (0x72 << 2),
            bitOffset    = 0,
            bitSize      = 3,
            mode         = 'RW',
            overlapEn    = True,
        ))

        #######################


        @self.command(description='Enable SPI readback',)
        def enSpiReadback():
            self.MUXOUT_LD_SEL.set(0x0)

        @self.command(description='Power Up procedure',)
        def pwrUp():
            print('lmx pwrUp')
            # Setup for SPI readback mode
            self.MUXOUT_LD_SEL.set(0x0)

            # Power up the device
            self.POWERDOWN.set(0x0)

            # Toggle the reset
            self.RESET.set(0x1)
            self.RESET.set(0x0)

        @self.command(description='Load the CodeLoader Hex Export file',value='',)
        def LoadCodeLoaderHexFile(arg):
            with open(arg, 'r') as ifd:
                for i, line in enumerate(ifd):
                    s = str.split(line)
                    addr = int(s[0][1:], 0)
                    if len(s) == 3:
                        data = int("0x" + s[2][-4:], 0)
                    else:
                        data = int("0x" + s[1][-4:], 0)
                    print(f'writing {addr:#04x}: {data:#06x}')
                    self.DataBlock.set(value=data, index=addr, write=True)

            self.MUXOUT_LD_SEL.set(0x0)
