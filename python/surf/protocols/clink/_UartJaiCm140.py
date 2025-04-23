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

class UartJaiCm140Tx(clink.ClinkSerialTx):
    def sendString(self,st):
        print( f'{self._path}: SendString: {st}' )
        ba = bytearray((len(st)+2)*4)
        i = 0
        for c in st:
            ba[i] = ord(c)
            i += 4
        ba[i+0] = 0x0D # <CR>
        ba[i+4] = 0x0A # <LF>

        frame = self._reqFrame(len(ba),True)
        frame.write(ba,0)
        self._sendFrame(frame)

class UartJaiCm140Rx(clink.ClinkSerialRx):
    def _acceptFrame(self,frame):
        ba = bytearray(frame.getPayload())
        frame.read(ba,0)

        for i in range(0,len(ba),4):
            c = chr(ba[i])

            if c == '\n':
                print(self._path+": Got Response: {}".format(''.join(self._cur)))
                self._cur = []
            elif c == '\r':
                self._last = ''.join(self._cur)
            elif c != '':
                self._cur.append(c)

class UartJaiCm140(pr.Device):
    def __init__(self, serial=None, **kwargs):
        super().__init__(**kwargs)

        # Attach the serial devices
        self._rx = UartJaiCm140Rx(self.path)
        pr.streamConnect(serial,self._rx)

        self._tx = UartJaiCm140Tx(self.path)
        pr.streamConnect(self._tx,serial)

        @self.command(value='', name='SendString', description='Send a command string')
        def sendString(arg):
            if self._tx is not None:
                self._tx.sendString(arg)

        #######################################################################
        # General settings and utility Commands
        #######################################################################
        self.add(pr.LocalVariable(
            name         = 'EB',
            description  = 'Echo Back: 0=Echo off, 1=Echo on',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'EB={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'ST',
            description  = 'Camera Status Request',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString('ST?') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'HP',
            description  = 'Online Help Request',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString('HP?') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'VN',
            description  = 'Firmware Version',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString('VN?') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'ID',
            description  = 'Camera ID Request',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString('ID?') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'MD',
            description  = 'Model Name Request',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString('MD?') if value!='' else ''
        ))

        #######################################################################
        # Shutter Commands
        #######################################################################
        self.add(pr.LocalVariable(
            name         = 'SM',
            description  = 'Shutter mode: SM=0 and SM=1, 0=Preset Shutter, 1=Programmable exposure',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'SM={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'SH',
            description  = 'Preset Shutter (Available when SM=0): 0=Off, 1=1/60, 2=1/100, 3=1/250, 4=1/500, 5=1/1000, 6=1/2000, 7=1/4000, 8=1/8000, 9=1/10000',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'SH={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'PE',
            description  = 'Programmable Exposure (Available when SM=1): 2 to 1052',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'PE={value}') if value!='' else ''
        ))

        #######################################################################
        # Trigger mode Commands
        #######################################################################
        self.add(pr.LocalVariable(
            name         = 'TR',
            description  = 'Trigger Mode: 0=Normal (Continuous), 1=EPS(Edge pre select), 2=PWC(Pulse width control), 3=RCT',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'TR={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'TP',
            description  = 'Trigger polarity: 0=Active Low, 1=Active High',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'TP={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'TI',
            description  = 'Trigger input: 0=Camera Link, 1=Hirose 12pin',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'TI={value}') if value!='' else ''
        ))

        #######################################################################
        # Image Format Commands
        #######################################################################
        self.add(pr.LocalVariable(
            name         = 'BA',
            description  = 'Bit allocation: 0=10bit, 1=8bit',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'BA={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'SC',
            description  = 'Partial scan: 0=Full Frame, 1=2/3 Partial, 2=1/2 Partial, 3=1/4 Partial, 4=1/8 Partial',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'SC={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'VB',
            description  = 'Vertical binning(Only for CM-140MCL): 0=OFF, 1=On',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'VB={value}') if value!='' else ''
        ))

        #######################################################################
        # Gain, Black and signal settings
        #######################################################################
        self.add(pr.LocalVariable(
            name         = 'GA',
            description  = 'Gain level: GA=-84 through +336, GA=0 is 0dB gain, which is normal working point. The range is from -3 dB to +12 dB.',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'GA={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'BL',
            description  = 'Black level: BL=0 through BL=1023, Black level (or set-up level) will set the video level for black. Factory setting is 32 LSB for 10bit or 8 LSB for 8bit',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'BL={value}') if value!='' else ''
        ))

    def _rootAttached(self,parent,root):
        super()._rootAttached(parent,root)
        self._rx._path = self.path
        self._tx._path = self.path
