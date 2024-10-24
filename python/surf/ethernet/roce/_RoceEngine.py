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

class RoceEngine(pr.Device):
    def __init__( self,
                  **kwargs):
        super().__init__(**kwargs)

        self.add(pr.RemoteVariable(
            name = 'SendMetaData',
            offset = 0xF00,
            bitSize = 1,
            mode = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name = 'MetaDataTx',
            offset = 0xF04,
            bitSize = 303,
            mode = 'RW',
        ))


        self.add(pr.RemoteVariable(
            name = 'RecvMetaData',
            offset = 0xF00,
            bitSize = 1,
            bitOffset = 1,
            mode = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name = 'MetaDataRx',
            offset = 0xF2C,
            bitSize = 276,
            mode = 'RO',
        ))
