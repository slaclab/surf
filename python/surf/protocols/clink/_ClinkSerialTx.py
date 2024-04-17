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

class ClinkSerialTx(rogue.interfaces.stream.Master):

    def __init__(self,path):
        rogue.interfaces.stream.Master.__init__(self)
        self._path = path

    def sendEscape(self):
        ba = bytearray(4)
        ba[0] = 27

        frame = self._reqFrame(len(ba),True)
        frame.write(ba,0)
        self._sendFrame(frame)

    def sendString(self,st):
        print(self._path+': SendString: %s' % st )
        ba = bytearray((len(st)+1)*4)
        i = 0
        for c in st:
            ba[i] = ord(c)
            i += 4
        ba[i] = 0x0D

        frame = self._reqFrame(len(ba),True)
        frame.write(ba,0)
        self._sendFrame(frame)
