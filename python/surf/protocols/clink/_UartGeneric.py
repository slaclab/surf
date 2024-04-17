#-----------------------------------------------------------------------------
# Title      : PyRogue CameraLink module
#-----------------------------------------------------------------------------
# Description:
# PyRogue CameraLink module
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
import surf.protocols.clink as clink

class UartGeneric(pr.Device):
    def __init__(self, serial=None, **kwargs):
        super().__init__(**kwargs)

        if serial is not None:

            # Attach the serial devices
            self._rx = clink.ClinkSerialRx(self.path)
            pr.streamConnect(serial,self._rx)

            self._tx = clink.ClinkSerialTx(self.path)
            pr.streamConnect(self._tx,serial)

            @self.command(value='', name='SendString', description='Send a command string')
            def sendString(arg):
                if self._tx is not None:
                    self._tx.sendString(arg)

    def _rootAttached(self,parent,root):
        super()._rootAttached(parent,root)
        self._rx._path = self.path
        self._tx._path = self.path
