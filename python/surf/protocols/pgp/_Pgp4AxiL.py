#-----------------------------------------------------------------------------
# This file is part of 'SLAC Firmware Standard Library'.
# It is subject to the license terms in the LICENSE.txt file found in the
# top-level directory of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of 'SLAC Firmware Standard Library', including this file,
# may be copied, modified, propagated, or distributed except according to
# the terms contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import surf.protocols.pgp as pgp

class Pgp4AxiL(pgp.Pgp3AxiL):
    def __init__(self,
                 description = "Configuration and status a PGP 4 link",
                 **kwargs):
        super().__init__(description=description, **kwargs)
