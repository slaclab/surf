#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue CameraLink module
#-----------------------------------------------------------------------------
# File       : UartGeneric.py
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

import surf.protocols.clink as clink
               
class UartGeneric(pr.Device):
    def __init__(   self,       
            name        = 'UartGeneric',
            description = 'Uart Generic channel access',
            serial      = None,
            **kwargs):
        super().__init__(name=name, description=description, **kwargs) 

        if serial is not None:
        
            # Attach the serial devices
            self._rx = clink.ClinkSerialRx()
            pr.streamConnect(serial,self._rx)

            self._tx = clink.ClinkSerialTx()
            pr.streamConnect(self._tx,serial)
            
            @self.command(value='', name='SendString', description='Send a command string')
            def sendString(arg):
                if self._tx is not None:
                    self._tx.sendString(arg)
