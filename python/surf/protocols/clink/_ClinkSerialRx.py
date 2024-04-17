#-----------------------------------------------------------------------------
# Title      : PyRogue CameraLink module, serial receiver
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

import rogue.interfaces.stream

class ClinkSerialRx(rogue.interfaces.stream.Slave):

    def __init__(self,path):
        rogue.interfaces.stream.Slave.__init__(self)
        self._cur = []
        self._last = None
        self._path = path

    def _acceptFrame(self,frame):
        ba = bytearray(frame.getPayload())
        frame.read(ba,0)

        for i in range(0,len(ba),4):
            c = chr(ba[i])

            if c == '\n':
                print(self._path+": Got Response: {}".format(''.join(self._cur)))
                self._cur = []
            elif c == '\r':
                print(self._path+": recvString: {}".format(''.join(self._cur)))
                self._last = ''.join(self._cur)
            elif c != '':
                self._cur.append(c)
