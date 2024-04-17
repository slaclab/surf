#-----------------------------------------------------------------------------
# Description:
# PyRogue AXI4 Monitor Module Module
#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

from surf import axi

class AxiMonAxiL(axi.AxiStreamMonAxiL):
    def __init__(self, numberLanes=1, **kwargs):

        axiType = [None for i in range(2*numberLanes)]
        for i in range(numberLanes):
            axiType[2*i+0] = f'Write[{i}]'
            axiType[2*i+1] = f'Read[{i}]'

        super().__init__(
            numberLanes = 2*numberLanes,
            chName      = axiType,
            **kwargs)
