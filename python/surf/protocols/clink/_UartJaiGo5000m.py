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

class UartJaiGo5000mTx(clink.ClinkSerialTx):
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

class UartJaiGo5000mRx(clink.ClinkSerialRx):
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

class UartJaiGo5000m(pr.Device):
    def __init__(self, serial=None, **kwargs):
        super().__init__(**kwargs)

        # Attach the serial devices
        self._rx = UartJaiGo5000mRx(self.path)
        pr.streamConnect(serial,self._rx)

        self._tx = UartJaiGo5000mTx(self.path)
        pr.streamConnect(self._tx,serial)

        @self.command(value='', name='SendString', description='Send a command string')
        def sendString(arg):
            if self._tx is not None:
                self._tx.sendString(arg)

        #######################################################################
        # General settings and utility Commands
        #######################################################################
        self.add(pr.LocalVariable(
            name         = 'DVN',
            description  = 'DeviceVendorName',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString('DVN?') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'MD',
            description  = 'DeviceModelName',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString('MD?') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'DV',
            description  = 'DeviceVersion',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString('DV?') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'ID',
            description  = 'DeviceID = Serial Number',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString('ID?') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'VN',
            description  = 'DeviceFirmware Version',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString('VN?') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'RST',
            description  = 'DeviceReset',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString('CRS00=1') if value!='' else ''
        ))

        #######################################################################
        # Image Format Control
        #######################################################################
        self.add(pr.LocalVariable(
            name         = 'HTL',
            description  = 'Height[Default=2048]: 1 ~ (2048 - OffsetY)',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'HTL={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'WTC',
            description  = 'Width[Default=2560]: 8 ~ (2560 - OffsetY)',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'WTC={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'OFL',
            description  = 'OffsetY[Default=0]: 0 ~ (2047 – Height)',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'OFL={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'OFC',
            description  = 'OffsetX[Default=0]: 0 ~ (2552 – Width)',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'OFC={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'HB',
            description  = 'Binning Horizontal[Default=1]: 1: Normal, 2: Binning 2 mode, 4: Binning 4 mode',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'HB={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'VB',
            description  = 'Binning Vertical[Default=1]: 1: Normal, 2: Binning 2 mode, 4: Binning 4 mode',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'VB={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'BA',
            description  = 'PixelFormat[Default=0]: 0: Mono8, 1: Mono10, 2: Mono12',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'BA={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'TPN',
            description  = 'PixelFormat[Default=0]: 0: Off, 1: GreyHorizontal Ramp, 2: GreyVertical Ramp, 3: GreyHorizontal RampMoving',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'TPN={value}') if value!='' else ''
        ))

        #######################################################################
        # Acquisition Control
        #######################################################################
        self.add(pr.LocalVariable(
            name         = 'TM',
            description  = 'FrameStartTrig Mode[Default=0]: 0: Off, 1: On',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'TM={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'STRG',
            description  = 'TriggerSoftware: 0, 1',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'STRG={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'TI',
            description  = 'FrameStartTrig Source[Default=0]: 0: Low, 1: High, 2: SoftTrigger, 8: PulseGenerator0, 13: CL_CC1_In, 14: Nand0, 15: Nand1',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'TI={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'TA',
            description  = 'FrameStartTrig Activation[Default=0]: 0: RisingEdge, 1: FallingEdge, 2: LevelHigh, 3: LevelLow',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'TA={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'EM',
            description  = 'ExposureMode[Default=0]: 0: Off, 1: Timed, 2: TriggerWidth',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'EM={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'PE',
            description  = 'ExposureTime Raw[Default=18000]: 10 ~ 8000000[us]',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'PE={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'ASC',
            description  = 'ExposureAuto Raw[Default=0]: 0: Off, 1: Continuous',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'ASC={value}') if value!='' else ''
        ))

        #######################################################################
        # Analog Control
        #######################################################################
        self.add(pr.LocalVariable(
            name         = 'FGA',
            description  = 'GainRawDigitalAll[Default=100]: 100 ~ 1600',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'FGA={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'ABALL',
            description  = 'AnalogBaseGainAll[Default=0]: 0: 0dB, 1: 6dB, 2:12dB',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'ABALL={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'AGC',
            description  = 'GainAuto[Default=0]: 0: Off, 1: Continuous',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'AGC={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'BL',
            description  = 'BlackLevelRaw All[Default=0]: -256 ~ 255',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'BL={value}') if value!='' else ''
        ))

        #######################################################################
        # Digital IO Control
        #######################################################################
        self.add(pr.LocalVariable(
            name         = 'ND0INV1',
            description  = 'LineInverter_Nand0In1[Default=0]: 0: False, 1: True',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'ND0INV1={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'ND0INV2',
            description  = 'LineInverter_Nand0In2[Default=0]: 0: False, 1: True',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'ND0INV2={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'ND1INV1',
            description  = 'LineInverter_Nand1In1[Default=0]: 0: False, 1: True',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'ND1INV1={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'ND1INV2',
            description  = 'LineInverter_Nand1In2[Default=0]: 0: False, 1: True',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'ND1INV2={value}') if value!='' else ''
        ))

        digValues = '0: Low, 1: High, 3: Frame TriggerWait, 4: Frame Active, 5: Exposure Active, 6: Fval, 7: Lval, 8: Pulse Generator0, 13: CL_CC1_In, 14: Nand0, 15: Nand1'

        self.add(pr.LocalVariable(
            name         = 'LS0',
            description  = f'LineSource_Line1[Default=0]: {digValues}',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'LS0={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'ND0IN1',
            description  = f'LineSource_Nand0In1[Default=0]: {digValues}',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'ND0IN1={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'ND0IN2',
            description  = f'LineSource_Nand0In2[Default=0]: {digValues}',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'ND0IN2={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'ND1IN1',
            description  = f'LineSource_Nand1In1[Default=0]: {digValues}',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'ND1IN1={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'ND1IN2',
            description  = f'LineSource_Nand1In2[Default=0]: {digValues}',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'ND1IN2={value}') if value!='' else ''
        ))

        #######################################################################
        # LUT Control
        #######################################################################
        self.add(pr.LocalVariable(
            name         = 'LUTG',
            description  = 'LUTValueGreen(Mono)[Default=1]: Param 1: LUT index (0 ~ 31), Param 2: LUTdata (0 ~ 4095)',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'LUTG={value}') if value!='' else ''
        ))

        #######################################################################
        # Transport Layer Control
        #######################################################################
        self.add(pr.LocalVariable(
            name         = 'TAGM',
            description  = 'DeviceTap Geometry[Default=5]: 1: Geometry_1X2_1Y, 3: Geometry_1X4_1Y, 5: Geometry_1X8_1Y, 7: Geometry_1X3_1Y',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'TAGM={value}') if value!='' else ''
        ))

        #######################################################################
        # User Set Control
        #######################################################################
        self.add(pr.LocalVariable(
            name         = 'LD',
            description  = 'UserSetLoad[Default=0]: 0: Default, 1: UserSet1, 2: UserSet2, 3: UserSet3',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'LD={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'SA',
            description  = 'UserSetSave[Default=1]: 1: UserSet1, 2: UserSet2, 3: UserSet3',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'SA={value}') if value!='' else ''
        ))

        #######################################################################
        # JAI Custom
        #######################################################################
        self.add(pr.LocalVariable(
            name         = 'AR',
            description  = 'AcquisitionFrame Period[Default=11961]: 1 ~ 325786[us]',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'AR={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'BMW',
            description  = 'BlemishWhite Enable[Default=0]: 0: False, 1: True',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'BMW={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'BMRCW',
            description  = 'BlemishWhite Detect: 1: True',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'BMRCW={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'BMTHW',
            description  = 'BlemishWhite Detect Threshold[Default=10]: 0 ~ 100 percent',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'BMTHW={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'BMPXW',
            description  = 'BlemishWhite DetectPositionX[Default=0]: Param 1: Blemish index, Param 2: X position (0 ~ 2559)',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'BMPXW={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'BMPYW',
            description  = 'BlemishWhite DetectPositionY[Default=0]: Param 1: Blemish index, Param 2: Y position (0 ~ 2047)',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'BMPYW={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'SDCM',
            description  = 'ShadingCorrection Mode[Default=0]: 0: Flat Shading',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'SDCM={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'RS',
            description  = 'ShadingCorrect: 0=Execute Command',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'RS={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'SDRS',
            description  = 'RequestShading DetectResult[Default=0]: 0=Complete, 1=Too Bright, 2=Too dark, 3=Timeout Error, 4=Busy, 5=Limit, 6= Trig is not set as Normal',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'SDRS={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'SDM',
            description  = 'ShadingMode[Default=0]: 0: Off, 1: UserSet1, 2: UserSet2, 3: UserSet3',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'SDM={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'VSM',
            description  = 'VideoSendMode[Default=0]: 0: Normal, 1: Trigger Sequence, 2: Command Sequence, 3: Multi Roi Mode',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'VSM={value}') if value!='' else ''
        ))

        self.add(pr.LocalVariable(
            name         = 'CLCF',
            description  = 'CameraLink ClockFrequency[Default=0]: 0= 72.9MHz, 1= 48.6MHz, 2= 84.9MHz, 3= 58.3MHz',
            mode         = 'WO',
            value        = '',
            localSet     = lambda value: self._tx.sendString(f'CLCF={value}') if value!='' else ''
        ))

    def _rootAttached(self,parent,root):
        super()._rootAttached(parent,root)
        self._rx._path = self.path
        self._tx._path = self.path
