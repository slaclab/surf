#-----------------------------------------------------------------------------
# Title      : Serialized DDR ADC readout
#-----------------------------------------------------------------------------
# Description:
# PyRogue model for the normalized AdcDdr capture and monitoring register map.
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

from typing import Any, Literal, Mapping, Sequence

import pyrogue as pr

import surf.devices.analog_devices as analog_devices


AdcDdrDeviceFamily = Literal['7SERIES', 'ULTRASCALE', 'ULTRASCALE_PLUS']


def adcDdrDelayBits(deviceFamily: AdcDdrDeviceFamily) -> int:
    """Return the native input-delay width for an FPGA device family.

    Parameters
    ----------
    deviceFamily : {'7SERIES', 'ULTRASCALE', 'ULTRASCALE_PLUS'}
        FPGA device family selected by RTL ``DEVICE_FAMILY_G``.

    Returns
    -------
    int
        Five for 7-Series or nine for UltraScale and UltraScale+.

    Raises
    ------
    ValueError
        If ``deviceFamily`` is not supported by the AdcDdr PHY.
    """

    try:
        return {
            '7SERIES': 5,
            'ULTRASCALE': 9,
            'ULTRASCALE_PLUS': 9,
        }[deviceFamily]
    except KeyError as exc:
        raise ValueError(
            'deviceFamily must be 7SERIES, ULTRASCALE, or ULTRASCALE_PLUS') from exc


def _formatDebugSnapshot(samples: Sequence[int], sampleBits: int) -> str:
    """Format one debug snapshot as grouped hexadecimal ADC samples."""

    width = (sampleBits+3)//4
    mask = (1 << sampleBits)-1
    return '0x' + '_'.join(f'{sample & mask:0{width}X}' for sample in samples)


def _convertDebugVoltage(
        sample: int,
        sampleBits: int,
        inputRange: float,
        offsetBinary: bool) -> float:
    """Convert one ADC code to a signed voltage."""

    modulus = 1 << sampleBits
    sign = 1 << (sampleBits-1)
    mask = modulus-1
    code = sample & mask
    if offsetBinary:
        signed = code-sign
    elif code & sign:
        signed = code-modulus
    else:
        signed = code
    return inputRange*signed/modulus


