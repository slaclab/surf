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
                offset = i * ADDR_SIZE,
                bitOffset = 0,
                bitSize = 8,
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
            linkedGet = n1_raw_get,
            linkedSet = n1_raw_set))

        # Actual N1 multiplier is x2 what is written in register
        def read_n1(read):
            return self.N1_RAW.get(read=read) + 1

        self.add(pr.LinkVariable(
            name = 'N1',
            dependencies = [self.N1_RAW],
            linkedGet = read_n1,
            linkedSet = lambda value, write: self.N1_RAW.set(value-1, write=write)))

        # Enum for HS_DIV
        self.add(pr.RemoteVariable(
            name = 'HS_DIV_RAW',
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
            name = 'HS_DIV',
            dependencies = [self.HS_DIV_RAW],
            linkedGet = lambda read: int(self.HS_DIV_RAW.getDisp(read=read)),
            linkedSet = lambda value, write: self.HS_DIV_RAW.setDisp(str(value))))

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
            #value = 0x2EBB04CE0,
            disp = '0x{:x}',
            dependencies = [self.Config[x] for x in range(8,13)],
            linkedGet = rfreq_raw_get,
            linkedSet = rfreq_raw_set))


        self.add(pr.LinkVariable(
            name = 'RFREQ',
            dependencies = [self.RFREQ_RAW],
            linkedGet = lambda read: self.RFREQ_RAW.get(read=read) / 2**28,
            linkedSet = lambda value, write: self.RFREQ_RAW.set(int(value*2**28), write=write)))

#         self.add(pr.RemoteCommand(
#             name = 'RST_REG',
#             offset = 135 * ADDR_SIZE,
#             bitOffset = 7,
#             bitSize = 1,
#             function = pr.Command.toggle))

        self.add(pr.RemoteCommand(
            name = 'NewFreq',
            offset = 135 * ADDR_SIZE,
            bitOffset = 6,
            bitSize = 1,
            function = pr.Command.touchOne))

#         self.add(pr.RemoteVariable(
#             name = 'FreezeM',
#             offset = 135 * ADDR_SIZE,
#             bitOffset = 5,
#             bitSize = 1,
#             base = pr.UInt))

        self.add(pr.RemoteCommand(
            name = 'RECALL',
            offset = 135 * ADDR_SIZE,
            bitOffset = 0,
            bitSize = 1,
            function = pr.Command.touchOne))

        self.add(pr.RemoteVariable(
            name = 'FreezeDCO',
            offset = 137 * ADDR_SIZE,
            bitSize = 1,
            bitOffset = 4))

        def get_fxtal(read):
            return 114.2855151335625
            rfreq =  self.RFREQ.get(read)
            if rfreq == 0:
                return 0.0
            else:
                return factory_freq * self.HS_DIV.get(read=read) * self.N1.get(read=read) / rfreq

        self.add(pr.LinkVariable(
            name = 'fxtal',
            dependencies = [self.RFREQ, self.HS_DIV, self.N1],
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

                #print(f'Si570 setting new params, {n1=}, {hs_div=}, {rfreq=}, {fdco=}')

                # Freeze
                self.FreezeDCO.set(1, write=True)

                # Write new config
                self.N1.set(n1, write=False)
                self.HS_DIV.set(hs_div, write=False)
                self.RFREQ.set(rfreq, write=False)
                self.writeAndVerifyBlocks()

                # Unfreeze
                self.FreezeDCO.set(0, write=True)

                # NewFreq
                self.NewFreq()

        def get_freq(read):
            n1 = self.N1.get(read=read)
            hs_div = self.HS_DIV.get(read=read)
            rfreq = self.RFREQ.get(read=read)
            fxtal = self.fxtal.get(read=read)

            return (fxtal * rfreq)/(hs_div * n1)


        self.add(pr.LinkVariable(
            name = 'Frequency',
            dependencies = [self.N1, self.HS_DIV, self.RFREQ, self.fxtal],
            linkedGet = get_freq,
            linkedSet = set_freq))
