#-----------------------------------------------------------------------------
# This file is part of the 'SLAC Firmware Standard Library'. It is subject to
# the license terms in the LICENSE.txt file found in the top-level directory
# of this distribution and at:
#    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
# No part of 'SLAC Firmware Standard Library', including this file, may be
# copied, modified, propagated, or distributed except according to the terms
# contained in the LICENSE.txt file.
#-----------------------------------------------------------------------------

from __future__ import annotations

from typing import Any

import pyrogue as pr

import surf.devices.analog_devices as analog_devices

class Ad9252Config(pr.Device):
    """PyRogue configuration model for the AD9252 ADC.

    Parameters
    ----------
    **kwargs : Any
        Additional arguments forwarded to ``pyrogue.Device``.
    """

    def __init__(self, **kwargs: Any) -> None:
        """Create the AD9252 configuration model."""

        super().__init__(description="AD9252 ADC object.",**kwargs)


#         self.add(pr.RemoteVariable(
#             name = "ConfigEn",
#             description='Set to ''True'' to enable register writes to ADC.',
#             offset=0x00,
#             bitSize=1,
#             bitOffset=0,
#             base =pr.Bool))

        self.add(pr.RemoteVariable(
            name = "ChipId",
            description='Read only chip ID value.',
            offset=0x04,
            bitSize=8,
            bitOffset=0,
            mode = "RO"))

        self.add(pr.RemoteVariable(
            name="ChipGrade",
            description='Read only chip grade value.',
            offset=0x08,
            bitSize=3,
            bitOffset=4,
            mode="RO"))


        self.add(pr.RemoteVariable(
            name="PowerDownMode",
            description='Set power mode of device.',
            offset=0x20,
            bitSize=2,
            bitOffset=0,
            base=pr.UInt,
            enum = {
                0: "Chip Run",
                1: "Full Power Down",
                2: "Standby",
                3: "Digital Reset"}))

        self.add(pr.RemoteVariable(
            name = "DutyCycleStabilizer",
            description='Turns on internal duty cycle stabilizer. (default=True).',
            offset=0x24,
            bitSize=1,
            bitOffset=0,
            base =pr.Bool))


        self.add(pr.RemoteVariable(
            name="DevIndexMask[7:4]",
            offset=0x10,
            bitSize=4,
            bitOffset=0,
            base=pr.UInt,
            disp='{:#b}'))

        self.add(pr.RemoteVariable(
            name="DevIndexMask[3:0]",
            offset=0x14,
            bitSize=4,
            bitOffset=0,
            base=pr.UInt,
            disp='{:#b}'))

        self.add(pr.RemoteVariable(
            name="DevIndexMask[DCO:FCO]",
            offset=0x14,
            bitSize=2,
            bitOffset=0x4,
            base=pr.UInt))

        self.add(pr.RemoteVariable(
            name="OutputTestMode",
            description='Set output test mode.',
            offset=0x34,
            bitSize=4,
            bitOffset=0,
            base=pr.UInt,
            enum={
                0: "Off",
                1: "Midscale Short",
                2: "Positive FS",
                3: "Negative FS",
                4: "Alternating checkerboard",
                5: "PN23",
                6: "PN9",
                7: "1/0-word toggle",
                8: "User Input",
                9: "1/0-bit Toggle",
                10: "1x sync",
                11: "One bit high",
                12: "mixed bit frequency"}))

        self.add(pr.RemoteVariable(
            name='ResetPNShort',
            description='Reset PN short gen test mode',
            offset=0x34,
            bitSize=1,
            bitOffset=4,
            base=pr.Bool))

        self.add(pr.RemoteVariable(
            name='ResetPNLong',
            description='Reset PN long gen test mode',
            offset=0x34,
            bitSize=1,
            bitOffset=5,
            base=pr.Bool))


        self.add(pr.RemoteVariable(
            name='UserTestMode',
            description='Sets user test mode of all channels',
            offset=0x34,
            bitSize=2,
            bitOffset=6,
            base=pr.UInt,
            enum={
                0: 'Off',
                1: 'OnSingAlternate',
                2: 'OnSingleOnce',
                3: 'OnAlternateOnce'}))


        self.add(pr.RemoteVariable(
            name='OutputFormat',
            description='Set output format. binary or twos complement.',
            offset=0x50,
            bitSize=2,
            bitOffset=0,
            base=pr.UInt,
            enum={
                1: 'Twos Compliment',
                0: 'Offset Binary'}))

        self.add(pr.RemoteVariable(
            name='OutputInvert',
            description='Enable output inversion.',
            offset=0x50,
            bitSize=1,
            bitOffset=2,
            base=pr.Bool))

        self.add(pr.RemoteVariable(
            name='OutputMode',
            description='Set output mode of device. Default=LVDS.',
            offset=0x50,
            bitSize=1,
            bitOffset=6,
            base=pr.UInt,
            enum={
                0:'LVDS ANSI-644',
                1:'LVDS Low Power'}))

        self.add(pr.RemoteVariable(
            name='DcoFcoDrive2x',
            description='Set DCO and FCO output drive strength.',
            offset=0x54,
            bitSize=1,
            bitOffset=0,
            base = pr.Bool))


        self.add(pr.RemoteVariable(
            name='OutputTermDrive',
            description='Set output driver termination.',
            offset=0x54,
            bitSize=2,
            bitOffset=4,
            base = pr.UInt,
            enum={
                0:'none',
                1:'200 Ohms',
                2:'100 Ohms',
                3:'100 Ohms'}))

        self.add(pr.RemoteVariable(
            name='OutputPhase',
            description='Set output phase adjustment.',
            offset=0x58,
            bitSize=4,
            bitOffset=0,
            base = pr.UInt,
            enum={
                0:'0 deg to edge',
                1:'60 deg to edge',
                2:'120 deg to edge',
                3:'180 deg to edge',
                4:'unused1',
                5:'300 deg to edge',
                6:'360 deg to edge',
                7:'unused2',
                8:'480 deg to edge',
                9:'540 deg to edge',
                10:'600 deg to edge',
                11:'660 deg to edge'}))

