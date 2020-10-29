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

class FirFilterMultiChannel(pr.Device):
    def __init__(
            self,
            numberTaps      = None, # TAP_SIZE_G
            numberChannels  = None, # CH_SIZE_G
            dataWordBitSize = None, # WIDTH_G
            **kwargs):
        super().__init__(**kwargs)

        if numberTaps is None:
            raise ValueError( f'{self.path}: numberTaps is undefined' )

        if numberChannels is None:
            raise ValueError( f'{self.path}: numberChannels is undefined' )

        if dataWordBitSize is None:
            raise ValueError( f'{self.path}: dataWordBitSize is undefined' )

        def addBoolPair(ch,tap):
            self.add(pr.RemoteVariable(
                name         = f'RawCh{ch}Tap[{tap}]',
                description  = f'Tap[{tap}] Fixed Point Coefficient',
                offset       = 0x0,
                bitSize      = dataWordBitSize,
                bitOffset    = (ch*numberTaps+tap)*dataWordBitSize,
                base         = pr.Int,
                mode         = 'RW',
                hidden       = True,
            ))

            var = self.variables[ f'RawCh{ch}Tap[{tap}]' ]

            self.add(pr.LinkVariable(
                name         = f'Ch{ch}Tap[{tap}]',
                description  = f'Tap[{tap}] Floating Point Coefficient',
                mode         = 'RW',
                linkedGet    = lambda: var.value()/2**dataWordBitSize,
                linkedSet    = lambda value, write: var.set(int(value*2**dataWordBitSize)),
                dependencies = [var],
                disp         = '{:1.3f}',
            ))

        for ch in range(numberChannels):
            for tap in range(numberTaps):
                addBoolPair(ch=ch,tap=tap)
