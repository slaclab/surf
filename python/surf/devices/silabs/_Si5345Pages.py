#-----------------------------------------------------------------------------
# This file is part of 'SLAC Firmware Standard Library'.
# It is subject to the license terms in the LICENSE.txt file found in the
# top-level directory of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of 'SLAC Firmware Standard Library', including this file,
# may be copied, modified, propagated, or distributed except according to
# the terms contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr
import rogue

rogue.Version.minVersion('5.4.0')

class Si5345PageBase(pr.Device):
    def __init__(self,
            name          = "PageBase",
            description   = "Base page",
            **kwargs):

        super().__init__(name=name, description=description, **kwargs)

        self.add(pr.RemoteVariable(
            name         = "DataBlock",
            description  = "",
            offset       = 0,
            bitSize      = 32 * 0x100,
            bitOffset    = 0,
            numValues    = 0x100,
            valueBits    = 32,
            valueStride  = 32,
            updateNotify = True,
            bulkOpEn     = False, # FALSE for large variables
            overlapEn    = False,
            verify       = False, # FALSE due to a mix of RO/WO/RW variables
            hidden       = True,
            base         = pr.UInt,
            mode         = "RW",
        ))

    def MyLinkVariable(self, name, description, offset, bitSize, mode, bitOffset=0, pollInterval=0, value=None, hidden=False):

        self.add(pr.LinkVariable(
            name         = name,
            description  = description,
            linkedGet    = lambda var: (self.DataBlock.value(index=offset//4)>>bitOffset)&((2**bitSize)-1),
            linkedSet    = lambda var, value, write: self.DataBlock.set(value=( (0xFFFF_FFFF ^ (((2**bitSize)-1)<<bitOffset)) & self.DataBlock.get(index=offset//4) ) | (value<<bitOffset),index=offset//4, write=write),
            mode         = mode,
            pollInterval = pollInterval,
            value        = value,
            hidden       = hidden,
            disp         = '0x{:x}',
            dependencies = [self.DataBlock],
        ))

class Si5345Page0(Si5345PageBase):
    def __init__(self,
            name          = "Page0",
            description   = "Alarms, interrupts, reset, other configuration",
            simpleDisplay = True,
            **kwargs):

        super().__init__(name=name, description=description, **kwargs)

        ##############################
        # 15.1 Page 0 Registers Si5345
        ##############################
        self.MyLinkVariable(
            name        = 'PN_BASE_LO',
            description = 'Four-digit base part number, one nibble per digit.',
            offset      = (0x02 << 2),
            bitSize     = 8,
            mode        = 'RO',
        )

        self.MyLinkVariable(
            name        = 'PN_BASE_HI',
            description = 'Four-digit base part number, one nibble per digit.',
            offset      = (0x03 << 2),
            bitSize     = 8,
            mode        = 'RO',
        )

        self.MyLinkVariable(
            name         = 'GRADE',
            description  = 'One ASCII character indicating the device speed/synthesis mode.',
            offset       = (0x04 << 2),
            bitSize      = 2,
            mode         = 'RO',
        )

        self.MyLinkVariable(
            name         = 'DEVICE_REV',
            description  = 'One ASCII character indicating the device revision level.',
            offset       = (0x05 << 2),
            bitSize      = 2,
            mode         = 'RO',
        )

        self.MyLinkVariable(
            name        = 'TOOL_VERSION[0]',
            description = 'The software tool version that creates the register values downloaded at power up is represented by TOOL_VERSION.',
            offset      = (0x06 << 2),
            bitSize     = 8,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'TOOL_VERSION[1]',
            description = 'The software tool version that creates the register values downloaded at power up is represented by TOOL_VERSION.',
            offset      = (0x07 << 2),
            bitSize     = 8,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'TOOL_VERSION[2]',
            description = 'The software tool version that creates the register values downloaded at power up is represented by TOOL_VERSION.',
            offset      = (0x08 << 2),
            bitSize     = 8,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'TEMP_GRADE',
            description = 'Device temperature grading, 0 = Industrial (40 C to 85 C) ambient conditions',
            offset      = (0x09 << 2),
            bitSize     = 8,
            mode        = 'RO',
        )

        self.MyLinkVariable(
            name        = 'PKG_ID',
            description = 'Package ID, 0 = 9x9 mm 64 QFN',
            offset      = (0x0A << 2),
            bitSize     = 8,
            mode        = 'RO',
        )

        self.MyLinkVariable(
            name        = 'I2C_ADDR',
            description = 'The upper five bits of the 7-bit I2C address.',
            offset      = (0x0B << 2),
            bitSize     = 7,
            mode        = 'RO',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name         = 'SYSINCAL',
            description  = '1 if the device is calibrating.',
            offset       = (0x0C << 2),
            bitSize      = 1,
            bitOffset    = 0,
            mode         = 'RO',
            pollInterval = 1,
        )

        self.MyLinkVariable(
            name         = 'LOSXAXB',
            description  = '1 if there is no signal at the XAXB pins.',
            offset       = (0x0C << 2),
            bitSize      = 1,
            bitOffset    = 1,
            mode         = 'RO',
            pollInterval = 1,
        )

        self.MyLinkVariable(
            name         = 'XAXB_ERR',
            description  = '1 if there is a problem locking to the XAXB input signal.',
            offset       = (0x0C << 2),
            bitSize      = 1,
            bitOffset    = 3,
            mode         = 'RO',
            pollInterval = 1,
        )

        self.MyLinkVariable(
            name        = 'SMBUS_TIMEOUT',
            description = '1 if there is an SMBus timeout error.',
            offset      = (0x0C << 2),
            bitSize     = 1,
            bitOffset   = 5,
            mode        = 'RO',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name         = 'LOS',
            description  = '1 if the clock input is currently LOS',
            offset       = (0x0D << 2),
            bitSize      = 4,
            bitOffset    = 0,
            mode         = 'RO',
            pollInterval = 1,
        )

        self.MyLinkVariable(
            name         = 'OOF',
            description  = '1 if the clock input is currently OOF',
            offset       = (0x0D << 2),
            bitSize      = 4,
            bitOffset    = 4,
            mode         = 'RO',
            pollInterval = 1,
        )

        self.MyLinkVariable(
            name         = 'LOL',
            description  = '1 if the DSPLL is out of lock',
            offset       = (0x0E << 2),
            bitSize      = 1,
            bitOffset    = 1,
            mode         = 'RO',
            pollInterval = 1,
        )

        self.MyLinkVariable(
            name         = 'HOLD',
            description  = '1 if the DSPLL is in holdover (or free run)',
            offset       = (0x0E << 2),
            bitSize      = 1,
            bitOffset    = 5,
            mode         = 'RO',
            pollInterval = 1,
        )

        self.MyLinkVariable(
            name         = 'CAL_PLL',
            description  = '1 if the DSPLL internal calibration is busy',
            offset       = (0x0F << 2),
            bitSize      = 1,
            bitOffset    = 5,
            mode         = 'RO',
            pollInterval = 1,
        )

        self.MyLinkVariable(
            name         = 'ClearIntErrFlag',
            description  = 'command to clears the internal error flags',
            offset       = (0x11 << 2),
            bitSize      = 1,
            mode         = 'WO',
            # hidden       = simpleDisplay,
        )

        self.MyLinkVariable(
            name         = 'SYSINCAL_FLG',
            description  = 'Sticky version of SYSINCAL. Write a 0 to this bit to clear.',
            offset       = (0x11 << 2),
            bitSize      = 1,
            bitOffset    = 0,
            mode         = 'RO',
            pollInterval = 1,
        )

        self.MyLinkVariable(
            name         = 'LOSXAXB_FLG',
            description  = 'Sticky version of LOSXAXB. Write a 0 to this bit to clear.',
            offset       = (0x11 << 2),
            bitSize      = 1,
            bitOffset    = 1,
            mode         = 'RO',
            pollInterval = 1,
        )

        self.MyLinkVariable(
            name         = 'XAXB_ERR_FLG',
            description  = 'Sticky version of XAXB_ERR. Write a 0 to this bit to clear.',
            offset       = (0x11 << 2),
            bitSize      = 1,
            bitOffset    = 3,
            mode         = 'RO',
            pollInterval = 1,
        )

        self.MyLinkVariable(
            name        = 'SMBUS_TIMEOUT_FLG',
            description = 'Sticky version of SMBUS_TIMEOUT. Write a 0 to this bit to clear.',
            offset      = (0x11 << 2),
            bitSize     = 1,
            bitOffset   = 5,
            mode        = 'RO',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'LOS_FLG',
            description = '1 if the clock input is LOS for the given input',
            offset      = (0x12 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RO',
        )

        self.MyLinkVariable(
            name        = 'OOF_FLG',
            description = '1 if the clock input is OOF for the given input',
            offset      = (0x12 << 2),
            bitSize     = 4,
            bitOffset   = 4,
            mode        = 'RO',
        )

        self.MyLinkVariable(
            name        = 'LOL_FLG',
            description = '1 if the DSPLL was unlocked',
            offset      = (0x13 << 2),
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RO',
        )

        self.MyLinkVariable(
            name        = 'HOLD_FLG',
            description = '1 if the DSPLL was in holdover or free run',
            offset      = (0x13 << 2),
            bitSize     = 1,
            bitOffset   = 5,
            mode        = 'RO',
        )

        self.MyLinkVariable(
            name        = 'CAL_PLL_FLG',
            description = '1 if the internal calibration was busy',
            offset      = (0x14 << 2),
            bitSize     = 1,
            bitOffset   = 5,
            mode        = 'RO',
        )

        self.MyLinkVariable(
            name        = 'LOL_ON_HOLD',
            description = 'Set by CBPro.',
            offset      = (0x16 << 2),
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'SYSINCAL_INTR_MSK',
            description = '1 to mask SYSINCAL_FLG from causing an interrupt',
            offset      = (0x17 << 2),
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'LOSXAXB_INTR_MSK',
            description = '1 to mask the LOSXAXB_FLG from causing an interrupt',
            offset      = (0x17 << 2),
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'SMBUS_TIMEOUT_FLG_MSK',
            description = '1 to mask SMBUS_TIMEOUT_FLG from the interrupt',
            offset      = (0x17 << 2),
            bitSize     = 1,
            bitOffset   = 5,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'LOS_INTR_MSK',
            description = '1 to mask the clock input LOS flag',
            offset      = (0x18 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'OOF_INTR_MSK',
            description = '1 to mask the clock input OOF flag',
            offset      = (0x18 << 2),
            bitSize     = 4,
            bitOffset   = 4,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'LOL_INTR_MSK',
            description = '1 to mask the clock input LOL flag',
            offset      = (0x19 << 2),
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'HOLD_INTR_MSK',
            description = '1 to mask the holdover flag',
            offset      = (0x19 << 2),
            bitSize     = 1,
            bitOffset   = 5,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'CAL_INTR_MSK',
            description = '1 to mask the DSPLL internal calibration busy flag',
            offset      = (0x1A << 2),
            bitSize     = 1,
            bitOffset   = 5,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = "SOFT_RST_ALL",
            description = "Initialize and calibrates the entire device",
            offset      = (0x1C << 2),
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'WO',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = "SOFT_RST",
            description = "Initialize outer loop",
            offset      = (0x1C << 2),
            bitSize     = 1,
            bitOffset   = 2,
            mode        = 'WO',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = "FINC",
            description = "1 a rising edge will cause the selected MultiSynth to increment the output frequency by the Nx_FSTEPW parameter. See registers 0x03390x0358",
            offset      = (0x1D << 2),
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'WO',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = "FDEC",
            description = "1 a rising edge will cause the selected MultiSynth to decrement the output frequency by the Nx_FSTEPW parameter. See registers 0x03390x0358",
            offset      = (0x1D << 2),
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'WO',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'PDN',
            description = '1 to put the device into low power mode',
            offset      = (0x1E << 2),
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RW',
            # hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'HARD_RST',
            description = '1 causes hard reset. The same as power up except that the serial port access is not held at reset.',
            offset      = (0x1E << 2),
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'SPI_3WIRE',
            description = '0 for 4-wire SPI, 1 for 3-wire SPI',
            offset      = (0x2B << 2),
            bitSize     = 1,
            bitOffset   = 3,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'AUTO_NDIV_UPDATE',
            description = 'Set by CBPro.',
            offset      = (0x2B << 2),
            bitSize     = 1,
            bitOffset   = 5,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'LOS_EN',
            description = '1 to enable LOS for a clock input',
            offset      = (0x2C << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'LOSXAXB_DIS',
            description = '0: Enable LOS Detection (default)',
            offset      = (0x2C << 2),
            bitSize     = 1,
            bitOffset   = 4,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        for i in range(4):
            self.MyLinkVariable(
                name        = f'LOS_VAL_TIME[{i}]',
                description = f'Clock Input[{i}]',
                offset      = (0x2D << 2),
                bitSize     = 2,
                bitOffset   = (2*i),
                mode        = 'RW',
                hidden      = simpleDisplay,
            )

        for i in range(4):
            self.MyLinkVariable(
                name        = f'LOS_TRG_THR_LO[{i}]',
                description = 'Trigger Threshold 16-bit Threshold Value',
                offset      = ((0x2E+(2*i)) << 2),
                bitSize     = 8,
                mode        = 'RW',
                hidden      = simpleDisplay,
            )
            self.MyLinkVariable(
                name        = f'LOS_TRG_THR_HI[{i}]',
                description = 'Trigger Threshold 16-bit Threshold Value',
                offset      = ((0x2F+(2*i)) << 2),
                bitSize     = 8,
                mode        = 'RW',
                hidden      = simpleDisplay,
            )

        for i in range(4):
            self.MyLinkVariable(
                name        = f'LOS_CLR_THR_LO[{i}]',
                description = 'Clear Threshold 16-bit Threshold Value',
                offset      = ((0x36+(2*i)) << 2),
                bitSize     = 8,
                mode        = 'RW',
                hidden      = simpleDisplay,
            )

            self.MyLinkVariable(
                name        = f'LOS_CLR_THR_HI[{i}]',
                description = 'Clear Threshold 16-bit Threshold Value',
                offset      = ((0x37+(2*i)) << 2),
                bitSize     = 8,
                mode        = 'RW',
                hidden      = simpleDisplay,
            )

        self.MyLinkVariable(
            name        = 'OOF_EN',
            description = '1 to enable, 0 to disable',
            offset      = (0x3F << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'FAST_OOF_EN',
            description = '1 to enable, 0 to disable',
            offset      = (0x3F << 2),
            bitSize     = 4,
            bitOffset   = 4,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'OOF_REF_SEL',
            description = 'OOF Reference Select',
            offset      = (0x40 << 2),
            bitSize     = 3,
            mode        = 'RO',
            hidden      = simpleDisplay,
        )

        for i in range(4):
            self.MyLinkVariable(
                name        = f'OOF_DIV_SEL[{i}]',
                description = 'Sets a divider for the OOF circuitry for each input clock 0,1,2,3. The divider value is 2OOFx_DIV_SEL. CBPro sets these dividers.',
                offset      = ((0x41+i) << 2),
                bitSize     = 5,
                mode        = 'RW',
                hidden      = simpleDisplay,
            )

        self.MyLinkVariable(
            name        = 'OOFXO_DIV_SEL',
            description = 'Sets a divider for the OOF circuitry for each input clock 0,1,2,3. The divider value is 2OOFx_DIV_SEL. CBPro sets these dividers.',
            offset      = (0x45 << 2),
            bitSize     = 5,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        for i in range(4):
            self.MyLinkVariable(
                name        = f'OOF_SET_THR[{i}]',
                description = 'OOF Set threshold. Range is up to 500 ppm in steps of 1/16 ppm.',
                offset      = ((0x46+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
                hidden      = simpleDisplay,
            )

        for i in range(4):
            self.MyLinkVariable(
                name        = f'OOF_CLR_THR[{i}]',
                description = 'OOF Clear threshold. Range is up to 500 ppm in steps of 1/16 ppm.',
                offset      = ((0x4A+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
                hidden      = simpleDisplay,
            )

        self.MyLinkVariable(
            name        = 'OOF_DETWIN_SEL[0]',
            description = 'Values calculated by CBPro.',
            offset      = (0x4E << 2),
            bitSize     = 3,
            bitOffset   = 0,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'OOF_DETWIN_SEL[1]',
            description = 'Values calculated by CBPro.',
            offset      = (0x4E << 2),
            bitSize     = 3,
            bitOffset   = 4,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'OOF_DETWIN_SEL[2]',
            description = 'Values calculated by CBPro.',
            offset      = (0x4F << 2),
            bitSize     = 3,
            bitOffset   = 0,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'OOF_DETWIN_SEL[3]',
            description = 'Values calculated by CBPro.',
            offset      = (0x4F << 2),
            bitSize     = 3,
            bitOffset   = 4,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'OOF_ON_LOS',
            description = 'Values set by CBPro',
            offset      = (0x50 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        for i in range(4):
            self.MyLinkVariable(
                name        = f'FAST_OOF_SET_THR[{i}]',
                description = '(1+ value) x 1000 ppm',
                offset      = ((0x51+i) << 2),
                bitSize     = 4,
                mode        = 'RW',
                hidden      = simpleDisplay,
            )

        for i in range(4):
            self.MyLinkVariable(
                name        = f'FAST_OOF_CLR_THR[{i}]',
                description = '(1+ value) x 1000 ppm',
                offset      = ((0x55+i) << 2),
                bitSize     = 4,
                mode        = 'RW',
                hidden      = simpleDisplay,
            )

        for i in range(4):
            self.MyLinkVariable(
                name        = f'FAST_OOF_DETWIN_SEL[{i}]',
                description = 'Values calculated by CBPro.',
                offset      = (0x59 << 2),
                bitSize     = 2,
                bitOffset   = (2*i),
                mode        = 'RW',
                hidden      = simpleDisplay,
            )

        for i in range(4):
            self.MyLinkVariable(
                name        = f'OOF0_RATIO_REF[{i}]',
                description = 'Values calculated by CBPro.',
                offset      = ((0x5A+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
                hidden      = simpleDisplay,
            )

        for i in range(4):
            self.MyLinkVariable(
                name        = f'OOF1_RATIO_REF[{i}]',
                description = 'Values calculated by CBPro.',
                offset      = ((0x5E+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
                hidden      = simpleDisplay,
            )

        for i in range(4):
            self.MyLinkVariable(
                name        = f'OOF2_RATIO_REF[{i}]',
                description = 'Values calculated by CBPro.',
                offset      = ((0x62+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
                hidden      = simpleDisplay,
            )

        for i in range(4):
            self.MyLinkVariable(
                name        = f'OOF3_RATIO_REF[{i}]',
                description = 'Values calculated by CBPro.',
                offset      = ((0x66+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
                hidden      = simpleDisplay,
            )

        self.MyLinkVariable(
            name        = 'LOL_FST_EN',
            description = 'Enables fast detection of LOL. A large input frequency error will quickly assert LOL when this is enabled.',
            offset      = (0x92 << 2),
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'LOL_FST_DETWIN_SEL',
            description = 'Values calculated by CBPro',
            offset      = (0x93 << 2),
            bitSize     = 4,
            bitOffset   = 4,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'LOL_FST_VALWIN_SEL',
            description = 'Values calculated by CBPro',
            offset      = (0x95 << 2),
            bitSize     = 2,
            bitOffset   = 2,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'LOL_FST_SET_THR_SEL',
            description = 'Values calculated by CBPro',
            offset      = (0x96 << 2),
            bitSize     = 4,
            bitOffset   = 4,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'LOL_FST_CLR_THR_SEL',
            description = 'Values calculated by CBPro',
            offset      = (0x98 << 2),
            bitSize     = 4,
            bitOffset   = 4,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'LOL_SLOW_EN_PLL',
            description = '1 to enable LOL; 0 to disable LOL.',
            offset      = (0x9A << 2),
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'LOL_SLW_DETWIN_SEL',
            description = '1 to enable LOL; 0 to disable LOL.',
            offset      = (0x9B << 2),
            bitSize     = 4,
            bitOffset   = 4,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'LOL_SLW_VALWIN_SEL',
            description = 'Values calculated by CBPro.',
            offset      = (0x9D << 2),
            bitSize     = 2,
            bitOffset   = 2,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'LOL_SLW_SET_THR',
            description = 'Configures the loss of lock set thresholds',
            offset      = (0x9E << 2),
            bitSize     = 4,
            bitOffset   = 4,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'LOL_SLW_CLR_THR',
            description = 'Configures the loss of lock set thresholds.',
            offset      = (0xA0 << 2),
            bitSize     = 4,
            bitOffset   = 4,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'LOL_TIMER_EN',
            description = '0 to disable, 1 to enable',
            offset      = (0xA2 << 2),
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        for i in range(4):
            self.MyLinkVariable(
                name        = f'LOL_CLR_DELAY_DIV256[{i}]',
                description = 'Set by CBPro.',
                offset      = ((0xA9+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
                hidden      = simpleDisplay,
            )

        self.MyLinkVariable(
            name        = 'ACTIVE_NVM_BANK',
            description = 'Read-only field indicating number of user bank writes carried out so far.',
            offset      = (0xE2 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'NVM_WRITE',
            description = 'Write 0xC7 to initiate an NVM bank burn.',
            offset      = (0xE3 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name         = "NVM_READ_BANK",
            description  = "When set, this bit will read the NVM down into the volatile memory.",
            offset       = (0xE4 << 2),
            bitSize      = 1,
            bitOffset    = 0,
            mode        = 'WO',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'FASTLOCK_EXTEND_EN',
            description = 'Extend Fastlock bandwidth period past LOL Clear, 0: Do not extend Fastlock period, 1: Extend Fastlock period (default)',
            offset      = (0xE5 << 2),
            bitSize     = 1,
            bitOffset   = 5,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        for i in range(4):
            self.MyLinkVariable(
                name        = f'FASTLOCK_EXTEND[{i}]',
                description = 'Set by CBPro.',
                offset      = ((0xEA+i) << 2),
                bitSize     = 8,
                mode        = 'RW',
                hidden      = simpleDisplay,
            )

        self.MyLinkVariable(
            name        = 'REG_0xF7_INTR',
            description = 'Set by CBPro.',
            offset      = (0xF6 << 2),
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'REG_0xF8_INTR',
            description = 'Set by CBPro.',
            offset      = (0xF6 << 2),
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RW',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'REG_0xF9_INTR',
            description = 'Set by CBPro.',
            offset      = (0xF6 << 2),
            bitSize     = 1,
            bitOffset   = 2,
            mode        = 'RO',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'SYSINCAL_INTR',
            description = 'Set by CBPro.',
            offset      = (0xF7 << 2),
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RO',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'LOSXAXB_INTR',
            description = 'Set by CBPro.',
            offset      = (0xF7 << 2),
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RO',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'LOSREF_INTR',
            description = 'Set by CBPro.',
            offset      = (0xF7 << 2),
            bitSize     = 1,
            bitOffset   = 2,
            mode        = 'RO',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'LOSVCO_INTR',
            description = 'Set by CBPro.',
            offset      = (0xF7 << 2),
            bitSize     = 1,
            bitOffset   = 4,
            mode        = 'RO',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'SMBUS_TIME_OUT_INTR',
            description = 'Set by CBPro.',
            offset      = (0xF7 << 2),
            bitSize     = 1,
            bitOffset   = 5,
            mode        = 'RO',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'LOS_INTR',
            description = 'Set by CBPro.',
            offset      = (0xF8 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RO',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'OOF_INTR',
            description = 'Set by CBPro.',
            offset      = (0xF8 << 2),
            bitSize     = 4,
            bitOffset   = 4,
            mode        = 'RO',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'LOL_INTR',
            description = 'Set by CBPro.',
            offset      = (0xF9 << 2),
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RO',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'HOLD_INTR',
            description = 'Set by CBPro.',
            offset      = (0xF9 << 2),
            bitSize     = 1,
            bitOffset   = 5,
            mode        = 'RO',
            hidden      = simpleDisplay,
        )

        self.MyLinkVariable(
            name        = 'DEVICE_READY',
            description = 'Ready Only byte to indicate device is ready. When read data is 0x0F one can safely read/write registers. This register is repeated on every page therefore a page write is not ever required to read the DEVICE_READY status.',
            offset      = (0xFE << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            hidden      = simpleDisplay,
        )


class Si5345Page5(Si5345PageBase):
    def __init__(self,
            name         = "Page5",
            description  = "M divider, BW, holdover, input switch, FINC/DEC",
            simpleDisplay = True,
            liteVersion   = True,
            **kwargs):
        super().__init__(name=name, description=description, **kwargs)

        self.MyLinkVariable(
            name        = "BW_UPDATE_PLL",
            description = "Must be set to 1 to update the BWx_PLL and FAST_BWx_PLL parameters",
            offset      = (0x14 << 2),
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'WO',
            hidden      = simpleDisplay,
        )
