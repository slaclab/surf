#!/usr/bin/env python3
#-----------------------------------------------------------------------------
# This file is part of the 'Development Board Examples'. It is subject to 
# the license terms in the LICENSE.txt file found in the top-level directory 
# of this distribution and at: 
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
# No part of the 'Development Board Examples', including this file, may be 
# copied, modified, propagated, or distributed except according to the terms 
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

import rogue.utilities 
import rogue.protocols.udp
import rogue.interfaces.stream
import pyrogue.interfaces.simulation
import rogue
import pyrogue
import time
import threading

#################################################################

class RssiOutOfOrder(rogue.interfaces.stream.Slave, rogue.interfaces.stream.Master):

    def __init__(self, period=0):
        rogue.interfaces.stream.Slave.__init__(self)
        rogue.interfaces.stream.Master.__init__(self)

        self._period = period
        self._lock   = threading.Lock()
        self._last   = None
        self._cnt    = 0

    @property
    def period(self,value):
        return self._period

    @period.setter
    def period(self,value):
        with self._lock:
            self._period = value

            # Send any cached frames if period is now 0
            if self._period == 0 and self._last is not None:
                self._sendFrame(self._last)
                self._last = None

    def _acceptFrame(self,frame):

        with self._lock:
            self._cnt += 1

            # Frame is cached, send current frame before cached frame
            if self._last is not None:
                self._sendFrame(frame)
                self._sendFrame(self._last)
                self._last = None

            # Out of order period has elapsed, store frame
            elif self._period > 0 and (self._cnt % self._period) == 0:
                self._last = frame

            # Otherwise just forward the frame
            else:
                self._sendFrame(frame)

#################################################################

class MyRoot(pyrogue.Root):
    def __init__(   self,       
            name        = "MyRoot",
            description = "my root container",
            **kwargs):
        super().__init__(name=name, description=description, **kwargs)
                
        # Setup the TCP sockets connections
        self.srv = rogue.interfaces.stream.TcpClient('localhost',9000)
        self.clt = rogue.interfaces.stream.TcpClient('localhost',9002)  

        # Out of order module on client side
        self.srvToClt = RssiOutOfOrder(period=2)
        self.cltToSrv = RssiOutOfOrder(period=1)

        # Insert out of order from server to client
        pyrogue.streamConnect(self.srv,      self.srvToClt)
        pyrogue.streamConnect(self.srvToClt, self.clt)

        # Insert out of order from client to server
        pyrogue.streamConnect(self.clt,      self.cltToSrv)
        pyrogue.streamConnect(self.cltToSrv, self.srv)

#################################################################

# Set base
rootTop = MyRoot(timeout=100.0)

# Stop the system
input("Press any key to exit...")
rootTop.stop()
exit()  
