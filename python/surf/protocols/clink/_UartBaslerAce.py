#-----------------------------------------------------------------------------
# Title      : PyRogue CameraLink module
#-----------------------------------------------------------------------------
# Description:
# PyRogue CameraLink Basler ACE module
# https://www.baslerweb.com/en/products/cameras/area-scan-cameras/ace/aca2040-180kmnir/
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
import rogue.interfaces.stream
import surf.protocols.clink as clink

class UartBaslerAceRx(clink.ClinkSerialRx):
    def __init__(self, path, **kwargs):
        super().__init__(path=path,**kwargs)

    def _acceptFrame(self,frame):
        ba = bytearray(frame.getPayload())
        frame.read(ba,0)

        for i in range(0,len(ba),4):
            # Check for ACK
            if ba[i] == 0x06:
                print ( self._path+': Got ACK Response' )
            # Check for ACK
            if ba[i] == 0x15:
                print ( self._path+': Got NACK Response' )

class UartBaslerAceTx(rogue.interfaces.stream.Master):
    def __init__(self, path, **kwargs):
        super().__init__(**kwargs)
        self._path = path

    def sendCmd(self,addr,data):
        # Create the byte array to be filled
        ba = bytearray(4*13)

        # BFS byte is always 0x01
        ba[4*0] = 0x1

        # FTF: Write operation
        ba[4*1] = 0x5

        # DataLen field
        ba[4*2] = 0x4

        # Address field (in little endian)
        for i in range(4):
            ba[(4*3)+4*i] = (int(addr) >> 8*i) & 0xFF

        # Data field (in little endian)
        for i in range(4):
            ba[(4*7)+4*i] = (int(data) >> 8*i) & 0xFF

        # Block Check Character (BCC)
        BCC = ba[4*1]
        for i in range(2,11,1):
            BCC ^= ba[4*i]
        ba[4*11] = BCC

        # BFE field is always 0x03
        ba[4*12] = 0x3

        dbgstring = ''
        for i in range(13):
            dbgstring += '0x{0:0{1}X},'.format(ba[4*i],2)
        print( f'{self._path}: SendString: {dbgstring[:-1]}' )

        # Send the byte array
        frame = self._reqFrame(len(ba),True)
        frame.write(ba,0)
        self._sendFrame(frame)

