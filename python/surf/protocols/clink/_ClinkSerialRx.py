#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue CameraLink module, serial receiver
#-----------------------------------------------------------------------------
# File       : ClinkSerialRx.py
# Created    : 2017-11-21
#-----------------------------------------------------------------------------
# Description:
# PyRogue CameraLink module
#-----------------------------------------------------------------------------
# This file is part of the rogue software platform. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of the rogue software platform, including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import pyrogue as pr
import rogue.interfaces.stream

class ClinkSerialRx(rogue.interfaces.stream.Slave):

    def __init__(self):
        rogue.interfaces.stream.Slave.__init__(self)
        self._cur = []

    def _acceptFrame(self,frame):
        ba = bytearray(frame.getPayload())
        frame.read(ba,0)

        for i in range(0,len(ba),4):
            c = chr(ba[i])

            if c == '\n':
                print("Got Response: {}".format(''.join(self._cur)))
                self._cur = []
            elif c != '\r':
                self._cur.append(c)

