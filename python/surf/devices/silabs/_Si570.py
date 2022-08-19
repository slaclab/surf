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
    def __init__(self, factory_freq):
        super().__init__(**kwargs)
        self.factory_freq = factory_freq

        ADDR_SIZE = 4

        self.add(pr.RemoteVariable(
            name = 'N1_RAW'
            offset = [7*ADDR_SIZE, 8*ADDR_SIZE],
            bitSize = [5, 2]
            bitOffset = [0, 6],
            base = pr.UIntBE))

        def read_n1(read):
            n1_raw = self.N1_RAW.get(read=read)
            if n1_raw == 0:
                return 1
            else:
                return n1_raw << 1

        self.add(pr.LinkVariable(
            name = 'N1'
            dependencies = [self.N1_RAW]
            linkedGet = read_n1,
            linkedSet = lambda value, write: self.N1_RAW.set(value>>1, write=write)))
        

        self.add(pr.RemoteVariable(
            name = 'HS_DIV_RAW',
            offset = 7 * ADDR_SIZE,
            bitSize = 3,
            bitOffset = 5,
            emum = {
                0: '4',
                1: '5',
                2: '6',
                3: '7',
                5: '9',
                7: '11'}))

        self.add(pr.LinkVariable(
            name 'HS_DIV',
            dependencies = [self.HS_DIV_RAW],
            linkedGet = lambda read: int(self.HS_DIV_RAW.get(read=read))
            linkedSet = lambda value, write: self.HS_DIV_RAW.setDisp(str(value))))

        self.add(pr.RemoteVariable(
            name = 'RFREQ_RAW',
            offset = [8*ADDR_SIZE, 9*ADDR_SIZE, 10*ADDR_SIZE, 11*ADDR_SIZE, 12*ADDR_SIZE],
            bitSize = [6, 8, 8, 8, 8],
            bitOffset =[0, 0, 0, 0, 0],
            base = pr.UIntBE
        ))

        self.add(pr.LinkVariable(
            name = 'RFREQ',
            dependencies = [self.RFREQ_RAW],
            linkedGet = lambda read: self.RFREQ_RAW.get(read=read) / 2**28,
            linkedSet = lambda value, write: self.RFREQ_RAW.set(int(value*2**28), write=write)))

        self.add(pr.RemoteCommand(
            name = 'RST_REG'
            offset = 135 * ADDR_SIZE,
            bitOffset = 7,
            bitSize = 1,
            function = pr.Command.toggle))

        self.add(pr.RemoteCommand(
            name = 'NewFreq',
            offset = 135 * ADDR_SIZE,
            bitOffset = 6,
            bitSize = 1,
            function = pr.Command.touchOne))

        self.add(pr.RemoteVariable(
            name = 'FreezeM',
            offset = 135 * ADDR_SIZE,
            bitOffset = 5,
            bitSize = 1,
            base = pr.UInt))

        self.add(pr.RemoteVariable(
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

        self.add(pr.LinkVariable(
            name = 'fxtal',
            dependencies = [self.RFREQ, self.HS_DIV, self.N1],
            linkedGet = lambda read: factory_freq * self.HS_DIV.get(read=read) * self.N1.get(read=read) / self.RFREQ.get(read=read)))


        n1_array = [1] + [x for x in range(2, 2**7, 2)]
        hs_div_array = [11, 9, 7, 6, 5, 4]

        def find_params(f1):
            # want low N1 and high HS_DIV
            for n1 in n1_array:
                for hs_div in hs_div_array:
                    fdco = f1 * hs_div_array * n1
                    if 4850 < fdco < 5670:
                        return n1, hs_div
        
        def set_freq(value, write):
            if write is False:
                return
            
            n1, hs_div = find_params(value)
            fdco = value * hs_div * n1
            rfreq = fdco / self.fxtal.get(read=true)

            print(f'Si570 setting new params, {n1=}, {hs_div=}, {rfreq=}, {fcdo=}')
            return

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
