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
            description  = "Raw register data block for bulk configuration loading",
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
            groups       = ['NoStream','NoState','NoConfig'], # Not saving config/state to YAML
        ))

        self.add(pr.RemoteVariable(
            name         = 'VCO_PHASE_SYNC',
            description  = 'Enable VCO phase synchronization to SYSREF',
            offset       = (0x00 << 2),
            bitOffset    = 14,
            bitSize      = 1,
            mode         = 'WO',
            value        = 1,
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'OUT_MUTE',
            description  = 'Mute all output channels when set',
            offset       = (0x00 << 2),
            bitOffset    = 9,
            bitSize      = 1,
            mode         = 'WO',
            value        = 1,
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'FCAL_HPFD_ADJ',
            description  = 'Fast calibration high phase frequency detector adjustment',
            offset       = (0x00 << 2),
            bitOffset    = 7,
            bitSize      = 2,
            mode         = 'WO',
            value        = 0,
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'FCAL_EN',
            description  = 'Enable VCO frequency calibration on next register write',
            offset       = (0x00 << 2),
            bitOffset    = 3,
            bitSize      = 1,
            mode         = 'WO',
            value        = 1,
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'MUXOUT_LD_SEL',
            description  = 'Select MUXOUT pin function: 0 = readback SPI, 1 = lock detect',
            offset       = (0x00 << 2),
            bitOffset    = 2,
            bitSize      = 1,
            mode         = 'RW',
            value        = 0,
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'RESET',
            description  = 'Software reset: write 1 then 0 to reset device registers',
            offset       = (0x00 << 2),
            bitOffset    = 1,
            bitSize      = 1,
            mode         = 'WO',
            value        = 0,
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'POWERDOWN',
            description  = 'Power down the device when set to 1',
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
            description  = 'Calibration clock divider ratio for VCO amplitude calibration',
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
            description  = 'Force VCO amplitude DAC to use VCO_DACISET register value',
            offset       = (0x08 << 2),
            bitOffset    = 14,
            bitSize      = 1,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'VCO_CAPCTRL_FORCE',
            description  = 'Force VCO capacitor control to use VCO_CAPCTRL register value',
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
            description  = 'Enable frequency doubler on OSCin input',
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
            description  = 'PLL reference divider ratio',
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
            description  = 'PLL pre-reference divider applied before PLL_R',
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
            description  = 'PLL charge pump gain setting',
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
            description  = 'VCO amplitude DAC setting used when VCO_DACISET_FORCE is set',
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
            description  = 'VCO capacitor control setting used when VCO_CAPCTRL_FORCE is set',
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
            description  = 'VCO core selection used when VCO_SEL_FORCE is set',
            offset       = (0x14 << 2),
            bitOffset    = 11,
            bitSize      = 3,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'VCO_SEL_FORCE',
            description  = 'Force VCO core selection to use VCO_SEL register value',
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
            description  = 'Enable segment 1 of the fractional modulator',
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
            description  = 'PLL integer divider upper 3 bits [18:16]',
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
            description  = 'PLL integer divider lower 16 bits [15:0]',
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
            description  = 'Phase frequency detector delay selection for spur reduction',
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
            description  = 'PLL fractional modulator denominator upper 16 bits [31:16]',
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
            description  = 'PLL fractional modulator denominator lower 16 bits [15:0]',
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
            description  = 'MASH sigma-delta modulator seed upper 16 bits [31:16]',
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
            description  = 'MASH sigma-delta modulator seed lower 16 bits [15:0]',
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
            description  = 'PLL fractional modulator numerator upper 16 bits [31:16]',
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
            description  = 'PLL fractional modulator numerator lower 16 bits [15:0]',
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
            description  = 'Output A power level setting',
            offset       = (0x2C << 2),
            bitOffset    = 8,
            bitSize      = 6,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'OUTB_PD',
            description  = 'Power down output B when set to 1',
            offset       = (0x2C << 2),
            bitOffset    = 7,
            bitSize      = 1,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'OUTA_PD',
            description  = 'Power down output A when set to 1',
            offset       = (0x2C << 2),
            bitOffset    = 6,
            bitSize      = 1,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'MASH_RESET_N',
            description  = 'MASH sigma-delta reset: 0 = reset active, 1 = normal operation',
            offset       = (0x2C << 2),
            bitOffset    = 5,
            bitSize      = 1,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'MASH_ORDER',
            description  = 'MASH sigma-delta modulator order selection',
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
            description  = 'Output A source mux: 0 = channel divider, 1 = VCO, 2 = high-Z',
            offset       = (0x2D << 2),
            bitOffset    = 11,
            bitSize      = 2,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'OUTB_PWR',
            description  = 'Output B power level setting',
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
            description  = 'Output B source mux: 0 = channel divider, 1 = VCO, 2 = high-Z',
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
            description  = 'Ignore SYNC, ENCLK1, ENCLK2 input pins and use SPI control only',
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
            description  = 'Lock detect type: 0 = VCO tuning voltage lock detect, 1 = PLL lock detect',
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
            description  = 'Lock detect delay before asserting the lock detect output',
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
            description  = 'MASH reset count upper 16 bits [31:16]',
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
            description  = 'MASH reset count lower 16 bits [15:0]',
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
            description  = 'SYSREF pre-divider ratio applied before SYSREF_DIV',
            offset       = (0x47 << 2),
            bitOffset    = 5,
            bitSize      = 3,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'SYSREF_PULSE',
            description  = 'Enable SYSREF pulse mode output',
            offset       = (0x47 << 2),
            bitOffset    = 4,
            bitSize      = 1,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'SYSREF_EN',
            description  = 'Enable SYSREF output generation',
            offset       = (0x47 << 2),
            bitOffset    = 3,
            bitSize      = 1,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'SYSREF_REPEAT',
            description  = 'Enable continuous SYSREF repeat mode',
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
            description  = 'SYSREF divider ratio',
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
            description  = 'JESD DAC2 output control value for SYSREF timing adjustment',
            offset       = (0x49 << 2),
            bitOffset    = 6,
            bitSize      = 6,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'JESD_DAC1_CTRL',
            description  = 'JESD DAC1 output control value for SYSREF timing adjustment',
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
            description  = 'Number of SYSREF pulses to generate in pulse mode',
            offset       = (0x4A << 2),
            bitOffset    = 12,
            bitSize      = 4,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'JESD_DAC4_CTRL',
            description  = 'JESD DAC4 output control value for SYSREF timing adjustment',
            offset       = (0x4A << 2),
            bitOffset    = 6,
            bitSize      = 6,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'JESD_DAC3_CTRL',
            description  = 'JESD DAC3 output control value for SYSREF timing adjustment',
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
            description  = 'Output channel divider ratio',
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
            description  = 'Readback: VCO tuning voltage lock detect and VTUNE status',
            offset       = (0x6E << 2),
            bitOffset    = 9,
            bitSize      = 2,
            mode         = 'RO',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'rb_VCO_SEL',
            description  = 'Readback: active VCO core selection after calibration',
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
            description  = 'Readback: VCO capacitor control value after calibration',
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
            description  = 'Readback: VCO amplitude DAC value after calibration',
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
            description  = 'Readback: device I/O pin status register',
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
            description  = 'Watchdog timer delay count before lock loss detection',
            offset       = (0x72 << 2),
            bitOffset    = 3,
            bitSize      = 7,
            mode         = 'RW',
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'WD_CNTRL',
            description  = 'Watchdog timer control and enable',
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
