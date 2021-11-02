#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------
import scipy
import pyrogue as pr

class FirFilterSingleChannel(pr.Device):
    def __init__(
            self,
            numberTaps      = None, # TAP_SIZE_G
            dataWordBitSize = None, # WIDTH_G
            **kwargs):
        super().__init__(**kwargs)

        if numberTaps is None:
            raise ValueError( f'{self.path}: numberTaps is undefined' )

        if dataWordBitSize is None:
            raise ValueError( f'{self.path}: dataWordBitSize is undefined' )

        self.add(pr.RemoteVariable(
            name = f'Taps',
            offset = 0,
            disp = '{:0.04f}',
            bitSize = 32*numberTaps,
            valueBits = dataWordBitSize,
            numValues = numberTaps,
            valueStride = 32,
            base = pr.Fixed(dataWordBitSize, dataWordBitSize-1)))

            
