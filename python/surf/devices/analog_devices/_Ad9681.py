#-----------------------------------------------------------------------------
# Title      : PyRogue AD9681 model
#-----------------------------------------------------------------------------
# Description:
# AD9681 configuration, normalized readout, and calibration models.
#-----------------------------------------------------------------------------
# This file is part of 'SLAC Firmware Standard Library'.
# It is subject to the license terms in the LICENSE.txt file found in the
# top-level directory of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of 'SLAC Firmware Standard Library', including this file,
# may be copied, modified, propagated, or distributed except according to
# the terms contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

from __future__ import annotations

from typing import Any

import pyrogue as pr

import surf.devices.analog_devices as analog_devices

class Ad9681Config(pr.Device):
    """PyRogue configuration model for the AD9681 ADC.

    Parameters
    ----------
    description : str, optional
        PyRogue device description.
    **kwargs : Any
        Additional arguments forwarded to ``pyrogue.Device``.
    """

    def __init__(
            self,
            description: str = 'Configure an AD9681 ADC',
            **kwargs: Any) -> None:
        """Create the AD9681 configuration model."""

        super().__init__(description=description, **kwargs)

        # AD9681 configuration registers
        self.add(pr.RemoteVariable(
            name        = 'ChipId',
            description = 'ADC chip identification register',
            offset      = 0x04,
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ChipGrade',
            description = 'ADC speed grade identification',
            offset      = 0x08,
            bitSize     = 3,
            bitOffset   = 4,
            mode        = 'RO',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ExternalPdwnMode',
            description = 'Selects behavior of PDWN pin (full power down or standby)',
            offset      = 0x20,
            bitSize     = 1,
            bitOffset   = 5,
            enum        = {
                0: 'Full Power Down',
                1: 'Standby',
            },
        ))

        self.add(pr.RemoteVariable(
            name        = 'InternalPdwnMode',
            description = 'Sets internal power-down mode via SPI register',
            offset      = 0x20,
            bitSize     = 2,
            bitOffset   = 0,
            enum        = {
                0: 'Chip Run',
                1: 'Full Power Down',
                2: 'Standby',
                3: 'Digital Reset',
            },
        ))

        self.add(pr.RemoteVariable(
            name        = 'DutyCycleStabilizer',
            description = 'Enables the clock duty cycle stabilizer',
            offset      = 0x24,
            bitSize     = 1,
            bitOffset   = 0,
            enum        = {
                0: 'Off',
                1: 'On',
            },
        ))

        self.add(pr.RemoteVariable(
            name        = 'ClockDivide',
            description = 'Input clock divide ratio selection',
            offset      = (0xb*4),
            bitSize     = 3,
            bitOffset   = 0,
            enum        = {i : f'Divide by {i+1}' for i in range(8)},
        ))

        self.add(pr.RemoteVariable(
            name        = 'ChopMode',
            description = 'Enables chop mode for offset cancellation',
            offset      = (0x0c*4),
            bitSize     = 1,
            bitOffset   = 2,
            enum        = {
                0: 'Off',
                1: 'On',
            },
        ))

        self.add(pr.RemoteVariable(
            name        = 'DevIndexMask_DataCh',
            description = 'Device index mask for data channels',
            offset      = 0x05 *4,
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RW',
            disp        = '{:#b}',
        ))


        self.add(pr.RemoteVariable(
            name        = 'DevIndexMask_FCO',
            description = 'Device index mask for the frame clock output (FCO)',
            offset      = 0x05 *4,
            bitSize     = 1,
            bitOffset   = 4,
            mode        = 'RW',
            disp        = '{:#b}',
        ))

        self.add(pr.RemoteVariable(
            name        = 'DevIndexMask_DCO',
            description = 'Device index mask for the data clock output (DCO)',
            offset      = 0x05 * 4,
            bitSize     = 1,
            bitOffset   = 5,
            mode        = 'RW',
            disp        = '{:#b}',
        ))

        self.add(pr.RemoteVariable(
            name        = 'UserTestModeCfg',
            description = 'Configures user-defined test pattern cycling mode',
            offset      = (0x0D*4),
            bitSize     = 2,
            bitOffset   = 6,
            enum        = {
                0: 'single',
                1: 'alternate',
                2: 'single once',
                3: 'alternate once',
            },
        ))

        self.add(pr.RemoteVariable(
            name        = 'OutputTestMode',
            description = 'Selects ADC output test pattern mode',
            offset      = (0x0D*4),
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RW',
            enum        = {
                0: 'Off',
                1: 'Midscale Short',
                2: 'Positive FS',
                3: 'Negative FS',
                4: 'Alternating checkerboard',
                5: 'PN23',
                6: 'PN9',
                7: '1/0-word toggle',
                8: 'User Input',
                9: '1/0-bit Toggle',
                10: '1x sync',
                11: 'One bit high',
                12: 'mixed bit frequency',
            },
        ))

        self.add(pr.RemoteVariable(
            name        = 'ResetPNShort',
            description = 'Reset the PN9 test-pattern generator',
            offset      = (0x0D*4),
            bitSize     = 1,
            bitOffset   = 4,
            base        = pr.Bool,
            mode        = 'RW',
        ))

        self.add(pr.RemoteVariable(
            name        = 'ResetPNLongReg',
            description = 'Reset the PN23 test-pattern generator',
            offset      = (0x0D*4),
            bitSize     = 1,
            bitOffset   = 5,
            base        = pr.Bool,
            mode        = 'RW',
            hidden      = True,
        ))

        self.add(pr.RemoteVariable(
            name        = 'OffsetAdjust',
            description = 'Output offset adjustment in LSB steps',
            offset      = (0x10*4),
            bitSize     = 8,
            bitOffset   = 0,
        ))

        self.add(pr.RemoteVariable(
            name        = 'OutputInvert',
            description = 'Inverts the ADC output data polarity',
            offset      = (0x14*4),
            bitSize     = 1,
            bitOffset   = 2,
            base        = pr.Bool,
        ))

        self.add(pr.RemoteVariable(
            name        = 'OutputFormat',
            description = 'Selects output data format (twos complement or offset binary)',
            offset      = (0x14*4),
            bitSize     = 1,
            bitOffset   = 0,
            enum        = {
                1: 'Twos Complement',
                0: 'Offset Binary',
            },
        ))

        self.add(pr.RemoteVariable(
            name        = 'OutputDriveTerm',
            description = 'LVDS output termination resistor selection',
            offset      = (0x15*4),
            bitSize     = 2,
            bitOffset   = 4,
            enum        = {
                0b00: "None",
                0b01: "200 Ohms",
                0b10: "100 Ohms",
                0b11: "101 Ohms",
            },
        ))

        self.add(pr.RemoteVariable(
            name        = 'DcoFcoDrive',
            description = 'DCO/FCO output drive strength selection',
            offset      = (0x15*4),
            bitSize     = 1,
            bitOffset   = 0,
            enum        = {
                0: "1x",
                1: "2x",
            },
        ))

        self.add(pr.RemoteVariable(
            name        = 'InputClkPhaseAdj',
            description = 'Input clock phase adjustment in clock delay steps',
            offset      = (0x16*4),
            bitSize     = 3,
            bitOffset   = 4,
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        = 'OutputClkPhaseAdj',
            description = 'Output clock (DCO) phase adjustment in delay steps',
            offset      = (0x16*4),
            bitSize     = 4,
            bitOffset   = 0,
            disp        = '{:d}',
        ))

        self.add(pr.RemoteVariable(
            name        = 'DigitalFsRangeAdj',
            description = 'Digital full-scale range adjustment for the ADC input',
            offset      = (0x18*4),
            bitSize     = 3,
            bitOffset   = 0,
            enum        = {
                0b000: '1.0 V',
                0b001: '1.14 V',
                0b010: '1.33 V',
                0b011: '1.6 V',
                0b100: '2.0 V',
            },
        ))



        self.add(pr.RemoteVariable(
            name        = 'UserPatt1Lsb',
            description = 'User-defined test pattern 1 LSB byte',
            offset      = (0x19*4),
            bitSize     = 8,
            bitOffset   = 0,
        ))

        self.add(pr.RemoteVariable(
            name        = 'UserPatt1Msb',
            description = 'User-defined test pattern 1 MSB byte',
            offset      = (0x1A*4),
            bitSize     = 8,
            bitOffset   = 0,
        ))

        self.add(pr.RemoteVariable(
            name        = 'UserPatt2Lsb',
            description = 'User-defined test pattern 2 LSB byte',
            offset      = (0x1B*4),
            bitSize     = 8,
            bitOffset   = 0,
        ))

        self.add(pr.RemoteVariable(
            name        = 'UserPatt2Msb',
            description = 'User-defined test pattern 2 MSB byte',
            offset      = (0x1C*4),
            bitSize     = 8,
            bitOffset   = 0,
        ))

        self.add(pr.RemoteVariable(
            name        = 'LvdsLsbFirst',
            description = 'Sets LVDS output bit order (LSB first when enabled)',
            offset      = (0x21*4),
            bitSize     = 1,
            bitOffset   = 7,
            base        = pr.Bool,
        ))

        self.add(pr.RemoteVariable(
            name        = 'OutputMode',
            description = 'Selects LVDS serial output mode (SDR/DDR, lane count, bit order)',
            offset      = (0x21*4),
            bitSize     = 3,
            bitOffset   = 4,
            enum        = {
                0b000: 'SDR two-lane, bitwise',
                0b001: 'SDR two-lane, bytewise',
                0b010: 'DDR two-lane, bitwise',
                0b011: 'DDR two-lane, bytewise',
                0b100: 'DDR one-lane, wordwise',
            },
        ))

        self.add(pr.RemoteVariable(
            name        = 'PllLowEncodeRateMode',
            description = 'Enables PLL low encode rate mode for slow clock operation',
            offset      = (0x21*4),
            bitSize     = 1,
            bitOffset   = 3,
            base        = pr.Bool,
        ))

        self.add(pr.RemoteVariable(
            name        = 'Select2xFrame',
            description = 'Selects 2x frame rate mode for output serialization',
            offset      = (0x21*4),
            bitSize     = 1,
            bitOffset   = 2,
            base        = pr.Bool,
        ))

        self.add(pr.RemoteVariable(
            name        = 'OutputNumBits',
            description = 'Selects ADC output word width (12 or 16 bits)',
            offset      = (0x21*4),
            bitSize     = 2,
            bitOffset   = 0,
            enum        = {
                0b00: '16 bits',
                0b10: '12 bits',
            },
        ))

        # Register 0x100 (resolution/sample-rate override) is a transfer-staged
        # register: the datasheet specifies it is not applied until the 0xFF
        # transfer strobe, and a read returns the old value until then. That
        # breaks pyrogue's immediate write-verify, and the override is not needed
        # for normal full-rate operation, so these fields are disabled for now.
        # Re-enable with verify=False (and route through DeviceUpdate) if the
        # override is ever required.
        # self.add(pr.RemoteVariable(
        #     name        = 'ResolutionSampleRateOverride',
        #     description = 'Enables the resolution and maximum sample-rate override',
        #     offset      = (0x100*4),
        #     bitSize     = 1,
        #     bitOffset   = 6,
        #     base        = pr.Bool,
        # ))

        # self.add(pr.RemoteVariable(
        #     name        = 'Resolution',
        #     description = 'Selects ADC resolution when the override is enabled',
        #     offset      = (0x100*4),
        #     bitSize     = 2,
        #     bitOffset   = 4,
        #     enum        = {
        #         0b00: 'Default (14 bits)',  # power-up/reset value; effective 14-bit
        #         0b01: '14 bits',
        #         0b10: '12 bits',
        #     },
        # ))

        # self.add(pr.RemoteVariable(
        #     name        = 'SampleRate',
        #     description = 'Selects maximum ADC sample rate when the override is enabled',
        #     offset      = (0x100*4),
        #     bitSize     = 3,
        #     bitOffset   = 0,
        #     enum        = {
        #         0b000: '20 MSPS',
        #         0b001: '40 MSPS',
        #         0b010: '50 MSPS',
        #         0b011: '65 MSPS',
        #         0b100: '80 MSPS',
        #         0b101: '105 MSPS',
        #         0b110: '125 MSPS',
        #     },
        # ))

        self.add(pr.RemoteCommand(
            name='DeviceUpdate',
            description='Transfers the resolution/sample-rate override into the ADC',
            offset=0x3FC,
            function=pr.BaseCommand.touchOne,
        ))

        analog_devices.addAdcDdrResetCommands(
            self, self.InternalPdwnMode, self.ResetPNLongReg)

    def writeBlocks(self, **kwargs: Any) -> None:
        """Write pending blocks and transfer them into the ADC."""
        super().writeBlocks(**kwargs)
        self.DeviceUpdate()


