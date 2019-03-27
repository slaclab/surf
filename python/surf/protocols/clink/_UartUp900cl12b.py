#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue CameraLink module
#-----------------------------------------------------------------------------
# File       : _UartUp900cl12b.py
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

class UartUp900cl12bRx(clink.ClinkSerialRx):
    def __init__(self,**kwargs):
        super().__init__(**kwargs)        

    def _acceptFrame(self,frame):
        ba = bytearray(frame.getPayload())
        frame.read(ba,0)

        for i in range(0,len(ba),4):
            c = chr(ba[i])
            # print (ba[i])

            if (c == '\r'):
                print("Got Response: {}".format(''.join(self._cur)))
                self._cur = []
            elif (c != '') and (ba[i] != 1):
                self._cur.append(c)
               
class UartUp900cl12b(pr.Device):
    def __init__(   self,       
            name        = 'UartUp900cl12b',
            description = 'Uart Uniq UP-900CL-12B channel access (http://uniqvision.com/Downloads/UP900CL-12B)',
            serial      = None,
            **kwargs):
        super().__init__(name=name, description=description, **kwargs) 

        # Attach the serial devices
        self._rx = clink.UartUp900cl12bRx()
        pr.streamConnect(serial,self._rx)

        self._tx = clink.ClinkSerialTx()
        pr.streamConnect(self._tx,serial)
        
        @self.command(value='', name='SendString', description='Send a command string')
        def sendString(arg):
            if self._tx is not None:
                self._tx.sendString(arg)
        
        ##############################
        # Variables
        ##############################        
        
        self.add(pr.LocalVariable(    
            name         = 'RU',
            description  = 'Recall user page: Must have a number after “ru” such as 1, 2, 3 or 4',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'ru{value}') if value!='' else ''
        ))
        
        self.add(pr.BaseCommand(    
            name         = 'RP',
            description  = 'Report current camera setting',
            function     = lambda cmd: self._tx.sendString('rp')
        ))  

        self.add(pr.BaseCommand(    
            name         = 'RF',
            description  = 'Recall factory setting page',
            function     = lambda cmd: self._tx.sendString('rf')
        ))          
        
        self.add(pr.LocalVariable(    
            name         = 'SM',
            description  = 'Shutter mode: Must have a number after sm (1 ~ f), refer to section 3.3 for details.',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'sm{value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(    
            name         = 'SP',
            description  = 'Save user page: There are 4 user page available',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'sp{value}') if value!='' else ''
        ))        
        
        self.add(pr.BaseCommand(    
            name         = 'NS',
            description  = 'Normal speed: Refer to camera specifications',
            function     = lambda cmd: self._tx.sendString('ns')
        ))

        self.add(pr.BaseCommand(    
            name         = 'DS',
            description  = 'Double speed: Refer to camera specifications',
            function     = lambda cmd: self._tx.sendString('ds')
        )) 

        self.add(pr.BaseCommand(    
            name         = 'NM',
            description  = 'Normal mode: Normal free running',
            function     = lambda cmd: self._tx.sendString('nm')
        )) 

        self.add(pr.BaseCommand(    
            name         = 'AM',
            description  = 'Asynchronous mode: Asynchronous reset',
            function     = lambda cmd: self._tx.sendString('am')
        ))         
        
        self.add(pr.LocalVariable(    
            name         = 'GI',
            description  = 'Gain increase: ### = Hexadecimals (000 ~ 3ff). If no number entered, gain will be increased by factor of 1. If a number is entered, then number will be added to stored gain.',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'gi{value}') if value!='' else ''
        ))     
        
        self.add(pr.LocalVariable(    
            name         = 'GD',
            description  = 'Gain decrease: ### = Hexadecimals (000 ~ 3ff). Same as gi, except it will be decreased.',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'gd{value}') if value!='' else ''
        )) 

        self.add(pr.LocalVariable(    
            name         = 'GN',
            description  = 'Gain number: ### = Hexadecimals (000 ~ 3ff). Refer to the gain curves below for details',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'gn{value}') if value!='' else ''
        )) 

        self.add(pr.LocalVariable(    
            name         = 'BI',
            description  = 'Reference increase: ### = Hexadecimals (000 ~ 3ff). If no number entered, reference will be increased by factor of 1. If a number is entered, then number will be added to stored reference. Note: It’s very uncommon to change reference level, contact UNIQ for further details.',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'bi{value}') if value!='' else ''
        )) 

        self.add(pr.LocalVariable(    
            name         = 'BD',
            description  = 'Reference decrease: ### = Hexadecimals (000 ~ 3ff). If no number entered, reference will be increased by factor of 1. If a number is entered, then number will be added to stored reference. Note: It’s very uncommon to change reference level, contact UNIQ for further details.',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'bd{value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(    
            name         = 'BN',
            description  = 'Reference number: ### = Hexadecimals (000 ~ 3ff). If no number entered, reference will be increased by factor of 1. If a number is entered, then number will be added to stored reference. Note: It’s very uncommon to change reference level, contact UNIQ for further details.',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'bn{value}') if value!='' else ''
        ))        
        