class UartBaslerAce(pr.Device):
    def __init__(self, serial=None, **kwargs):
        super().__init__(**kwargs)

        # Attach the serial devices
        self._rx = clink.UartBaslerAceRx(self.path)
        pr.streamConnect(serial,self._rx)

        self._tx = clink.UartBaslerAceTx(self.path)
        pr.streamConnect(self._tx,serial)

        def createCmd(addr):
            def _cmd(value):
                if value != '':
                    self._tx.sendCmd(addr=addr, data=value)
            return _cmd

        ###############################
        # 4.2 Transport Layer Registers
        ###############################
        self.add(pr.LocalVariable(
            name         = 'TapGeometry',
            description  = 'The CL Tap Geometry value sets the tap geometry that will be used when image data is read out of the camera’s image buffer and transmitted via the Camera Link interface.',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0724)
        ))

        self.add(pr.LocalVariable(
            name         = 'PixelClock',
            description  = 'The CL Pixel Clock value sets the pixel clock speed that will be used by the Camera Link interface.',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0744)
        ))

        ############################
        # 4.4 Image Format Registers
        ############################

        self.add(pr.LocalVariable(
            name         = 'DigitizationTaps',
            description  = 'The Sensor Digitization Taps value sets the number of taps on the camera\'s imaging sensor that will be used to read pixel values out of the sensor.',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x00030004)
        ))


        self.add(pr.LocalVariable(
            name         = 'BitDepth',
            description  = 'The Sensor Bit Depth value sets the bit depth of the pixel data produced by the camera’s imaging sensor.',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x00030504)
        ))

        self.add(pr.LocalVariable(
            name         = 'PixelFormat',
            description  = 'The Pixel Format value sets the pixel format to use during image acquisition.',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x00030024)
        ))

        self.add(pr.LocalVariable(
            name         = 'BinningHorizontal',
            description  = 'The horizontal binning feature allows to horizontally combine pixel values from adjacent columns into one pixel.',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x00030324)
        ))

        self.add(pr.LocalVariable(
            name         = 'BinningVertical',
            description  = 'The vertical binning feature allows to vertically combine pixel values from adjacent lines into one pixel.',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x00030344)
        ))

        self.add(pr.LocalVariable(
            name         = 'StackedZoneImagingEnable',
            description  = 'The Stacked Zone Imaging Enable value is used to enable the camera’s stacked zone imaging feature.',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x0003E004)
        ))

        self.add(pr.LocalVariable(
            name         = 'DecimationHorizontal',
            description  = 'The Decimation Horizontal value specifies the extent of horizontal subsampling of the acquired frame.',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x000303A4)
        ))

        self.add(pr.LocalVariable(
            name         = 'DecimationVertical',
            description  = 'The Decimation Vertical value specifies the extent of vertical subsampling of the acquired frame.',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x000303C4)
        ))


        ###################################
        # 4.5 Acquisition Control Registers
        ###################################
        self.add(pr.LocalVariable(
            name         = 'TrigModeAcqStart',
            description  = 'The Trigger Mode Acquisition Start value sets the mode for the acquisition start trigger.',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x00040104)
        ))

        self.add(pr.LocalVariable(
            name         = 'AcqFrameCnt',
            description  = 'When the Trigger Mode parameter for the acquisition start trigger is set to on, you must set the value of the camera’s Acquisition Frame Count parameter. The value of the Acquisition Frame Count can range from 1 to 255.',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x000400A4)
        ))

        self.add(pr.LocalVariable(
            name         = 'TrigSrcAcqStart',
            description  = 'Set the value of the Trigger Source Acquisition Start register to Software, Line 1, CC1, CC2, or CC3.',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x00040144)
        ))

        self.add(pr.LocalVariable(
            name         = 'TrigActAcqStart',
            description  = 'The Trigger Activation Acquisition Start value determines when the acquisition start trigger signal will be considered as valid.',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x00040164)
        ))

        self.add(pr.LocalVariable(
            name         = 'TrigModeFrameStart',
            description  = 'The Trigger Mode Frame Start value sets the mode for the frame start trigger.',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x00040204)
        ))

        self.add(pr.LocalVariable(
            name         = 'TrigSrcFrameStart',
            description  = 'If the Trigger Source Frame Start value is set to On, the Trigger Source Frame Start value sets the source signal that will be used for the frame start trigger.',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x00040244)
        ))

        self.add(pr.LocalVariable(
            name         = 'TrigActFrameStart',
            description  = 'The Trigger Activation Frame Start value determines when the frame start trigger signal will be considered as valid.',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x00040264)
        ))

        self.add(pr.LocalVariable(
            name         = 'TrigSrcLineStart',
            description  = 'If the Trigger Source Line Start value is set to On, the Trigger Source Line Start value sets the source signal that will be used for the line start trigger.',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x00040344)
        ))

        self.add(pr.LocalVariable(
            name         = 'TrigActLineStart',
            description  = 'The Trigger Activation Line Start value determines when the line start trigger signal will be considered as valid.',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x00040364)
        ))

        ################################
        # 4.6 Exposure Control Registers
        ################################
        self.add(pr.LocalVariable(
            name         = 'ExposureMode',
            description  = 'The Exposure mode parameter sets the camera\'s exposure mode.',
            mode         = 'RW',
            value        = '',
            localSet     = createCmd(addr=0x00040404)
        ))

    def _rootAttached(self,parent,root):
        super()._rootAttached(parent,root)
        self._rx._path = self.path
        self._tx._path = self.path
