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

import surf.ethernet.roce as roce

class RoCEv2AxiStreamRdma(pr.Device):
    def __init__( self,
                  dcqcn = True,
                  dispatchBits = 24,
                  **kwargs):
        super().__init__(**kwargs)

        self.add(roce.RoCEv2Engine(
            name   = "Engine",
            offset = 0x0000,
            expand = False,
        ))

        if dcqcn:
            self.add(roce.RoCEv2Dcqcn(
                name   = "Dcqcn",
                offset = 0x1000,
                expand = False,
            ))

        self.add(roce.RoCEv2AxiStreamRdmaCore(
            name         = "Core",
            offset       = 0x2000,
            dispatchBits = dispatchBits,
            expand       = False,
        ))
