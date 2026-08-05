#-----------------------------------------------------------------------------
# Title      : Serialized DDR ADC pattern tester
#-----------------------------------------------------------------------------
# Description:
# PyRogue model for the AdcDdr finite-window pattern measurement engine.
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


class AdcDdrPatternTester(pr.Device):
    """PyRogue model for the finite-window ADC pattern tester.

    Parameters
    ----------
    channels : int
        Number of logical ADC channels.
    fcoLanes : int
        Number of frame-clock lanes.
    sampleBits : int
        Number of meaningful bits in each ADC sample.
    **kwargs : Any
        Additional arguments forwarded to ``pyrogue.Device``.
    """

    def __init__(
            self,
            *,
            channels: int,
            fcoLanes: int,
            sampleBits: int,
            **kwargs: Any) -> None:
        """Create the ADC pattern-tester model."""

        for name, value, minimum, maximum in (
                ('channels', channels, 1, 16),
                ('fcoLanes', fcoLanes, 1, 16),
                ('sampleBits', sampleBits, 2, 16)):
            if not minimum <= value <= maximum:
                raise ValueError(f'{name} must be from {minimum} through {maximum}')

        kwargs.setdefault('description', 'Parallel finite-window ADC pattern measurement')
        super().__init__(**kwargs)

        self.add(pr.RemoteCommand(
            name        = 'Start',
            description = 'Start a finite pattern measurement window',
            offset      = 0x000,
            bitSize     = 1,
            bitOffset   = 0,
            function    = pr.RemoteCommand.touchOne))

        self.add(pr.RemoteCommand(
            name        = 'Abort',
            description = 'Abort the active pattern measurement window',
            offset      = 0x004,
            bitSize     = 1,
            bitOffset   = 0,
            function    = pr.RemoteCommand.touchOne))

        self.add(pr.RemoteVariable(
            name        = 'Alternating',
            description = 'Compare a shared-phase alternating A/B pattern instead of constant A',
            offset      = 0x008,
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RW',
            base        = pr.Bool))

        self.add(pr.RemoteVariable(
            name        = 'ReferenceChannel',
            description = 'Enabled logical channel used to acquire shared A/B phase',
            offset      = 0x008,
            bitSize     = 8,
            bitOffset   = 8,
            mode        = 'RW',
            base        = pr.UInt,
            disp        = '{:d}',
            minimum     = 0,
            maximum     = channels-1))

        self.add(pr.RemoteVariable(
            name        = 'ChannelMask',
            description = 'Logical channels enabled for parallel pattern comparison',
            offset      = 0x00C,
            bitSize     = channels,
            mode        = 'RW',
            base        = pr.UInt,
            disp        = '{:#x}'))

        self.add(pr.RemoteVariable(
            name        = 'FcoMask',
            description = 'FCO lanes enabled for mismatch counting',
            offset      = 0x010,
            bitSize     = fcoLanes,
            mode        = 'RW',
            base        = pr.UInt,
            disp        = '{:#x}'))

        self.add(pr.RemoteVariable(
            name        = 'DataMask',
            description = 'Sample bits included in each comparison',
            offset      = 0x014,
            bitSize     = sampleBits,
            mode        = 'RW',
            base        = pr.UInt,
            disp        = '{:#x}'))

        self.add(pr.RemoteVariable(
            name        = 'PatternA',
            description = 'Constant pattern or first alternating pattern',
            offset      = 0x018,
            bitSize     = sampleBits,
            mode        = 'RW',
            base        = pr.UInt,
            disp        = '{:#x}'))

        self.add(pr.RemoteVariable(
            name        = 'PatternB',
            description = 'Second alternating pattern',
            offset      = 0x01C,
            bitSize     = sampleBits,
            mode        = 'RW',
            base        = pr.UInt,
            disp        = '{:#x}'))

        self.add(pr.RemoteVariable(
            name        = 'Samples',
            description = 'Number of valid sample groups requested for the measurement',
            offset      = 0x020,
            bitSize     = 32,
            mode        = 'RW',
            base        = pr.UInt,
            disp        = '{:d}',
            minimum     = 1))

        self.add(pr.RemoteVariable(
            name        = 'Timeout',
            description = 'Consecutive capture clocks without sampleValid; zero disables timeout',
            offset      = 0x024,
            bitSize     = 32,
            mode        = 'RW',
            base        = pr.UInt,
            disp        = '{:d}'))

        self.add(pr.RemoteVariable(
            name        = 'Busy',
            description = 'A pattern measurement window is active',
            offset      = 0x028,
            bitSize     = 1,
            bitOffset   = 0,
            mode        = 'RO',
            base        = pr.Bool))

        self.add(pr.RemoteVariable(
            name        = 'TimedOut',
            description = 'The last window ended without sampleValid',
            offset      = 0x028,
            bitSize     = 1,
            bitOffset   = 1,
            mode        = 'RO',
            base        = pr.Bool))

        self.add(pr.RemoteVariable(
            name        = 'ConfigError',
            description = 'The last start had invalid configuration',
            offset      = 0x028,
            bitSize     = 1,
            bitOffset   = 2,
            mode        = 'RO',
            base        = pr.Bool))

        self.add(pr.RemoteVariable(
            name        = 'Aborted',
            description = 'The last window was aborted',
            offset      = 0x028,
            bitSize     = 1,
            bitOffset   = 3,
            mode        = 'RO',
            base        = pr.Bool))

        self.add(pr.RemoteVariable(
            name        = 'PhaseAcquired',
            description = 'Shared alternating-pattern phase was acquired',
            offset      = 0x028,
            bitSize     = 1,
            bitOffset   = 4,
            mode        = 'RO',
            base        = pr.Bool))

        self.add(pr.RemoteVariable(
            name        = 'AllChannelsPass',
            description = 'Every enabled logical channel passed',
            offset      = 0x028,
            bitSize     = 1,
            bitOffset   = 5,
            mode        = 'RO',
            base        = pr.Bool))

        self.add(pr.RemoteVariable(
            name        = 'AllFcoPass',
            description = 'Every enabled FCO lane was observed and had no mismatches',
            offset      = 0x028,
            bitSize     = 1,
            bitOffset   = 6,
            mode        = 'RO',
            base        = pr.Bool))

        self.add(pr.RemoteVariable(
            name        = 'Sequence',
            description = 'Completed pattern-window count including error and abort outcomes',
            offset      = 0x02C,
            bitSize     = 32,
            mode        = 'RO',
            base        = pr.UInt,
            disp        = '{:d}'))

        self.add(pr.RemoteVariable(
            name        = 'CheckedSamples',
            description = 'Valid sample groups checked by the completed or active window',
            offset      = 0x030,
            bitSize     = 32,
            mode        = 'RO',
            base        = pr.UInt,
            disp        = '{:d}'))

        self.add(pr.RemoteVariable(
            name        = 'ChannelPassed',
            description = 'One pass bit per enabled logical channel',
            offset      = 0x034,
            bitSize     = channels,
            mode        = 'RO',
            base        = pr.UInt,
            disp        = '{:#x}'))

        self.add(pr.RemoteVariable(
            name        = 'FcoPassed',
            description = 'One pass bit per observed, mismatch-free enabled FCO lane',
            offset      = 0x038,
            bitSize     = fcoLanes,
            mode        = 'RO',
            base        = pr.UInt,
            disp        = '{:#x}'))

        self.addRemoteVariables(
            name        = 'WordErrorCount',
            description = 'Saturating pattern word-error count for each logical channel',
            number      = channels,
            stride      = 4,
            offset      = 0x040,
            bitSize     = 32,
            mode        = 'RO',
            base        = pr.UInt,
            disp        = '{:d}')

        self.addRemoteVariables(
            name        = 'BitErrorMask',
            description = 'Accumulated failing sample-bit mask for each logical channel',
            number      = channels,
            stride      = 4,
            offset      = 0x080,
            bitSize     = sampleBits,
            mode        = 'RO',
            base        = pr.UInt,
            disp        = '{:#x}')

        self.addRemoteVariables(
            name        = 'FcoErrorCount',
            description = 'Saturating FCO mismatch count for each enabled FCO lane',
            number      = fcoLanes,
            stride      = 4,
            offset      = 0x0C0,
            bitSize     = 32,
            mode        = 'RO',
            base        = pr.UInt,
            disp        = '{:d}')
