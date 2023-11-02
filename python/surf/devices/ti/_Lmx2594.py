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
import time

class Lmx2594(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        numRegs = 113
        self.add(pr.RemoteVariable(
            name         = "DataBlock",
            description  = "",
            offset       = 0,
            bitSize      = 32 * numRegs,
            bitOffset    = 0,
            numValues    = numRegs,
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

        def addLinkVariable(name, description, offset, bitSize, mode, bitOffset=0, pollInterval=0, value=None, hidden=False):

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

        ##############################
        # Link Variables
        ##############################

        addLinkVariable(
            name        = 'RAMP_EN',
            description = 'frequency ramping mode',
            offset      = (0 << 2),
            bitOffset   = 15,
            bitSize     = 1,
            mode        = 'RW',
        )

        addLinkVariable(
            name        = 'VCO_PHASE_SYNC',
            description = 'phase SYNC mode',
            offset      = (0 << 2),
            bitOffset   = 14,
            bitSize     = 1,
            mode        = 'RW',
        )

        addLinkVariable(
            name        = 'OUT_MUTE',
            description = 'Mute the outputs when the VCO is calibrating',
            offset      = (0 << 2),
            bitOffset   = 9,
            bitSize     = 1,
            mode        = 'RW',
        )

        addLinkVariable(
            name        = 'FCAL_EN',
            description = 'Enable the VCO frequency calibration',
            offset      = (0 << 2),
            bitOffset   = 3,
            bitSize     = 1,
            mode        = 'RW',
        )

        addLinkVariable(
            name        = 'MUXOUT_LD_SEL',
            description = 'Selects the state of the function of the MUXout pin',
            offset      = (0 << 2),
            bitOffset   = 2,
            bitSize     = 1,
            mode        = 'RW',
        )

        addLinkVariable(
            name        = 'RESET',
            description = 'Resets and holds all state machines and registers to default value',
            offset      = (0 << 2),
            bitOffset   = 1,
            bitSize     = 1,
            mode        = 'RW',
        )

        addLinkVariable(
            name        = 'POWERDOWN',
            description = 'Powers down entire device',
            offset      = (0 << 2),
            bitOffset   = 0,
            bitSize     = 1,
            mode        = 'RW',
        )

        addLinkVariable(
            name        = 'OUTB_PD',
            description = 'Powers down output B',
            offset      = (44 << 2),
            bitOffset   = 7,
            bitSize     = 1,
            mode        = 'RW',
        )

        addLinkVariable(
            name        = 'OUTA_PD',
            description = 'Powers down output A',
            offset      = (44 << 2),
            bitOffset   = 6,
            bitSize     = 1,
            mode        = 'RW',
        )

        addLinkVariable(
            name        = 'SYSREF_DIV_PRE',
            description = 'Pre-divider for SYSREF',
            offset      = (71 << 2),
            bitOffset   = 5,
            bitSize     = 3,
            mode        = 'RW',
        )

        addLinkVariable(
            name        = 'SYSREF_PULSE',
            description = 'Enable pulser mode in master mode',
            offset      = (71 << 2),
            bitOffset   = 4,
            bitSize     = 1,
            mode        = 'RW',
        )

        addLinkVariable(
            name        = 'SYSREF_EN',
            description = 'Enable SYSREF',
            offset      = (71 << 2),
            bitOffset   = 3,
            bitSize     = 1,
            mode        = 'RW',
        )

        addLinkVariable(
            name        = 'SYSREF_REPEAT',
            description = 'Enable repeater mode',
            offset      = (71 << 2),
            bitOffset   = 2,
            bitSize     = 1,
            mode        = 'RW',
        )

        addLinkVariable(
            name        = 'SYSREF_DIV',
            description = 'Divider for the SYSREF',
            offset      = (72 << 2),
            bitOffset   = 0,
            bitSize     = 11,
            mode        = 'RW',
        )

        addLinkVariable(
            name        = 'SYSREF_PULSE_CNT',
            description = 'Number of pulses in pulse mode in master mode',
            offset      = (74 << 2),
            bitOffset   = 12,
            bitSize     = 4,
            mode        = 'RW',
        )

        addLinkVariable(
            name        = 'rb_LD_VTUNE',
            description = 'Readback of Vtune lock detect',
            offset      = (110 << 2),
            bitOffset   = 9,
            bitSize     = 2,
            mode        = 'RO',
        )

        addLinkVariable(
            name        = 'rb_VCO_SEL',
            description = 'Reads back the actual VCO that the calibration has selected.',
            offset      = (110 << 2),
            bitOffset   = 5,
            bitSize     = 3,
            mode        = 'RO',
        )

        addLinkVariable(
            name        = 'rb_VCO_CAPCTRL',
            description = 'Reads back the actual CAPCTRL capcode value the VCO calibration has chosen.',
            offset      = (111 << 2),
            bitOffset   = 0,
            bitSize     = 8,
            mode        = 'RO',
        )

        addLinkVariable(
            name        = 'rb_VCO_DACISET',
            description = 'Reads back the actual amplitude (DACISET) value that the VCO calibration has chosen.',
            offset      = (112 << 2),
            bitOffset   = 0,
            bitSize     = 9,
            mode        = 'RO',
        )

        @self.command(description='Load the CodeLoader .HEX file',value='',)
        def LoadCodeLoaderHexFile(arg):

            self.DataBlock.set(value=0x2410,index=0, write=True) # MUXOUT_LD_SEL=readback

            ##################################################################
            # For the most reliable programming, TI recommends this procedure:
            ##################################################################

            # 1. Apply power to device.

            # 2. Program RESET = 1 to reset registers.
            self.DataBlock.set(value=0x2412, index=0, write=True)

            # 3. Program RESET = 0 to remove reset.
            self.DataBlock.set(value=0x2410, index=0, write=True)

            # 4. Program registers as shown in the register map in REVERSE order from highest to lowest.
            with open(arg, 'r') as ifd:
                # Note: HEX file dumped in REVERSE order
                for i, line in enumerate(ifd):
                    s = str.split(line)
                    addr = int(s[0][1:], 0)
                    data = int("0x" + s[1][-4:], 0)
                    # print( f'addr={addr}, data={hex(data)}' )
                    self.DataBlock.set(value=data, index=addr, write=True)

            # 5. Wait 10 ms.
            time.sleep(0.1)

            # 6. Program register R0 one additional time with FCAL_EN = 1 to ensure that the VCO calibration runs from a stable state.
            self.DataBlock.set(value=data&0xFFFB, index=addr, write=True)
            time.sleep(0.1)