class Ad9681Readout(analog_devices.AdcDdr):
    """Normalized register model for the eight-channel AD9681 readout.

    Parameters
    ----------
    deviceFamily : {'7SERIES', 'ULTRASCALE', 'ULTRASCALE_PLUS'}, optional
        FPGA device family selected by RTL ``DEVICE_FAMILY_G``.
    patternCheck : bool, optional
        Whether RTL ``PATTERN_CHECK_G`` includes the hardware pattern tester.
    **kwargs : Any
        Additional arguments forwarded to ``AdcDdr``.
    """

    def __init__(
            self,
            *,
            deviceFamily: analog_devices.AdcDdrDeviceFamily = 'ULTRASCALE',
            patternCheck: bool = True,
            **kwargs: Any) -> None:
        """Create the normalized AD9681 readout."""

        delayBits = analog_devices.adcDdrDelayBits(deviceFamily)
        kwargs.setdefault('description', 'AD9681 serialized DDR readout')
        super().__init__(
            dataLanes           = 16,
            fcoLanes            = 2,
            channels            = 8,
            sampleBits          = 14,
            serializationFactor = 8,
            delayBits           = delayBits,
            patternCheck        = patternCheck,
            **kwargs)


class Ad9681ReadoutCalibration(analog_devices.AdcDdrCalibration):
    """Calibration process for a normalized AD9681 readout.

    Parameters
    ----------
    config : Ad9681Config
        ADC configuration device.
    readout : Ad9681Readout
        Normalized readout to calibrate.
    **kwargs : Any
        Additional arguments forwarded to ``AdcDdrCalibration``.
    """

    def __init__(
            self,
            *,
            config: Ad9681Config,
            readout: Ad9681Readout,
            **kwargs: Any) -> None:
        """Create the AD9681 calibration process."""

        if not isinstance(config, Ad9681Config):
            raise TypeError('config must be an Ad9681Config')
        if not isinstance(readout, Ad9681Readout):
            raise TypeError('readout must be an Ad9681Readout')
        super().__init__(
            config            = config,
            readout           = readout,
            dataLaneToChannel = tuple(range(8))+tuple(range(8)),
            dataLaneMasks     = (0x003F,)*8+(0x3FC0,)*8,
            **kwargs)
