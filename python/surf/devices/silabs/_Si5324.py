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
import click
import fnmatch

class Si5324(pr.Device):
    def __init__(self,**kwargs):
        super().__init__(**kwargs)

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
            bulkOpEn     = True,
            overlapEn    = True,
            verify       = True,
            hidden       = True,
            base         = pr.UInt,
            mode         = "RW",
        ))

        self.add(pr.LocalVariable(
            name         = "TxtFilePath",
            description  = "Used if command's argument is empty",
            mode         = "RW",
            value        = "",
        ))

        ##############################
        # Commands
        ##############################
        @self.command(value='',description="Load the .txt from DSPLLsim",)
        def LoadTxtFile(arg):
            # Check if non-empty argument
            if (arg != ""):
                path = arg
            else:
                # Use the variable path instead
                path = self.TxtFilePath.get()

            # Check for .txt file
            if fnmatch.fnmatch(path, '*.txt'):
                click.secho( f'{self.path}.LoadTxtFile(): {path}', fg='green')
            else:
                click.secho( f'{self.path}.LoadTxtFile(): {path} is not .txt', fg='red')
                return

            # Open the .txt file
            fh = open(path,'r')
            all_lines = fh.readlines()
            fh.close()

            # Process the read file
            for line in all_lines:
                if line.find('#') < 0:
                    addr,data = line.replace('h','').replace(',','').split()
                    self._setValue(
                        offset = int(addr)<<2,
                        data   = int(data,16),
                    )

            # Update local RemoteVariables and verify conflagration
            self.readBlocks(recurse=True)
            self.checkBlocks(recurse=True)

        ###########################
        #      Register[0]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'FREE_RUN',
            description = 'Internal to the device, route XA/XB to CKIN2.',
            offset      = (0 << 2),
            bitSize     = 1,
            bitOffset   = 6,
            mode        = 'RW',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'CKOUT_ALWAYS_ON',
            description = 'This will bypass the SQ_ICAL function',
            offset      = (0 << 2),
            bitSize     = 1,
            bitOffset   = 5,
            mode        = 'RW',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'BYPASS_REG',
            description = 'This bit enables or disables the PLL bypass mode',
            offset      = (0 << 2),
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[1]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'CK_PRIOR2',
            description = 'Selects which of the input clocks will be 2nd priority in the autoselection state machine.',
            offset      = (1 << 2),
            bitSize     = 2,
            bitOffset   = 2,
            mode        = 'RW',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'CK_PRIOR1',
            description = 'Selects which of the input clocks will be 1st priority in the autoselection state machine.',
            offset      = (1 << 2),
            bitSize     = 2,
            bitOffset   = 0,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[2]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'BWSEL_REG',
            description = 'Selects nominal f3dB bandwidth for PLL.',
            offset      = (2 << 2),
            bitSize     = 4,
            bitOffset   = 4,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[3]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'CKSEL_REG',
            description = 'If the device is operating in register-based manual clock selection mode',
            offset      = (3 << 2),
            bitSize     = 2,
            bitOffset   = 6,
            mode        = 'RW',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'DHOLD',
            description = 'Forces the part into digital hold',
            offset      = (3 << 2),
            bitSize     = 1,
            bitOffset   = 5,
            mode        = 'RW',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'SQ_ICAL',
            description = 'This bit determines if the output clocks will remain enabled or be squelched during an internal calibration',
            offset      = (3 << 2),
            bitSize     = 1,
            bitOffset   = 4,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[4]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'AUTOSEL_REG',
            description = 'Selects method of input clock selection to be used.',
            offset      = (4 << 2),
            bitSize     = 2,
            bitOffset   = 6,
            mode        = 'RW',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'HIST_DEL',
            description = 'Selects amount of delay to be used in generating the history information used for Digital Hold',
            offset      = (4 << 2),
            bitSize     = 5,
            bitOffset   = 0,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[5]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'ICMOS',
            description = 'When the output buffer is set to CMOS mode, these bits determine the output buffer drive strength',
            offset      = (5 << 2),
            bitSize     = 2,
            bitOffset   = 6,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[6]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'SFOUT2_REG',
            description = 'Controls output signal format and disable for CKOUT2 output buffer',
            offset      = (6 << 2),
            bitSize     = 3,
            bitOffset   = 3,
            mode        = 'RW',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'SFOUT1_REG',
            description = 'Controls output signal format and disable for CKOUT1 output buffer',
            offset      = (6 << 2),
            bitSize     = 3,
            bitOffset   = 0,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[7]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'FOSREFSEL',
            description = 'Selects which input clock is used as the reference frequency',
            offset      = (7 << 2),
            bitSize     = 3,
            bitOffset   = 0,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[8]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'HLOG_2',
            offset      = (8 << 2),
            bitSize     = 2,
            bitOffset   = 6,
            mode        = 'RW',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'HLOG_1',
            offset      = (8 << 2),
            bitSize     = 2,
            bitOffset   = 4,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[9]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'HIST_AVG',
            description = 'Selects amount of averaging time to be used in generating the history information used for Digital Hold',
            offset      = (9 << 2),
            bitSize     = 5,
            bitOffset   = 3,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[10]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'DSBL2_REG',
            description = 'This bit controls the powerdown of the CKOUT2 output buffer',
            offset      = (10 << 2),
            bitSize     = 1,
            bitOffset   = 3,
            mode        = 'RW',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'DSBL1_REG',
            description = 'This bit controls the powerdown of the CKOUT1 output buffer',
            offset      = (10 << 2),
            bitSize     = 1,
            bitOffset   = 2,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[11]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'PD_CK2',
            description = 'This bit controls the powerdown of the CKIN2 input buffer',
            offset      = (11 << 2),
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RW',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'PD_CK1',
            description = 'This bit controls the powerdown of the CKIN1 input buffer',
            offset      = (11 << 2),
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[19]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'FOS_EN',
            description = 'Frequency Offset Enable globally disables FOS',
            offset      = (19 << 2),
            bitSize     = 1,
            bitOffset   = 7,
            mode        = 'RW',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'FOS_THR',
            description = 'Frequency Offset at which FOS is declared',
            offset      = (19 << 2),
            bitSize     = 2,
            bitOffset   = 5,
            mode        = 'RW',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'VALTIME',
            description = 'Sets amount of time for input clock to be valid before the associated alarm is removed',
            offset      = (19 << 2),
            bitSize     = 2,
            bitOffset   = 3,
            mode        = 'RW',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'LOCKT',
            description = 'Sets retrigger interval for one shot monitoring phase detector output',
            offset      = (19 << 2),
            bitSize     = 3,
            bitOffset   = 0,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[20]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'CK2_BAD_PIN',
            description = 'The CK2_BAD status can be reflected on the C2B output pin',
            offset      = (20 << 2),
            bitSize     = 1,
            bitOffset   = 3,
            mode        = 'RW',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'CK1_BAD_PIN',
            description = 'The CK1_BAD status can be reflected on the C1B output pin',
            offset      = (20 << 2),
            bitSize     = 1,
            bitOffset   = 2,
            mode        = 'RW',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'LOL_PIN',
            description = 'The LOL_INT status bit can be reflected on the LOL output pin',
            offset      = (20 << 2),
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RW',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'INT_PIN',
            description = 'Reflects the interrupt status on the INT_C1B output pin',
            offset      = (20 << 2),
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[21]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'CK1_ACTV_PIN',
            offset      = (21 << 2),
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RW',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'CKSEL_PIN',
            offset      = (21 << 2),
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[22]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'CK_ACTV_POL',
            description = 'Sets the active polarity for the CS_CA signals when reflected on an output pin',
            offset      = (22 << 2),
            bitSize     = 1,
            bitOffset   = 3,
            mode        = 'RW',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'CK_BAD_POL',
            description = 'Sets the active polarity for the INT_C1B and C2B signals when reflected on output pin',
            offset      = (22 << 2),
            bitSize     = 1,
            bitOffset   = 2,
            mode        = 'RW',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'LOL_POL',
            description = 'Sets the active polarity for the LOL status when reflected on an output pin',
            offset      = (22 << 2),
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RW',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'INT_POL',
            description = 'Sets the active polarity for the interrupt status when reflected on the INT_C1B output pin',
            offset      = (22 << 2),
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[23]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'LOS2_MSK',
            description = 'Determines if a LOS on CKIN2 (LOS2_FLG) is used in the generation of an interrupt',
            offset      = (23 << 2),
            bitSize     = 1,
            bitOffset   = 2,
            mode        = 'RW',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'LOS1_MSK',
            description = 'Determines if a LOS on CKIN1 (LOS1_FLG) is used in the generation of an interrupt',
            offset      = (23 << 2),
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RW',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'LOSX_MSK',
            description = 'Determines if a LOS on XA/XB(LOSX_FLG) is used in the generation of an interrupt',
            offset      = (23 << 2),
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[24]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'FOS2_MSK',
            description = 'Determines if the FOS2_FLG is used to in the generation of an interrupt',
            offset      = (24 << 2),
            bitSize     = 1,
            bitOffset   = 2,
            mode        = 'RW',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'FOS1_MSK',
            description = 'Determines if the FOS1_FLG is used in the generation of an interrupt',
            offset      = (24 << 2),
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RW',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'LOL_MSK',
            description = 'Determines if the LOL_FLG is used in the generation of an interrupt',
            offset      = (24 << 2),
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[25]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'N1_HS',
            description = 'Sets value for N1 high speed divider which drives NCn_LS (n = 1 to 2) low-speed divider',
            offset      = (25 << 2),
            bitSize     = 3,
            bitOffset   = 5,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[31]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'NC1_LS_19_16',
            description = 'Sets value for NC1 low-speed divider, which drives CKOUT1 output',
            offset      = (31 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[32]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'NC1_LS_15_8',
            description = 'Sets value for NC1 low-speed divider, which drives CKOUT1 output.',
            offset      = (32 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[33]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'NC1_LS_7_0',
            description = 'Sets value for NC1 low-speed divider, which drives CKOUT1 output.',
            offset      = (33 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[34]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'NC2_LS_19_16',
            description = 'Sets value for NC2 low-speed divider, which drives CKOUT2 output',
            offset      = (34 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[35]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'NC2_LS_15_8',
            description = 'Sets value for NC2 low-speed divider, which drives CKOUT2 output',
            offset      = (35 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[36]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'NC2_LS_7_0',
            description = 'Sets value for NC2 low-speed divider, which drives CKOUT2 output',
            offset      = (36 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[40]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'N2_HS',
            description = 'Sets value for N2 high speed divider which drives N2LS low-speed divider.',
            offset      = (40 << 2),
            bitSize     = 3,
            bitOffset   = 5,
            mode        = 'RW',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'N2_LS_19_16',
            description = 'Sets value for N2 low-speed divider, which drives phase detector.',
            offset      = (40 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[41]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'N2_LS_15_8',
            description = 'Sets value for N2 low-speed divider, which drives phase detector.',
            offset      = (41 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[42]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'N2_LS_7_0',
            description = 'Sets value for N2 low-speed divider, which drives phase detector.',
            offset      = (42 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[43]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'N31_18_16',
            description = 'Sets value for input divider for CKIN1',
            offset      = (43 << 2),
            bitSize     = 3,
            bitOffset   = 0,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[44]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'N31_15_8',
            description = 'Sets value for input divider for CKIN1',
            offset      = (44 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[45]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'N31_7_0',
            description = 'Sets value for input divider for CKIN1',
            offset      = (45 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[46]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'N32_18_16',
            description = 'Sets value for input divider for CKIN2',
            offset      = (46 << 2),
            bitSize     = 3,
            bitOffset   = 0,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[47]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'N32_15_8',
            description = 'Sets value for input divider for CKIN2',
            offset      = (47 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[48]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'N32_7_0',
            description = 'Sets value for input divider for CKIN2',
            offset      = (48 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[55]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'CLKIN2RATE',
            description = 'CKINn frequency selection for FOS alarm monitoring',
            offset      = (55 << 2),
            bitSize     = 3,
            bitOffset   = 3,
            mode        = 'RW',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'CLKIN1RATE',
            description = 'CKINn frequency selection for FOS alarm monitoring',
            offset      = (55 << 2),
            bitSize     = 3,
            bitOffset   = 0,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[128]
        ###########################
        self.add(pr.RemoteVariable(
            name         = 'CK2_ACTV_REG',
            description  = 'Indicates if CKIN2 is currently the active clock for the PLL input',
            offset       = (128 << 2),
            bitSize      = 1,
            bitOffset    = 1,
            mode         = 'RO',
            pollInterval = 1,
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'CK1_ACTV_REG',
            description  = 'Indicates if CKIN1 is currently the active clock for the PLL input',
            offset       = (128 << 2),
            bitSize      = 1,
            bitOffset    = 0,
            mode         = 'RO',
            pollInterval = 1,
            overlapEn    = True,
        ))

        ###########################
        #      Register[129]
        ###########################
        self.add(pr.RemoteVariable(
            name         = 'LOS2_INT',
            description  = 'Indicates the LOS status on CKIN2',
            offset       = (129 << 2),
            bitSize      = 1,
            bitOffset    = 2,
            mode         = 'RO',
            pollInterval = 1,
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'LOS1_INT',
            description  = 'Indicates the LOS status on CKIN1',
            offset       = (129 << 2),
            bitSize      = 1,
            bitOffset    = 1,
            mode         = 'RO',
            pollInterval = 1,
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'LOSX_INT',
            description  = 'Indicates the LOS status of the external reference on the XA/XB pins',
            offset       = (129 << 2),
            bitSize      = 1,
            bitOffset    = 0,
            mode         = 'RO',
            pollInterval = 1,
            overlapEn    = True,
        ))

        ###########################
        #      Register[130]
        ###########################
        self.add(pr.RemoteVariable(
            name         = 'DIGHOLDVALID',
            description  = 'Indicates if the digital hold circuit has enough samples of a valid clock to meet digital hold specifications',
            offset       = (130 << 2),
            bitSize      = 1,
            bitOffset    = 6,
            mode         = 'RO',
            pollInterval = 1,
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'FOS2_INT',
            description  = 'CKIN2 Frequency Offset Status',
            offset       = (130 << 2),
            bitSize      = 1,
            bitOffset    = 2,
            mode         = 'RO',
            pollInterval = 1,
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'FOS1_INT',
            description  = 'CKIN1 Frequency Offset Status',
            offset       = (130 << 2),
            bitSize      = 1,
            bitOffset    = 1,
            mode         = 'RO',
            pollInterval = 1,
            overlapEn    = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'LOL_INT',
            description  = 'PLL Loss of Lock Status',
            offset       = (130 << 2),
            bitSize      = 1,
            bitOffset    = 0,
            mode         = 'RO',
            pollInterval = 1,
            overlapEn    = True,
        ))

        ###########################
        #      Register[131]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'LOS2_FLG',
            description = 'CKIN2 Loss-of-Signal Flag',
            offset      = (131 << 2),
            bitSize     = 1,
            bitOffset   = 2,
            mode        = 'RW',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'LOS1_FLG',
            description = 'CKIN1 Loss-of-Signal Flag',
            offset      = (131 << 2),
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RW',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'LOSX_FLG',
            description = 'External Reference (signal on pins XA/XB) Loss-of-Signal Flag',
            offset      = (131 << 2),
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[132]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'FOS2_FLG',
            description = 'CLKIN_2 Frequency Offset Flag',
            offset      = (132 << 2),
            bitSize     = 1,
            bitOffset   = 3,
            mode        = 'RW',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'FOS1_FLG',
            description = 'CLKIN_1 Frequency Offset Flag',
            offset      = (132 << 2),
            bitSize     = 1,
            bitOffset   = 2,
            mode        = 'RW',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'LOL_FLG',
            description = 'PLL Loss of Lock Flag',
            offset      = (132 << 2),
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[134]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'PARTNUM_RO_11_4',
            description = 'Device ID',
            offset      = (134 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            overlapEn   = True,
        ))

        ###########################
        #      Register[135]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'PARTNUM_RO_3_0',
            description = 'Device ID',
            offset      = (135 << 2),
            bitSize     = 4,
            bitOffset   = 4,
            mode        = 'RO',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'REVID_RO',
            description = 'Indicates Revision Number of Device.',
            offset      = (135 << 2),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RO',
            overlapEn   = True,
        ))

        ###########################
        #      Register[136]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'RST_REG',
            description = 'Internal Reset (Same as Pin Reset)',
            offset      = (136 << 2),
            bitSize     = 1,
            bitOffset   = 7,
            mode        = 'RW',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'ICAL',
            description = 'Start an Internal Calibration Sequence',
            offset      = (136 << 2),
            bitSize     = 1,
            bitOffset   = 6,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[137]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'FASTLOCK',
            description = 'This bit must be set to 1 to enable FASTLOCK',
            offset      = (137 << 2),
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[138]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'LOS2_EN_1',
            description = 'Enable CKIN2 LOS Monitoring on the Specified Input',
            offset      = (138 << 2),
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RW',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'LOS1_EN_1',
            description = 'Enable CKIN1 LOS Monitoring on the Specified Input',
            offset      = (138 << 2),
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[139]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'LOS2_EN_0',
            description = 'Enable CKIN2 LOS Monitoring on the Specified Input',
            offset      = (139 << 2),
            bitSize     = 1,
            bitOffset   = 5,
            mode        = 'RW',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'LOS1_EN_0',
            description = 'Enable CKIN1 LOS Monitoring on the Specified Input',
            offset      = (139 << 2),
            bitSize     = 1,
            bitOffset   = 4,
            mode        = 'RW',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'FOS2_EN',
            description = 'Enables FOS on a Per Channel Basis',
            offset      = (139 << 2),
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RW',
            overlapEn   = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'FOS1_EN',
            description = 'Enables FOS on a Per Channel Basis',
            offset      = (139 << 2),
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[142]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'INDEPENDENTSKEW1',
            description = '8 bit field that represents a twos complement of the phase offset in terms of clocks from the high speed output divider',
            offset      = (142 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RW',
            overlapEn   = True,
        ))

        ###########################
        #      Register[143]
        ###########################
        self.add(pr.RemoteVariable(
            name        = 'INDEPENDENTSKEW2',
            description = '8 bit field that represents a twos complement of the phase offset in terms of clocks from the high speed output divider',
            offset      = (143 << 2),
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RW',
            overlapEn   = True,
        ))


        self.add(pr.LinkVariable(
            name         = 'Locked',
            description  = 'Inverse of LOL',
            mode         = 'RO',
            dependencies = [self.LOL_INT],
            linkedGet    = lambda: (False if self.LOL_INT.value() else True)
        ))

    def _setValue(self,offset,data):
        # Note: index is byte index (not word index)
        self.DataBlock.set(value=data,index=(offset%0x400)>>2)
