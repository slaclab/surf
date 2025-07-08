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

class PhantomS641(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        #############################################################
        # Start of manufacturer-specific register space at 0x00006000
        #############################################################

        self.add(pr.RemoteVariable(
            name         = 'DevicePhfwVersionReg',
            description  = 'Version of the firmware in the device.',
            offset       = 0x8174,
            base         = pr.UIntBE,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'DeviceSerialNumberReg',
            description  = 'Serial Number of device.',
            offset       = 0x8158,
            base         = pr.UIntBE,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'DeviceIPAddress',
            description  = 'This feature provides the static IP address of the device',
            offset       = 0x8300,
            base         = pr.String,
            bitSize      = 8*32,
            mode         = 'RO',
            # hidden       = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'DeviceNetmask',
            description  = 'This feature provides the Netmask address of the device',
            offset       = 0x8320,
            base         = pr.String,
            bitSize      = 8*32,
            mode         = 'RO',
            # hidden       = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'pDeviceTemperatureSelectorReg',
            description  = 'Selects the location within the device, where the temperature will be measured.',
            offset       = 0x8168,
            base         = pr.UIntBE,
            bitSize      = 16,
            bitOffset    = 0,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'pDeviceTemperatureReg',
            description  = 'Device temperature in degrees Celsius (C).',
            offset       = 0x8168,
            base         = pr.IntBE,
            bitSize      = 16,
            bitOffset    = 16,
            mode         = 'RO',
            units        = 'degC',
            disp         = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name         = 'WidthMaxReg',
            description  = 'Maximum width (in pixels) of the image. The dimension is calculated after horizontal binning, decimation or any other function changing the horizontal dimension of the image.',
            offset       = 0x8010,
            base         = pr.UIntBE,
            mode         = 'RO',
            units        = 'pixels',
            disp         = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name         = 'WidthReg',
            description  = 'This feature represents the actual image width expelled by the camera (in pixels).',
            offset       = 0x8000,
            base         = pr.UIntBE,
            mode         = 'RW',
            units        = 'pixels',
            disp         = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name         = 'HeightMaxReg',
            description  = 'Maximum height (in pixels) of the image. This dimension is calculated after vertical binning, decimation or any other function changing the vertical dimension of the image.',
            offset       = 0x8014,
            base         = pr.UIntBE,
            mode         = 'RO',
            units        = 'pixels',
            disp         = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name         = 'HeightReg',
            description  = 'This feature represents the actual image height expelled by the camera (in pixels).',
            offset       = 0x8004,
            base         = pr.UIntBE,
            mode         = 'RW',
            units        = 'pixels',
            disp         = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name         = 'PixelFormatReg',
            description  = 'This feature indicates the format of the pixel to use during the acquisition.',
            offset       = 0x8008,
            base         = pr.UIntBE,
            mode         = 'RW',
            enum         = {
                0x00000000: 'Undefined',
                0x01080001: 'Mono8',
                0x010C0006: 'Mono12',
                0x01100007: 'Mono16',
                0x0108000A: 'BayerGB8',
                0x010C0055: 'BayerGB12',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'ImageSourceReg',
            description  = 'This feature controls the image source.',
            offset       = 0x8120,
            base         = pr.UIntBE,
            mode         = 'RW',
            enum         = {
                0: 'LiveImage',
                1: 'OffsetTableGlobal',
                2: 'GainTableAtGlobal',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'ImageSourceGrabReg',
            description  = 'Grab Gain and Offset from camera.',
            offset       = 0x8124,
            base         = pr.UIntBE,
            mode         = 'WO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MultiROIEnableReg',
            description  = 'Enable multiple region of interest mode',
            offset       = 0x8070,
            base         = pr.UIntBE,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'OffsetXReg',
            description  = 'This feature represents the OffsetX',
            offset       = 0x8078,
            base         = pr.UIntBE,
            mode         = 'RW',
            minimum      = 0,
            maximum      = 2560,
        ))

        self.add(pr.RemoteVariable(
            name         = 'OffsetYReg',
            description  = 'This feature represents the OffsetY',
            offset       = 0x807C,
            base         = pr.UIntBE,
            mode         = 'RW',
            minimum      = 0,
            maximum      = 1600,
        ))

        self.add(pr.RemoteVariable(
            name         = 'ActiveWidthReg',
            description  = 'This value represents the Active Width of the Sensor',
            offset       = 0x8084,
            base         = pr.UIntBE,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'ActiveHeightReg',
            description  = 'This value represents the Active Height of the Sensor',
            offset       = 0x8088,
            base         = pr.UIntBE,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'MROISpecialReg',
            description  = 'Additional MultiROI Helper Registers',
            offset       = 0x84FC,
            base         = pr.UIntBE,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'RegionIDValueReg',
            description  = 'Additional MultiROI Helper Registers',
            offset       = 0x8080,
            base         = pr.UIntBE,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'WindowXReg',
            description  = 'Additional MultiROI Helper Registers',
            offset       = 0x8500,
            base         = pr.UIntBE,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'WindowYTOPReg',
            description  = 'Additional MultiROI Helper Registers',
            offset       = 0x8504,
            base         = pr.UIntBE,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'WindowYBOTReg',
            description  = 'Additional MultiROI Helper Registers',
            offset       = 0x8508,
            base         = pr.UIntBE,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'AcquisitionModeReg',
            description  = 'This feature controls the acquisition mode of the device.',
            offset       = 0x8018,
            base         = pr.UIntBE,
            mode         = 'RW',
            enum         = {
                0: 'undefined',
                2: 'Continuous',
            },
        ))

        self.add(pr.RemoteCommand(
            name         = 'AcquisitionStart',
            description  = 'This feature starts the Acquisition of the device.',
            offset       = 0x801C,
            base         = pr.UIntBE,
            bitSize      = 8,
            bitOffset    = 24,
            function     = lambda cmd: cmd.post(1),
        ))

        self.add(pr.RemoteCommand(
            name         = 'AcquisitionStop',
            description  = 'This feature stops the Acquisition of the device at the end of the current Frame.',
            offset       = 0x8020,
            base         = pr.UIntBE,
            bitSize      = 8,
            bitOffset    = 24,
            function     = lambda cmd: cmd.post(0),
        ))

        self.add(pr.RemoteVariable(
            name         = 'pFrameRateReg',
            description  = 'Frame rate in Hz',
            offset       = 0x80C0,
            base         = pr.UIntBE,
            mode         = 'RW',
            minimum      = 24,
            units        = 'Hz',
            disp         = '{:d}',
            # pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'pFrameRateRegMax',
            description  = 'Maximum value for pFrameRateReg',
            offset       = 0x80C4,
            base         = pr.UIntBE,
            mode         = 'RO',
            units        = 'Hz',
            disp         = '{:d}',
            # pollInterval = 1,
        ))

        self.add(pr.RemoteVariable(
            name         = 'ExposureTimeReg',
            description  = 'Sets the Exposure time (in microseconds). This controls the duration where the photosensitive cells are exposed to light.',
            offset       = 0x80C8,
            base         = pr.UIntBE,
            mode         = 'RW',
            minimum      = 1,
            units        = '\u03BCs',
            disp         = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name         = 'pExposureTimeRegMax',
            description  = 'Maximum value for ExposureTimeReg',
            offset       = 0x80CC,
            base         = pr.UIntBE,
            mode         = 'RO',
            units        = '\u03BCs',
            disp         = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name         = 'EDRTimeReg',
            description  = 'Sets the EDR time (in microseconds). This controls the EDR reset of the sensor',
            offset       = 0x80D0,
            base         = pr.UIntBE,
            mode         = 'RW',
            minimum      = 0,
            units        = '\u03BCs',
            disp         = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name         = 'ExposureAutoReg',
            description  = 'Selects auto exposure type',
            offset       = 0x80B4,
            base         = pr.UIntBE,
            mode         = 'RW',
            enum         = {
                0: 'Off',
                1: 'Once',
                2: 'Continuous',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'ExposureAutoCompensationReg',
            description  = 'Sets the auto exposure compensation factor',
            offset       = 0x80B8,
            base         = pr.IntBE,
            mode         = 'RW',
            minimum      = -2,
            maximum      = 2,
        ))

        self.add(pr.RemoteVariable(
            name         = 'ExposureAutoModeReg',
            description  = 'Selects auto exposure mode',
            offset       = 0x80BC,
            base         = pr.UIntBE,
            mode         = 'RW',
            enum         = {
                0: 'Undefined',
                1: 'Average',
                2: 'Spot',
                3: 'CenterWeighted',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'SensorShutterModeReg',
            description  = 'Specifies the shutter mode of the device',
            offset       = 0x817C,
            base         = pr.UIntBE,
            mode         = 'RW',
            enum         = {
                0: 'Global',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'TriggerModeReg',
            description  = 'Select camera sync mode.',
            offset       = 0x8128,
            base         = pr.UIntBE,
            bitSize      = 8,
            bitOffset    = 24,
            mode         = 'RW',
            enum         = {
                0: 'TriggerModeOff',
                1: 'TriggerModeOn',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'TriggerSelectorReg',
            description  = 'Selects the type of trigger to configure.',
            offset       = 0x8128,
            base         = pr.UIntBE,
            bitSize      = 8,
            bitOffset    = 16,
            mode         = 'RW',
            enum         = {
                0: 'ExposureStart',
                1: 'ExposureActive',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'TriggerSourceReg',
            description  = 'Specifies the internal signal or physical input Line to use as the trigger source. The selected trigger must have its TriggerMode set to On.',
            offset       = 0x8128,
            base         = pr.UIntBE,
            bitSize      = 8,
            bitOffset    = 8,
            mode         = 'RW',
            enum         = {
                0: 'GPIO0',
                1: 'GPIO1',
                2: 'GPIO2',
                5: 'SWTRIGGER',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'CTRLReg_fan',
            description  = 'Turn camera fan on/off.',
            offset       = 0x8180,
            base         = pr.UIntBE,
            bitSize      = 8,
            bitOffset    = 16,
            mode         = 'RW',
            enum         = {
                0: 'FanOff',
                1: 'FanOn',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'CTRLReg_led',
            description  = 'Turn CXP LEDs on/off.',
            offset       = 0x8180,
            base         = pr.UIntBE,
            bitSize      = 8,
            bitOffset    = 8,
            mode         = 'RW',
            enum         = {
                0: 'LEDOff',
                1: 'LEDOn',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'TimeStampSetReg',
            description  = 'Set camera time by entering current time in seconds since January 1st, 1970.',
            offset       = 0x8188,
            base         = pr.UIntBE,
            mode         = 'WO',
            hidden       = True,
        ))

        self.add(pr.RemoteVariable(
            name         = 'LensApertureReg',
            description  = 'Lens Aperture.',
            offset       = 0x81A0,
            base         = pr.UIntBE,
            mode         = 'RW',
            enum         = {
                0: 'undefined',
                10: 'f10',
                12: 'f12',
                14: 'f14',
                18: 'f18',
                20: 'f20',
                24: 'f24',
                28: 'f28',
                33: 'f33',
                40: 'f40',
                48: 'f48',
                56: 'f56',
                67: 'f67',
                80: 'f80',
                96: 'f96',
                110: 'f110',
                132: 'f132',
                160: 'f160',
                192: 'f192',
                220: 'f220',
                264: 'f264',
                320: 'f320',
                384: 'f384',
                480: 'f480',
                576: 'f576',
                640: 'f640',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'LensApertureMinReg',
            description  = 'Minimum value for LensApertureReg',
            offset       = 0x81A4,
            base         = pr.UIntBE,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LensApertureMaxReg',
            description  = 'Maximum value for LensApertureReg',
            offset       = 0x81A8,
            base         = pr.UIntBE,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LensFocusReg',
            description  = 'Set Lens Focus',
            offset       = 0x81AC,
            base         = pr.UIntBE,
            mode         = 'WO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LensFocusStepReg',
            description  = 'Set Lens Focus Step',
            offset       = 0x81B0,
            base         = pr.UIntBE,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LensShutterReg',
            description  = 'Camera Shutter Open/Close',
            offset       = 0x81B4,
            base         = pr.UIntBE,
            mode         = 'RW',
            enum         = {
                0: 'Open',
                1: 'Close',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'GainSelectorReg',
            description  = 'Selects which Gain is controlled by the various Gain features',
            offset       = 0x80E4,
            base         = pr.UIntBE,
            mode         = 'RW',
            enum         = {
                0: 'undefined',
                20: 'DigitalAll',
                21: 'DigitalRed',
                22: 'DigitalGreen',
                23: 'DigitalBlue',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'GainReg',
            description  = 'Controls the selected gain as an absolute physical value. This is an amplification factor applied to the video signal.',
            offset       = 0x80E8,
            base         = pr.UIntBE,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'BlackLevelSelectorReg',
            description  = 'Selects which Black Level is controlled by the various Black Level features.',
            offset       = 0x80F8,
            base         = pr.UIntBE,
            mode         = 'RW',
            enum         = {
                0: 'All',
                1: 'Red',
                2: 'Green',
                3: 'Blue',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'BlackLevelReg',
            description  = 'Controls the analog black level as an absolute physical value. This represents a DC offset applied to the video signal.',
            offset       = 0x80FC,
            base         = pr.UIntBE,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'BalanceWhiteAutoReg',
            description  = 'Controls the mode for automatic white balancing between the color channels.',
            offset       = 0x80DC,
            base         = pr.UIntBE,
            mode         = 'RW',
            enum         = {
                0: 'Off',
                1: 'Once',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'BalanceWhiteMarkerReg',
            description  = 'Auto White Balance Marker.',
            offset       = 0x80E0,
            base         = pr.UIntBE,
            mode         = 'RW',
            enum         = {
                0: 'Off',
                1: 'On',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'FlatFieldCorrectionReg',
            description  = 'Turn Flat Field Correction on/off',
            offset       = 0x81B8,
            base         = pr.UIntBE,
            mode         = 'RW',
            enum         = {
                0: 'Off',
                1: 'On',
            },
        ))

        self.add(pr.RemoteCommand(
            name         = 'GainBlackLevelResetReg',
            description  = 'Set camera gain and black level to default.',
            offset       = 0x8208,
            base         = pr.UIntBE,
            function     = lambda cmd: cmd.post(1),
        ))

        self.add(pr.RemoteVariable(
            name         = 'OutputRawImageReg',
            description  = 'Grab raw images',
            offset       = 0x820C,
            base         = pr.UIntBE,
            mode         = 'RW',
            enum         = {
                0: 'Off',
                1: 'Once',
            },
        ))

        for i in range(3):
            self.add(pr.RemoteVariable(
                name         = f'DigitalIOReg[{i}]',
                description  = 'Selects the physical line (or pin) of the external device connector or the virtual line of the Transport Layer to configure.',
                offset       = 0x8198,
                base         = pr.UIntBE,
                bitSize      = 8,
                bitOffset    = 24-(i*8),
                mode         = 'RW',
                enum         = {
                    0:  'EventIn',
                    3:  'MemGate',
                    6:  'UserIn',
                    16: 'Strobe',
                    17: 'TriggerOut',
                    18: 'Ready',
                    21: 'SWTrigger',
                    22: 'TimecodeOut',
                    31: 'UserOut',
                },
            ))

        self.add(pr.RemoteVariable(
            name         = 'UserOutputSetReg',
            description  = 'Set user output high/low.',
            offset       = 0x8200,
            base         = pr.UIntBE,
            mode         = 'RW',
            enum         = {
                0: 'Low',
                1: 'High',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'UserInputStatusReg',
            description  = 'Displays state of user input GPIO line.',
            offset       = 0x8204,
            base         = pr.UIntBE,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'LinkNumberReg',
            description  = 'Bootstrap register Banks.',
            offset       = 0x8184,
            base         = pr.UIntBE,
            mode         = 'RW',
            enum         = {
                0: 'Banks_A',
                1: 'Banks_AB',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'ConnectedBankIDReg',
            description  = 'Connected Bank ID',
            offset       = 0x80D8,
            base         = pr.UIntBE,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'EventRefreshReg',
            description  = 'Refresh rate (ms) of CXP events. 0 = Events Off',
            offset       = 0x827C,
            base         = pr.UIntBE,
            mode         = 'RW',
            units        = 'ms',
        ))

        self.add(pr.RemoteVariable(
            name         = 'ComplianceTestReg',
            description  = 'Bootstrap Compliance Test',
            offset       = 0x8210,
            base         = pr.UIntBE,
            mode         = 'RW',
            enum         = {
                0:          'Disable',
                0x00010028: 'ComplianceTest1G',
                0x00010030: 'ComplianceTest2G',
                0x00010038: 'ComplianceTest3G',
                0x00010040: 'ComplianceTest5G',
                0x00010048: 'ComplianceTest6G',
            },
        ))

        # self.add(pr.RemoteVariable(
            # name         = 'UserSerialTxReg',
            # description  = 'FOR User Serial Rx/Tx',
            # offset       = 0x8148,
            # base         = pr.UIntBE,
            # mode         = 'RW',
            # hidden       = True,
        # ))

        # self.add(pr.RemoteVariable(
            # name         = 'UserSerialRxReg',
            # description  = 'FOR User Serial Rx/Tx',
            # offset       = 0x8154,
            # base         = pr.UIntBE,
            # mode         = 'RO',
            # hidden       = True,
        # ))

        # self.add(pr.RemoteVariable(
            # name         = 'UserSerialBaudRateReg',
            # description  = 'FOR User Serial Rx/Tx',
            # offset       = 0x8164,
            # base         = pr.UIntBE,
            # mode         = 'RW',
            # hidden       = True,
        # ))

        # self.add(pr.RemoteVariable(
            # name         = 'FactorySerialTxReg',
            # description  = 'FOR Factory Serial Rx/Tx',
            # offset       = 0x8140,
            # base         = pr.UIntBE,
            # mode         = 'RW',
            # hidden       = True,
        # ))

        # self.add(pr.RemoteVariable(
            # name         = 'FactorySerialRxReg',
            # description  = 'FOR Factory Serial Rx/Tx',
            # offset       = 0x8144,
            # base         = pr.UIntBE,
            # mode         = 'RO',
            # hidden       = True,
        # ))

        # self.add(pr.RemoteVariable(
            # name         = 'FactorySerialUpdateReg',
            # description  = 'FOR Factory Serial Rx/Tx',
            # offset       = 0x8130,
            # base         = pr.UIntBE,
            # mode         = 'RW',
            # hidden       = True,
        # ))

        self.add(pr.RemoteVariable(
            name         = 'DeviceFeaturesMaskReg',
            description  = 'Device Features, set by loader - LSB to MSB: shtr, eos, mroi, ffc',
            offset       = 0x81BC,
            base         = pr.UIntBE,
            mode         = 'RW',
            hidden       = True,
        ))
