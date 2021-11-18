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

class FirFilterSingleChannel(pr.Device):
    def __init__(
            self,
            numberTaps, # NUM_TAPS_G
            coeffWordBitSize, # COEFF_WIDTH_G
            **kwargs):
        super().__init__(**kwargs)

        self.add(pr.RemoteVariable(
            name = 'Taps',
            offset = 0,
            disp = '{:0.04f}',
            bitSize = 32*numberTaps,
            valueBits = coeffWordBitSize,
            numValues = numberTaps,
            valueStride = 32,
            base = pr.Fixed(coeffWordBitSize, coeffWordBitSize-1)))
