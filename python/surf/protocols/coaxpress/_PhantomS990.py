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

import surf.protocols.coaxpress as coaxpress

class PhantomS990(pr.Device):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.add(coaxpress.Bootstrap(
            offset = 0x0000_0000,
            expand = False,
        ))

        #############################################################
        # Start of manufacturer-specific register space at 0x00006000
        #############################################################

        self.add(pr.RemoteVariable(
            name         = 'DevicePhfwVersionReg',
            description  = 'Version of the firmware in the device.',
            base         = pr.UIntBE,
            offset       = 0x6174,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'DeviceSerialNumberReg',
            description  = 'Serial Number of device.',
            base         = pr.UIntBE,
            offset       = 0x6158,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'WidthMaxReg',
            description  = 'Maximum width (in pixels) of the image. The dimension is calculated after horizontal binning, decimation or any other function changing the horizontal dimension of the image.',
            base         = pr.UIntBE,
            offset       = 0x6010,
            bitSize      = 16,
            bitOffset    = 16,
            mode         = 'RO',
            units        = 'pixels',
        ))

        self.add(pr.RemoteVariable(
            name         = 'WidthReg',
            description  = 'This feature represents the actual image width expelled by the camera (in pixels).',
            base         = pr.UIntBE,
            offset       = 0x6000,
            mode         = 'RW',
            units        = 'pixels',
        ))

        self.add(pr.RemoteVariable(
            name         = 'HeightMaxReg',
            description  = 'Maximum height (in pixels) of the image. This dimension is calculated after vertical binning, decimation or any other function changing the vertical dimension of the image.',
            base         = pr.UIntBE,
            offset       = 0x6010,
            bitSize      = 16,
            bitOffset    = 0,
            mode         = 'RO',
            units        = 'pixels',
        ))

        self.add(pr.RemoteVariable(
            name         = 'HeightReg',
            description  = 'This feature represents the actual image height expelled by the camera (in pixels).',
            base         = pr.UIntBE,
            offset       = 0x6004,
            mode         = 'RW',
            units        = 'pixels',
        ))

        self.add(pr.RemoteVariable(
            name         = 'PixelFormatReg',
            description  = 'This feature indicates the format of the pixel to use during the acquisition.',
            base         = pr.UIntBE,
            offset       = 0x6008,
            mode         = 'RW',
            enum         = {
                0x00000000: 'Undefined',
                0x01080001: 'Mono8',
                0x010C0047: 'Mono12',
                0x01100007: 'Mono16',
                0x0108000A: 'BayerGB8',
                0x010C0055: 'BayerGB12',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'ImageSourceReg',
            description  = 'This feature controls the image source.',
            base         = pr.UIntBE,
            offset       = 0x6120,
            mode         = 'RW',
            enum        = {
                0: 'imgsrc0',
                1: 'imgsrc1',
                2: 'imgsrc2',
                3: 'imgsrc3',
                4: 'imgsrc4',
                5: 'imgsrc5',
                6: 'imgsrc6',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'AcquisitionModeReg',
            description  = 'This feature controls the acquisition mode of the device.',
            base         = pr.UIntBE,
            offset       = 0x6018,
            mode         = 'RW',
            enum         = {
                0: 'Continuous',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'AcquisitionStartReg',
            description  = 'This feature starts the Acquisition of the device.',
            base         = pr.UIntBE,
            offset       = 0x601C,
            bitSize      = 8,
            bitOffset    = 24,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'AcquisitionStopReg',
            description  = 'This feature stops the Acquisition of the device at the end of the current Frame.',
            base         = pr.UIntBE,
            offset       = 0x6020,
            bitSize      = 8,
            bitOffset    = 24,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'pFrameRateReg',
            description  = 'Frame rate in Hz.',
            base         = pr.FloatBE,
            offset       = 0x60C0,
            mode         = 'RW',
            units        = 'Hz',
        ))

        self.add(pr.RemoteVariable(
            name         = 'pFrameRateRegMax',
            description  = 'Frame rate in Hz.',
            base         = pr.FloatBE,
            offset       = 0x60C4,
            mode         = 'RO',
            units        = 'Hz',
        ))

        self.add(pr.RemoteVariable(
            name         = 'ExposureTimeReg',
            description  = 'Sets the Exposure time (in microseconds). This controls the duration where the photosensitive cells are exposed to light.',
            base         = pr.FloatBE,
            offset       = 0x60C8,
            mode         = 'RW',
            units        = 'microseconds',
        ))

        self.add(pr.RemoteVariable(
            name         = 'pExposureTimeRegMax',
            description  = 'Sets the Exposure time (in microseconds). This controls the duration where the photosensitive cells are exposed to light.',
            base         = pr.FloatBE,
            offset       = 0x60CC,
            mode         = 'RO',
            units        = 'microseconds',
        ))

        self.add(pr.RemoteVariable(
            name         = 'ShutterModeReg',
            description  = 'Select Global or Rolling shutter mode.',
            base         = pr.UIntBE,
            offset       = 0x617C,
            mode         = 'RW',
            enum         = {
                0: 'Rolling',
                1: 'Global',
                2: 'BrightField',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'FeaturesReg',
            description  = '',
            base         = pr.UIntBE,
            offset       = 0x60EC,
            mode         = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name         = 'TriggerModeReg',
            description  = 'Select camera sync mode.',
            base         = pr.UIntBE,
            offset       = 0x6128,
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
            base         = pr.UIntBE,
            offset       = 0x6128,
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
            base         = pr.UIntBE,
            offset       = 0x6128,
            bitSize      = 8,
            bitOffset    = 8,
            mode         = 'RW',
            enum         = {
                0: 'GPIO0',
                1: 'GPIO1',
                2: 'GPIO2',
                3: 'GPIO3',
                4: 'GPIO4',
                5: 'SWTRIGGER',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'CTRLReg_fan',
            description  = 'Turn camera fan on/off.',
            base         = pr.UIntBE,
            offset       = 0x6180,
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
            base         = pr.UIntBE,
            offset       = 0x6180,
            bitSize      = 8,
            bitOffset    = 8,
            mode         = 'RW',
            enum         = {
                0: 'LEDOff',
                1: 'LEDOn',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'CTRLReg_ts',
            description  = 'Enable or disable time stamp.',
            base         = pr.UIntBE,
            offset       = 0x6180,
            bitSize      = 8,
            bitOffset    = 24,
            mode         = 'RW',
            enum         = {
                0: 'TSOff',
                1: 'TSOn',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'TimeStampSetReg',
            description  = 'Set camera time by entering current time in seconds since January 1st, 1970.',
            base         = pr.UIntBE,
            offset       = 0x6188,
            mode         = 'WO',
        ))

        for i in range(4):
            self.add(pr.RemoteVariable(
                name         = f'DigitalIOReg[{i}]',
                description  = 'Selects the physical line (or pin) of the external device connector or the virtual line of the Transport Layer to configure.',
                base         = pr.UIntBE,
                offset       = 0x6198,
                bitSize      = 8,
                bitOffset    = 24-(i*8),
                mode         = 'RW',
                enum         = {
                    0:  'eventin',
                    3:  'memgate',
                    16: 'strobe',
                    17: 'triggerout',
                    18: 'ready',
                    21: 'swtrigger',
                    22: 'tcout',
                },
            ))

        self.add(pr.RemoteVariable(
            name         = 'DigitalIOReg[4]',
            description  = 'Selects the physical line (or pin) of the external device connector or the virtual line of the Transport Layer to configure.',
            base         = pr.UIntBE,
            offset       = 0x619C,
            bitSize      = 8,
            bitOffset    = 24,
            mode         = 'RW',
            enum         = {
                0: 'eventin',
                3: 'memgate',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'DigitalIOReg[5]',
            description  = 'Selects the physical line (or pin) of the external device connector or the virtual line of the Transport Layer to configure.',
            base         = pr.UIntBE,
            offset       = 0x619C,
            bitSize      = 8,
            bitOffset    = 16,
            mode         = 'RW',
            enum         = {
                0: 'undefined',
                16: 'strobe',
                18: 'ready',
                21: 'swtrigger',
                22: 'tcout',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'LinkNumberReg',
            description  = 'Bootstrap register Banks.',
            base         = pr.UIntBE,
            offset       = 0x6184,
            mode         = 'RW',
            enum         = {
                0: 'Banks_A',
                1: 'Banks_AB',
                3: 'Banks_ABCD',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'UsermemWriteMaskReg',
            description  = 'Sets the write mask to disable to write access to User memory, whose address is greater than 0x0006000. Settng Usermem Write Mask register will only disable writing to user memory for bank whose corresponding bit in the mask set to one, bit 0 is for bank A, bit1 bank B, etc.',
            base         = pr.UIntBE,
            offset       = 0x618C,
            mode         = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name         = 'TapGeometryReg',
            description  = 'TapGeometry.',
            base         = pr.UIntBE,
            offset       = 0x600C,
            mode         = 'RW',
            enum         = {
                0: 'X1_1Y',
                1: 'X1_1Y2',
                2: 'X1_2YE',
            },
        ))

        self.add(pr.RemoteVariable(
            name         = 'Image1StreamIDReg',
            description  = 'Image1StreamID.',
            base         = pr.UIntBE,
            offset       = 0x60D8,
            mode         = 'RO',
        ))
