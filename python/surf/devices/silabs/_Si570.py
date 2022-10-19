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

class Si570(pr.Device):
    def __init__(self, factory_freq, **kwargs):
        super().__init__(**kwargs)
        self.factory_freq = factory_freq

        ADDR_SIZE = 4

        for i in range(7, 13):
            self.add(pr.RemoteVariable(
                name = f'Config[{i}]',
                description = 'Entire configuration space as an array of registers',
                offset = i * ADDR_SIZE,
                bitOffset = 0,
                bitSize = 8,
                hidden = True,
                overlapEn = True))

        # Extract N1 register value
        def n1_raw_get(read):
            high = self.Config[7].get(read=read)
            low = self.Config[8].get(read=read)
            return ((high & 0x1f) << 2) | ((low & 0xc0) >> 6)

        def n1_raw_set(value, write):
            high = self.Config[7].value() & 0xe0
            low = self.Config[8].value() & 0x1f

            high |= (value & 0b01111100) >> 2
            low |= (value & 0x3) << 6

            self.Config[7].set(high, write=False)
            self.Config[8].set(low, write=False)
            self.writeAndVerifyBlocks()

        self.add(pr.LinkVariable(
            name = 'N1_RAW',
            dependencies = [self.Config[7], self.Config[8]],
            hidden = True,
            linkedGet = n1_raw_get,
            linkedSet = n1_raw_set))

        self.add(pr.LinkVariable(
            name = 'N1',
            description = """
            Sets the value for CLKOUT output divider.
            Can be 1 or any even number up to 128.
            Value will be formatted for register as described on datasheet page 23""",
            dependencies = [self.N1_RAW],
            linkedGet = lambda read: self.N1_RAW.get(read=read) + 1,
            linkedSet = lambda value, write: self.N1_RAW.set(value-1, write=write)))

        # Enum for HS_DIV
        self.add(pr.RemoteVariable(
            name = 'HS_DIV',
            description = 'Sets value for high speed divider that takes the DCO output fOSC as its clock input',
            overlapEn = True,
            offset = 7 * ADDR_SIZE,
            bitSize = 3,
            bitOffset = 5,
            enum = {
                0: '4',
                1: '5',
                2: '6',
                3: '7',
                5: '9',
                7: '11'}))

        # Map enum to link variable for setting as int
        self.add(pr.LinkVariable(
            name = 'HS_DIV_INT',
            description = 'Sets value for high speed divider that takes the DCO output fOSC as its clock input',
            hidden = True,
            dependencies = [self.HS_DIV],
            linkedGet = lambda read: int(self.HS_DIV.getDisp(read=read)),
            linkedSet = lambda value, write: self.HS_DIV.setDisp(str(value))))

        # Extract RFREQ from registers
        def rfreq_raw_get(read):
            ret = 0
            for i in range(8, 13):
                ret = ret << 8 | self.Config[i].get(read=read)

            ret &= 0x1fffffffff
            return ret

        def rfreq_raw_set(value, write):
            tmp = value
            for i in reversed(range(8, 13)):
                if i == 8:
                    old = self.Config[i].get(read=False)
                    tmp = (tmp & 0x1f) | (old & 0xc0)
                self.Config[i].set(tmp&0xFF, write=write)
                tmp = tmp >> 8

        self.add(pr.LinkVariable(
            name = 'RFREQ_RAW',
            description = 'Frequency control input to DCO',
            disp = '0x{:x}',
            hidden = True,
            dependencies = [self.Config[x] for x in range(8,13)],
            linkedGet = rfreq_raw_get,
            linkedSet = rfreq_raw_set))


        self.add(pr.LinkVariable(
            name = 'RFREQ',
            description = 'Frequency control input to DCO, formatted from fixed point',
            dependencies = [self.RFREQ_RAW],
            linkedGet = lambda read: self.RFREQ_RAW.get(read=read) / 2**28,
            linkedSet = lambda value, write: self.RFREQ_RAW.set(int(value*2**28), write=write)))

        self.add(pr.RemoteCommand(
            name = 'RST_REG',
            description = """
            Reset of all internal logic. Output tristated during reset.
            Automatically returns to 0 after reset completion.
            Interrupts I2C state machine. Not recommended to use""",
            offset = 135 * ADDR_SIZE,
            bitOffset = 7,
            bitSize = 1,
            hidden = True,
            function = pr.Command.touchOne))

        self.add(pr.RemoteCommand(
            name = 'NewFreq',
            description = 'Alerts the DSPLL that a new frequency configuration has been applied',
            offset = 135 * ADDR_SIZE,
            bitOffset = 6,
            bitSize = 1,
            hidden = True,
            function = pr.Command.touchOne))

        self.add(pr.RemoteVariable(
            name = 'FreezeM',
            description = 'Prevents interim frequency changes when writing RFREQ registers',
            offset = 135 * ADDR_SIZE,
            bitOffset = 5,
            bitSize = 1,
            hidden = True,
            base = pr.UInt))

        self.add(pr.RemoteCommand(
            name = 'RECALL',
            description = """
            Write NVM bits into RAM.
            Effectively resets the chip without interrupting I2C""",
            offset = 135 * ADDR_SIZE,
            bitOffset = 0,
            bitSize = 1,
            function = pr.Command.touchOne))

        self.add(pr.RemoteVariable(
            name = 'FreezeDCO',
            description = 'Freezes the DSPLL so the frequency configuration can be modified',
            hidden = True,
            offset = 137 * ADDR_SIZE,
            bitSize = 1,
            bitOffset = 4))

        def get_fxtal(read):
            return 114.2855151335625
            rfreq =  self.RFREQ.get(read)
            if rfreq == 0:
                return 0.0
            else:
                return factory_freq * self.HS_DIV_INT.get(read=read) * self.N1.get(read=read) / rfreq

        self.add(pr.LinkVariable(
            name = 'fxtal',
            description = 'Calculated fxtal frequency as described in the datasheet',
            units = 'MHz',
            dependencies = [self.RFREQ, self.HS_DIV_INT, self.N1],
            linkedGet = get_fxtal))


        n1_array = [1] + [x for x in range(2, 2**7, 2)]
        hs_div_array = [11, 9, 7, 6, 5, 4]

        def find_params(f1):
            # want low N1 and high HS_DIV
            for n1 in n1_array:
                for hs_div in hs_div_array:
                    fdco = f1 * hs_div * n1
                    if 4850 < fdco < 5670:
                        return n1, hs_div

        def set_freq(value, write):
            if write is False:
                return

            with self.root.updateGroup():
                n1, hs_div = find_params(value)
                fdco = value * hs_div * n1
                rfreq = fdco / self.fxtal.get(read=True)

                # Freeze
                self.FreezeDCO.set(1, write=True)

                # Write new config
                self.N1.set(n1, write=False)
                self.HS_DIV_INT.set(hs_div, write=False)
                self.RFREQ.set(rfreq, write=False)
                self.writeAndVerifyBlocks()

                # Unfreeze
                self.FreezeDCO.set(0, write=True)

                # NewFreq
                self.NewFreq()

        def get_freq(read):
            n1 = self.N1.get(read=read)
            hs_div = self.HS_DIV_INT.get(read=read)
            rfreq = self.RFREQ.get(read=read)
            fxtal = self.fxtal.get(read=read)

            return (fxtal * rfreq)/(hs_div * n1)


        self.add(pr.LinkVariable(
            name = 'Frequency',
            description = """
            Set the frequency in MHz.
            Automatically calculates all register values and performs the frequency update procedure described in the datasheet""",
            units = 'MHz',
            dependencies = [self.N1, self.HS_DIV_INT, self.RFREQ, self.fxtal],
            linkedGet = get_freq,
            linkedSet = set_freq))
