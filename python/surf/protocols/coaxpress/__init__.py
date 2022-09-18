##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################
from surf.protocols.coaxpress._CoaXPressAxiL import *
from surf.protocols.coaxpress._Bootstrap     import *

from surf.protocols.coaxpress._PhantomS991   import *

def addStringVariables(dev, name, description, offset, number):

    for i in range(number):
        for j in range(4):
            dev.add(pr.RemoteVariable(
                name         = f'{name}Byte[{i*4+j}]',
                description  = description,
                base         = pr.String,
                offset       = offset+(i*4),
                bitSize      = 8,
                bitOffset    = (3-j)*8,
                mode         = 'RO',
                hidden       = True,
            ))

    dev.add(pr.LinkVariable(
        name         = name,
        linkedGet    = lambda var: ''.join([var.dependencies[x].value() for x in range(4*number)]),
        dependencies = [dev.variables[f'{name}Byte[{x}]'] for x in range(4*number)],
    ))