#          def convPattern(raw):
#             def convert():
#                 return raw.value()
#             return convert

        self.add(pr.RemoteVariable(
            name="UserPattern1Lsb",
            offset=0x64,
            bitSize=8,
            bitOffset=0,
            base=pr.UInt))

        self.add(pr.RemoteVariable(
            name="UserPattern1Msb",
            offset=0x68,
            bitSize=8,
            bitOffset=0,
            base=pr.UInt))

        self.add(pr.RemoteVariable(
            name="UserPattern2Lsb",
            offset=0x6C,
            bitSize=8,
            bitOffset=0,
            base=pr.UInt))

        self.add(pr.RemoteVariable(
            name="UserPattern2Msb",
            offset=0x70,
            bitSize=8,
            bitOffset=0,
            base=pr.UInt))

    #     self.add(pr.LinkVariable(
#             name='UserPattern1',
#             description='Set user test pattern 1 data.',
#             linkedGet=convPattern(self.UserPattern1Raw),
#             dependencies=[self.UserPattern1Raw]))

#         self.add(pr.LinkVariable(
#             name='UserPattern2',
#             description='Set user test pattern 2 data.',
#             linkedGet=convPattern(self.UserPattern2Raw),
#             dependencies=[self.UserPattern2Raw]))

        self.add(pr.RemoteVariable(
            name='SerialBits',
            description='Set number of serial bits.',
            offset=0x84,
            bitSize=3,
            bitOffset=0,
            base = pr.UInt,
            enum={
                0:'14 bits',
                1:'8 bits',
                2:'10 bits',
                3:'12 bits',
                4:'14 bits'}))

        self.add(pr.RemoteVariable(
            name='LowEncodeRate',
            description='Set low rate less than 10mbs mode.',
            offset=0x84,
            bitSize=1,
            bitOffset=3,
            base = pr.Bool))

        self.add(pr.RemoteVariable(
            name='SerialLsbFirst',
            description='Set LSB first mode of device.',
            offset=0x84,
            bitSize=1,
            bitOffset=7,
            base = pr.Bool))


        self.add(pr.RemoteVariable(
            name='ChPowerDown',
            description='Set channel power down.',
            offset=0x88,
            bitSize=1,
            bitOffset=0,
            base = pr.Bool))

        self.add(pr.RemoteCommand(
            name='DeviceUpdate',
            description='Transfers buffered SPI register values into the ADC',
            offset=0x3FC,
            function=pr.BaseCommand.touchOne,
        ))

    def writeBlocks(self, **kwargs: Any) -> None:
        """Write pending blocks and transfer them into the ADC."""
        super().writeBlocks(**kwargs)
        self.DeviceUpdate()


class Ad9252Readout(analog_devices.AdcDdr):
    """Normalized AD9252 readout with one data lane per enabled channel.

    Parameters
    ----------
    channels : int, optional
        Number of ADC channels exposed by the firmware.
    deviceFamily : {'7SERIES', 'ULTRASCALE', 'ULTRASCALE_PLUS'}, optional
        FPGA device family selected by RTL ``DEVICE_FAMILY_G``.
    **kwargs : Any
        Additional arguments forwarded to ``AdcDdr``.
    """

    def __init__(
            self,
            *,
            channels: int = 8,
            deviceFamily: analog_devices.AdcDdrDeviceFamily = 'ULTRASCALE',
            **kwargs: Any) -> None:
        """Create the normalized AD9252 readout."""

        if not 1 <= channels <= 8:
            raise ValueError('channels must be from 1 through 8')
        delayBits = analog_devices.adcDdrDelayBits(deviceFamily)
        kwargs.setdefault('description', 'AD9252 serialized DDR readout')
        super().__init__(
            dataLanes           = channels,
            fcoLanes            = 1,
            channels            = channels,
            sampleBits          = 14,
            serializationFactor = 14,
            delayBits           = delayBits,
            **kwargs)


class Ad9252ReadoutCalibration(analog_devices.AdcDdrCalibration):
    """Calibration process for a normalized AD9252 readout.

    Parameters
    ----------
    config : Ad9252Config
        ADC configuration device.
    readout : Ad9252Readout
        Normalized readout to calibrate.
    **kwargs : Any
        Additional arguments forwarded to ``AdcDdrCalibration``.
    """

    def __init__(
            self,
            *,
            config: Ad9252Config,
            readout: Ad9252Readout,
            **kwargs: Any) -> None:
        """Create the AD9252 calibration process."""

        if not isinstance(config, Ad9252Config):
            raise TypeError('config must be an Ad9252Config')
        if not isinstance(readout, Ad9252Readout):
            raise TypeError('readout must be an Ad9252Readout')
        super().__init__(
            config            = config,
            readout           = readout,
            dataLaneToChannel = tuple(range(readout._channels)),
            configUpdate      = config.DeviceUpdate,
            pn23Reset         = config.ResetPNLong,
            **kwargs)
