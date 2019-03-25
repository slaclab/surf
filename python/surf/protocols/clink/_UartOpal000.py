#!/usr/bin/env python
#-----------------------------------------------------------------------------
# Title      : PyRogue CameraLink module
#-----------------------------------------------------------------------------
# File       : _UartOpal000.py
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
        
class UartOpal000Rx(clink.ClinkSerialRx):
    def __init__(self,**kwargs):
        super().__init__(**kwargs)        

    def _acceptFrame(self,frame):
        ba = bytearray(frame.getPayload())
        frame.read(ba,0)

        for i in range(0,len(ba),4):
            c = chr(ba[i])

            if c == '\n':
                print("Got Response: {}".format(''.join(self._cur)))
                self._cur = []
            elif ba[i] == 0x6:
                print("Got ACK Response: {}".format(''.join(self._cur)))
                self._cur = []
            elif ba[i] == 0x25:
                print("Got NAK Response: {}".format(''.join(self._cur)))
                self._cur = []
            elif c != '':
                self._cur.append(c)

class UartOpal000(pr.Device):
    def __init__(   self,       
            name        = 'UartOpal000',
            description = 'Uart Opal000 channel access',
            serial      = None,
            **kwargs):
        super().__init__(name=name, description=description, **kwargs) 
        
        # Attach the serial devices
        self._rx = UartOpal000Rx()
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
            name         = 'CCE[0]',
            description  = 'Selects the exposure control source and event selection',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'@CCE{self.CCE[0].get()};{self.CCE[1].get()}') if (self.CCE[0].get()!='' and self.CCE[1].get()!='') else ''
        )) 

        self.add(pr.LocalVariable(    
            name         = 'CCE[1]',
            description  = 'Selects the exposure control source and event selection',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'@CCE{self.CCE[0].get()};{self.CCE[1].get()}') if (self.CCE[0].get()!='' and self.CCE[1].get()!='') else ''
        ))          
        
        self.add(pr.LocalVariable(    
            name         = 'CCFS[0]',
            description  = 'Selects the frame start control source and event selection',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'@CCFS{self.CCFS[0].get()};{self.CCFS[1].get()}') if (self.CCFS[0].get()!='' and self.CCFS[1].get()!='') else ''
        )) 

        self.add(pr.LocalVariable(    
            name         = 'CCFS[1]',
            description  = 'Selects the frame start control source and event selection',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'@CCFS{self.CCFS[0].get()};{self.CCFS[1].get()}') if (self.CCFS[0].get()!='' and self.CCFS[1].get()!='') else ''
        ))           
        
        self.add(pr.LocalVariable(    
            name         = 'DPE',
            description  = 'Enables or disables the defect pixel correction.',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'@DPE{value}') if value!='' else ''
        ))   

        self.add(pr.LocalVariable(    
            name         = 'FP',
            description  = 'Sets the frame period.',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'@FP{value}') if value!='' else ''
        ))           

        self.add(pr.LocalVariable(    
            name         = 'FSM',
            description  = 'Selects the FSTROBE output and polarity',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'@FSM{value}') if value!='' else ''
        ))  
        
        self.add(pr.LocalVariable(    
            name         = 'FST[0]',
            description  = 'Configures the FSTROBE, step, delay and active',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'@FST{self.FST[0].get()};{self.FST[1].get()}') if (self.FST[0].get()!='' and self.FST[1].get()!='') else ''
        )) 

        self.add(pr.LocalVariable(    
            name         = 'FST[1]',
            description  = 'Configures the FSTROBE, step, delay and active',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'@FST{self.FST[0].get()};{self.FST[1].get()}') if (self.FST[0].get()!='' and self.FST[1].get()!='') else ''
        ))         
        
        self.add(pr.LocalVariable(    
            name         = 'GA',
            description  = 'Sets the digital gain of the camera.',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'@GA{value}') if value!='' else ''
        ))          
        
        self.add(pr.LocalVariable(    
            name         = 'IT',
            description  = 'Sets the integration time.',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'@IT{value}') if value!='' else ''
        ))  

        self.add(pr.LocalVariable(    
            name         = 'MI',
            description  = 'Enables or disables the mirror function.',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'@MI{value}') if value!='' else ''
        ))          
        
        self.add(pr.LocalVariable(    
            name         = 'MO',
            description  = 'Sets the operating mode of the camera.',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'@MO{value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(    
            name         = 'OFS',
            description  = 'Sets the output offset in GL at 12 bit internal resolution',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'@OFS{value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(    
            name         = 'OR',
            description  = 'Sets the output resolution of the camera.',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'@OR{value}') if value!='' else ''
        ))        
        
        self.add(pr.LocalVariable(    
            name         = 'TP',
            description  = 'Selects display of the test pattern',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'@TP{value}') if value!='' else ''
        )) 

        self.add(pr.LocalVariable(    
            name         = 'VBIN',
            description  = 'Sets the image output binning',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'@VBIN{value}') if value!='' else ''
        ))
        
        self.add(pr.LocalVariable(    
            name         = 'WB[0]',
            description  = 'Sets the gain for the Red, Green and Blue channel',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'@WB{self.WB[0].get()};{self.WB[1].get()};{self.WB[2].get()}') if (self.WB[0].get()!='' and self.WB[1].get()!='' and self.WB[2].get()!='') else ''
        )) 

        self.add(pr.LocalVariable(    
            name         = 'WB[1]',
            description  = 'Sets the gain for the Red, Green and Blue channel',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'@WB{self.WB[0].get()};{self.WB[1].get()};{self.WB[2].get()}') if (self.WB[0].get()!='' and self.WB[1].get()!='' and self.WB[2].get()!='') else ''
        ))  

        self.add(pr.LocalVariable(    
            name         = 'WB[2]',
            description  = 'Sets the gain for the Red, Green and Blue channel',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'@WB{self.WB[0].get()};{self.WB[1].get()};{self.WB[2].get()}') if (self.WB[0].get()!='' and self.WB[1].get()!='' and self.WB[2].get()!='') else ''
        ))          
        
        self.add(pr.LocalVariable(    
            name         = 'BL',
            description  = 'Sets the black level.',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'@BL{value}') if value!='' else ''
        ))        
                
        self.add(pr.LocalVariable(    
            name         = 'VR',
            description  = 'Enableling and disableling the vertical remap is done by means of the vertical remap command.',
            mode         = 'RW', 
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'@VR{value}') if value!='' else ''
        ))    

        self.add(pr.LocalVariable(    
            name         = 'FSP',
            description = '''
                The active state of the strobe output can be inverted to adapt to the application requirements.
                0 for the reverse polarity: in this polarity configuration the phototransistor at the camera output is non-conductive during the active state of the strobe.
                1 for the normal polarity: in this polarity configuration the phototransistor at the camera output is conductive during the active state of the strobe.
                ''',            
            mode         = 'RW', 
            value        = '', 
            localSet     = lambda value: self._tx.sendString(f'@FSP{value}') if value!='' else ''
        ))            
            

            