class AdcDdr(pr.Device):
    """PyRogue model for a normalized serialized DDR ADC readout.

    Parameters
    ----------
    dataLanes : int, optional
        Number of serialized ADC data lanes.
    fcoLanes : int, optional
        Number of serialized frame-clock lanes.
    channels : int, optional
        Number of logical ADC channels.
    sampleBits : int, optional
        Number of meaningful bits in each ADC sample.
    serializationFactor : int, optional
        Number of serialized bits captured per data lane.
    delayBits : int, optional
        Width of each programmable input-delay value.
    **kwargs : Any
        Additional arguments forwarded to ``pyrogue.Device``.
    """

    def _getDataDelays(self, read: bool) -> list[int]:
        """Return all data-lane delay values."""

        return [int(delay) for delay in self.DataDelayBulk.get(read=read)]

    def _setDataDelays(self, values: Mapping[int, int]) -> None:
        """Set and verify a collection of data-lane delay values."""

        for lane, value in sorted(values.items()):
            self.DataDelayBulk.set(value, index=lane, write=False)
        self.writeAndVerifyBlocks(
            recurse  = False,
            variable = self.DataDelayBulk)

    def _getDebugSamples(self, read: bool) -> list[list[int]]:
        """Return four debug samples for every logical channel."""

        flat = self.DebugSampleRaw.get(read=read)
        return [
            [int(sample) for sample in flat[4*channel:4*(channel+1)]]
            for channel in range(self._channels)
        ]

    def _snapshot(self, cmd: Any) -> list[str]:
        """Trigger and format one coherent debug snapshot."""

        cmd.set(1)
        self._getDebugSamples(read=True)
        return [
            self.nodes[f'DebugSample[{channel}]'].get(read=False)
            for channel in range(self._channels)
        ]

    def __init__(self, *,
            dataLanes: int           = 8,
            fcoLanes: int            = 1,
            channels: int            = 8,
            sampleBits: int          = 14,
            serializationFactor: int = 14,
            delayBits: int           = 5,
            **kwargs: Any) -> None:
        """Create the normalized ADC readout model."""

        for name, value, minimum, maximum in (
                ('dataLanes', dataLanes, 1, 64),
                ('fcoLanes', fcoLanes, 1, 16),
                ('channels', channels, 1, 16),
                ('sampleBits', sampleBits, 2, 16),
                ('serializationFactor', serializationFactor, 1, 16),
                ('delayBits', delayBits, 1, 9)):
            if not minimum <= value <= maximum:
                raise ValueError(f'{name} must be from {minimum} through {maximum}')

        kwargs.setdefault('description', 'Serialized DDR ADC capture and monitoring')
        super().__init__(**kwargs)

        self._dataLanes = dataLanes
        self._fcoLanes = fcoLanes
        self._channels = channels
        self._sampleBits = sampleBits
        self._serializationFactor = serializationFactor
        self._delayBits = delayBits

        self.add(pr.RemoteVariable(
            name        = 'Version',
            description = 'Normalized AdcDdr register-map version',
            offset      = 0x000,
            bitSize     = 32,
            mode        = 'RO',
            base        = pr.UInt,
            disp        = '{:#010x}'))

        self.add(pr.RemoteVariable(
            name        = 'DataLanes',
            description = 'Number of serialized ADC data lanes',
            offset      = 0x004,
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            base        = pr.UInt,
            disp        = '{:d}',
            hidden      = True))

        self.add(pr.RemoteVariable(
            name        = 'FcoLanes',
            description = 'Number of serialized ADC frame-clock lanes',
            offset      = 0x004,
            bitSize     = 8,
            bitOffset   = 8,
            mode        = 'RO',
            base        = pr.UInt,
            disp        = '{:d}',
            hidden      = True))

        self.add(pr.RemoteVariable(
            name        = 'Channels',
            description = 'Number of logical ADC channels',
            offset      = 0x004,
            bitSize     = 8,
            bitOffset   = 16,
            mode        = 'RO',
            base        = pr.UInt,
            disp        = '{:d}',
            hidden      = True))

        self.add(pr.RemoteVariable(
            name        = 'SampleBits',
            description = 'Number of meaningful bits in each ADC sample',
            offset      = 0x004,
            bitSize     = 8,
            bitOffset   = 24,
            mode        = 'RO',
            base        = pr.UInt,
            disp        = '{:d}',
            hidden      = True))

        self.add(pr.RemoteVariable(
            name        = 'DelayBits',
            description = 'Width of each programmable input-delay value',
            offset      = 0x008,
            bitSize     = 8,
            bitOffset   = 0,
            mode        = 'RO',
            base        = pr.UInt,
            disp        = '{:d}'))

        self.add(pr.RemoteVariable(
            name        = 'SerializationFactor',
            description = 'Number of serialized bits captured per data lane',
            offset      = 0x008,
            bitSize     = 8,
            bitOffset   = 8,
            mode        = 'RO',
            base        = pr.UInt,
            disp        = '{:d}',
            hidden      = True))

        self.add(pr.RemoteVariable(
            name        = 'PatternCheck',
            description = 'Hardware pattern measurement engine is present',
            offset      = 0x008,
            bitSize     = 1,
            bitOffset   = 16,
            mode        = 'RO',
            base        = pr.Bool))

        self.add(pr.RemoteVariable(
            name        = 'CaptureReset',
            description = 'Manually hold the ADC PHY and capture behavior in reset',
            offset      = 0x00C,
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RW',
            base        = pr.Bool))

        self.add(pr.RemoteCommand(
            name        = 'Relock',
            description = 'Restart FCO word alignment without changing delays',
            offset      = 0x010,
            bitSize     = 1,
            bitOffset   = 0,
            function    = pr.RemoteCommand.touchOne))

        self.add(pr.LocalVariable(
            name        = 'DebugVoltageRange',
            description = 'Differential full-scale input range used for debug voltage conversion',
            value       = 2.0,
            minimum     = 0.0,
            units       = 'V',
            disp        = '{:1.6f}',
            mode        = 'RW'))

        self.add(pr.LocalVariable(
            name        = 'DebugVoltageFormat',
            description = 'ADC output coding used for debug voltage conversion',
            value       = 1,
            enum        = {
                0: 'Offset Binary',
                1: 'Twos Complement',
            },
            mode        = 'RW'))

        self.add(pr.RemoteCommand(
            name        = 'Snapshot',
            description = 'Block until four coherent debug samples are captured, then read them',
            offset      = 0x014,
            bitSize     = 1,
            bitOffset   = 0,
            function    = self._snapshot))

        self.add(pr.RemoteCommand(
            name        = 'ClearCounters',
            description = 'Clear event counters and sticky overflow status',
            offset      = 0x018,
            bitSize     = 1,
            bitOffset   = 0,
            function    = pr.RemoteCommand.touchOne))

        self.add(pr.RemoteVariable(
            name        = 'DelayReady',
            description = 'Input-delay controller is ready; low holds the capture PHY in reset',
            offset      = 0x01C,
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RO',
            base        = pr.Bool))

        self.add(pr.RemoteVariable(
            name        = 'AllLocked',
            description = 'All FCO lanes are word aligned',
            offset      = 0x01C,
            bitSize     = 1,
            bitOffset   = 2,
            mode        = 'RO',
            base        = pr.Bool))

        self.add(pr.RemoteVariable(
            name        = 'AnyOverflow',
            description = 'One or more coherent samples were dropped',
            offset      = 0x01C,
            bitSize     = 1,
            bitOffset   = 3,
            mode        = 'RO',
            base        = pr.Bool))

        self.add(pr.RemoteVariable(
            name      = 'LockedMask',
            offset    = 0x020,
            bitSize   = fcoLanes,
            mode      = 'RO',
            base      = pr.UInt,
            disp      = '{:#x}'))

        self.add(pr.RemoteVariable(
            name        = 'SnapshotSequence',
            description = 'Completed atomic debug-snapshot count',
            offset      = 0x024,
            bitSize     = 32,
            mode        = 'RO',
            base        = pr.UInt,
            disp        = '{:d}'))

        self.add(analog_devices.AdcDdrPatternTester(
            name       = 'PatternTester',
            offset     = 0x800,
            channels   = channels,
            fcoLanes   = fcoLanes,
            sampleBits = sampleBits,
            expand     = False))

        self.add(pr.RemoteVariable(
            name        = 'DataDelayBulk',
            description = 'Array of programmed input-delay values for all serialized data lanes',
            offset      = 0x100,
            bitSize     = 32*dataLanes,
            valueBits   = delayBits,
            numValues   = dataLanes,
            valueStride = 32,
            mode        = 'RW',
            base        = pr.UInt,
            disp        = '{:d}',
            minimum     = 0,
            maximum     = (1 << delayBits) - 1,
            hidden      = True))

        for lane in range(dataLanes):
            self.add(pr.LinkVariable(
                name        = f'DataDelay[{lane}]',
                description = f'Programmed input-delay value for serialized data lane {lane}',
                variable    = self.DataDelayBulk,
                linkedGet   = lambda read, check, lane=lane: self.DataDelayBulk.get(
                    index=lane, read=read, check=check),
                linkedSet   = lambda value, write, verify, check, lane=lane:
                    self.DataDelayBulk.set(
                        value,
                        index=lane,
                        write=write,
                        verify=verify,
                        check=check)))

        self.addRemoteVariables(
            name        = 'FcoDelay',
            description = 'Programmed input-delay value for each FCO lane',
            number      = fcoLanes,
            stride      = 4,
            offset      = 0x200,
            bitSize     = delayBits,
            mode        = 'RW',
            base        = pr.UInt,
            disp        = '{:d}',
            minimum     = 0,
            maximum     = (1 << delayBits) - 1)

        self.addRemoteVariables(
            name        = 'FcoWord',
            description = 'Most recent deserialized FCO word',
            number      = fcoLanes,
            stride      = 4,
            offset      = 0x300,
            bitSize     = serializationFactor,
            mode        = 'RO',
            base        = pr.UInt,
            disp        = '{:#x}')

        self.addRemoteVariables(
            name        = 'LostLockCount',
            number      = fcoLanes,
            stride      = 4,
            offset      = 0x340,
            bitSize     = 32,
            mode        = 'RO',
            base        = pr.UInt,
            disp        = '{:d}')

        self.add(pr.RemoteVariable(
            name        = 'OverflowCount',
            description = 'Saturating coherent sample-group FIFO overflow count',
            offset      = 0x500,
            bitSize     = 32,
            mode        = 'RO',
            base        = pr.UInt,
            disp        = '{:d}'))

        self.add(pr.RemoteVariable(
            name        = 'DebugSampleRaw',
            description = (
                'Flattened channel-major raw pre-format atomic samples; '
                'four oldest-to-newest samples per logical channel'),
            offset      = 0x600,
            bitSize     = 32*4*channels,
            valueBits   = sampleBits,
            numValues   = 4*channels,
            valueStride = 32,
            mode        = 'RO',
            base        = pr.UInt,
            disp        = '{:#x}',
            hidden      = True))

        for channel in range(channels):
            self.add(pr.LinkVariable(
                name         = f'DebugSample[{channel}]',
                description  = (
                    f'Raw pre-format atomic samples for logical channel {channel}; '
                    'oldest to newest'),
                mode         = 'RO',
                dependencies = [self.DebugSampleRaw],
                linkedGet    = lambda read, channel=channel: _formatDebugSnapshot(
                    self._getDebugSamples(read=read)[channel], sampleBits)))

        for channel in range(channels):
            self.add(pr.LinkVariable(
                name         = f'DebugVoltage[{channel}]',
                description  = f'Differential input voltage for logical channel {channel}',
                mode         = 'RO',
                units        = 'V',
                disp         = '{:1.6f}',
                dependencies = [
                    self.DebugSampleRaw,
                    self.DebugVoltageRange,
                    self.DebugVoltageFormat,
                ],
                linkedGet    = lambda read, channel=channel: _convertDebugVoltage(
                    self._getDebugSamples(read=read)[channel][0],
                    sampleBits,
                    self.DebugVoltageRange.get(read=read),
                    self.DebugVoltageFormat.get(read=read) == 0)))
