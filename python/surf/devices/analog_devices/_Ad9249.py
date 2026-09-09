#-----------------------------------------------------------------------------
# Title      : PyRogue AD9249 model
#-----------------------------------------------------------------------------
# Description:
# AD9249 configuration, readout, and calibration models.
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

import math
from typing import Any

import pyrogue as pr

import surf.devices.analog_devices as analog_devices

class Ad9249ConfigGroup(pr.Device):
    """Configuration registers for one eight-channel AD9249 bank.

    Parameters
    ----------
    description : str, optional
        PyRogue device description.
    **kwargs : Any
        Additional arguments forwarded to ``pyrogue.Device``.
    """

    def __init__(
            self,
            description: str = 'Configure one side of an AD9249 ADC',
            **kwargs: Any) -> None:
        """Create one AD9249 bank configuration model."""

        super().__init__(description=description, **kwargs)

        # AD9249 bank configuration registers
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
            name        = 'DevIndexMask_DataCh[0]',
            description = 'Device index mask for data channel bank 0',
            offset      = 0x10,
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RW',
            disp        = '{:#b}',
        ))

        self.add(pr.RemoteVariable(
            name        = 'DevIndexMask_DataCh[1]',
            description = 'Device index mask for data channel bank 1',
            offset      = 0x14,
            bitSize     = 4,
            bitOffset   = 0,
            mode        = 'RW',
            disp        = '{:#b}',
        ))

        self.add(pr.RemoteVariable(
            name        = 'DevIndexMask_FCO',
            description = 'Device index mask for the frame clock output (FCO)',
            offset      = 0x14,
            bitSize     = 1,
            bitOffset   = 4,
            mode        = 'RW',
            disp        = '{:#b}',
        ))

        self.add(pr.RemoteVariable(
            name        = 'DevIndexMask_DCO',
            description = 'Device index mask for the data clock output (DCO)',
            offset      = 0x14,
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

        self.add(pr.RemoteCommand(
            name        = 'DeviceUpdate',
            description = 'Transfers the resolution/sample-rate override into the ADC',
            offset      = (0xFF*4),
            function    = pr.BaseCommand.touchOne,
        ))

        self.add(pr.RemoteVariable(
            name        = 'ResolutionSampleRateOverride',
            description = 'Enables the resolution and maximum sample-rate override',
            offset      = (0x100*4),
            bitSize     = 1,
            bitOffset   = 6,
            base        = pr.Bool,
        ))

        self.add(pr.RemoteVariable(
            name        = 'Resolution',
            description = 'Selects ADC resolution when the override is enabled',
            offset      = (0x100*4),
            bitSize     = 2,
            bitOffset   = 4,
            enum        = {
                0b00: 'Default (14 bits)',  # power-up/reset value; effective 14-bit
                0b01: '14 bits',
                0b10: '12 bits',
            },
        ))

        self.add(pr.RemoteVariable(
            name        = 'SampleRate',
            description = 'Selects maximum ADC sample rate when the override is enabled',
            offset      = (0x100*4),
            bitSize     = 3,
            bitOffset   = 0,
            enum        = {
                0b000: '20 MSPS',
                0b001: '40 MSPS',
                0b010: '50 MSPS',
                0b011: '65 MSPS',
            },
        ))

        analog_devices.addAdcDdrResetCommands(
            self, self.InternalPdwnMode, self.ResetPNLongReg)

    def writeBlocks(self, **kwargs: Any) -> None:
        """Write pending blocks and transfer them into the ADC."""
        super().writeBlocks(**kwargs)
        self.DeviceUpdate()

class Ad9249ChipConfig(pr.Device):
    """Configuration model containing both banks of one AD9249.

    Parameters
    ----------
    name : str, optional
        PyRogue device name.
    description : str, optional
        PyRogue device description.
    **kwargs : Any
        Additional arguments forwarded to ``pyrogue.Device``.
    """

    def __init__(
            self,
            name: str = 'Ad9249ChipConfig',
            description: str = 'Configure one side of an AD9249 ADC',
            **kwargs: Any) -> None:
        """Create the two-bank configuration model."""

        super().__init__(name=name, description=description, **kwargs)
        self.add(Ad9249ConfigGroup(name='BankConfig[0]', offset=0x0000))
        self.add(Ad9249ConfigGroup(name='BankConfig[1]', offset=0x0200))

class Ad9249Config(pr.Device):
    """Configuration model for one or more AD9249 devices.

    Parameters
    ----------
    name : str, optional
        PyRogue device name.
    description : str, optional
        PyRogue device description.
    chips : int, optional
        Number of AD9249 devices represented by the firmware register map.
    **kwargs : Any
        Additional arguments forwarded to ``pyrogue.Device``.
    """

    def __init__(
            self,
            name: str = 'Ad9249Config',
            description: str = 'Configuration of Ad9249 ADC',
            chips: int = 1,
            **kwargs: Any) -> None:
        """Create the AD9249 configuration model."""

        super().__init__(name=name, description=description, **kwargs)

        PDWN_ADDR = int(pow(2,11+math.log(chips*2,2)))

        # First add all of the power down GPIOs
        if chips == 1:
            self.add(pr.RemoteVariable(
                name        = 'Pdwn',
                description = 'Power down chip ',
                offset      = PDWN_ADDR,
                bitSize     = 1,
                bitOffset   = 0,
                base        = pr.Bool,
                mode        = 'RW',
            ))
            self.add(Ad9249ConfigGroup(name='BankConfig[0]', offset=0x0000))
            self.add(Ad9249ConfigGroup(name='BankConfig[1]', offset=0x0800))
        else:
            for i in range(chips):
                self.add(pr.RemoteVariable(
                    name        = f'Pdwn{i}',
                    description = f'Power down chip {i}',
                    offset      = PDWN_ADDR + (i*4),
                    bitSize     = 1,
                    bitOffset   = 0,
                    base        = pr.Bool,
                    mode        = 'RW',
                ))
                self.add(Ad9249ConfigGroup(name=f'Ad9249ChipBankConfig0[{i}]', offset=i*0x1000))
                self.add(Ad9249ConfigGroup(name=f'Ad9249ChipBankConfig1[{i}]', offset=i*0x1000+0x0800))

class Ad9249ReadoutBank(analog_devices.AdcDdr):
    """Normalized register model for one eight-channel AD9249 output bank.

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
            numChannels: int = 8,
            patternCheck: bool = True,
            **kwargs: Any) -> None:
        """Create one normalized AD9249 bank readout.

        ``numChannels`` must match the RTL ``NUM_CHANNELS_G`` generic; the
        firmware only implements delay/data registers for the instantiated
        lanes, so reading a wider map returns an AXI decode error.
        """

        delayBits = analog_devices.adcDdrDelayBits(deviceFamily)
        kwargs.setdefault('description', 'One normalized AD9249 output bank')
        super().__init__(
            dataLanes           = numChannels,
            fcoLanes            = 1,
            channels            = numChannels,
            sampleBits          = 14,
            serializationFactor = 14,
            delayBits           = delayBits,
            patternCheck        = patternCheck,
            **kwargs)


class Ad9249ReadoutBankCalibration(analog_devices.AdcDdrCalibration):
    """Calibration process for one normalized AD9249 output bank.

    Parameters
    ----------
    config : Ad9249ConfigGroup
        Configuration device for the corresponding ADC bank.
    readout : Ad9249ReadoutBank
        Normalized readout to calibrate.
    **kwargs : Any
        Additional arguments forwarded to ``AdcDdrCalibration``.
    """

    def __init__(
            self,
            *,
            config: Ad9249ConfigGroup,
            readout: Ad9249ReadoutBank,
            **kwargs: Any) -> None:
        """Create one AD9249 bank calibration process."""

        if not isinstance(config, Ad9249ConfigGroup):
            raise TypeError('config must be an Ad9249ConfigGroup')
        if not isinstance(readout, Ad9249ReadoutBank):
            raise TypeError('readout must be an Ad9249ReadoutBank')
        super().__init__(
            config            = config,
            readout           = readout,
            dataLaneToChannel = tuple(range(readout._dataLanes)),
            **kwargs)


class Ad9249Readout(pr.Device):
    """Full AD9249 readout containing two independent normalized banks.

    Parameters
    ----------
    deviceFamily : {'7SERIES', 'ULTRASCALE', 'ULTRASCALE_PLUS'}, optional
        FPGA device family selected by RTL ``DEVICE_FAMILY_G``.
    patternCheck : bool, optional
        Whether RTL ``PATTERN_CHECK_G`` includes the hardware pattern tester.
    **kwargs : Any
        Additional arguments forwarded to ``pyrogue.Device``.
    """

    def __init__(
            self,
            *,
            deviceFamily: analog_devices.AdcDdrDeviceFamily = 'ULTRASCALE',
            patternCheck: bool = True,
            **kwargs: Any) -> None:
        """Create the complete normalized AD9249 readout."""

        analog_devices.adcDdrDelayBits(deviceFamily)
        kwargs.setdefault('description', 'Complete normalized 16-channel AD9249 readout')
        super().__init__(**kwargs)

        for i in range(2):
            self.add(Ad9249ReadoutBank(
                name         = f'Bank[{i}]',
                offset       = 0x1000*i,
                deviceFamily = deviceFamily,
                patternCheck = patternCheck))


class Ad9249ReadoutCalibration(pr.Device):
    """Container for both AD9249 bank calibration processes.

    Parameters
    ----------
    config : Ad9249Config
        Configuration device containing both ADC banks.
    readout : Ad9249Readout
        Complete normalized AD9249 readout.
    **kwargs : Any
        Additional arguments forwarded to ``pyrogue.Device``.
    """

    def __init__(
            self,
            *,
            config: Ad9249Config,
            readout: Ad9249Readout,
            **kwargs: Any) -> None:
        """Create both AD9249 bank calibration processes."""

        if not isinstance(config, Ad9249Config):
            raise TypeError('config must be an Ad9249Config')
        if not isinstance(readout, Ad9249Readout):
            raise TypeError('readout must be an Ad9249Readout')
        kwargs.setdefault('description', 'Calibration processes for both AD9249 output banks')
        super().__init__(**kwargs)

        for bank in range(2):
            self.add(Ad9249ReadoutBankCalibration(
                name    = f'Bank[{bank}]',
                config  = config.BankConfig[bank],
                readout = readout.Bank[bank]))
