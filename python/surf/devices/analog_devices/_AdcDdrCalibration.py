#-----------------------------------------------------------------------------
# Title      : Serialized DDR ADC calibration helpers
#-----------------------------------------------------------------------------
# Description:
# Device-neutral eye analysis and calibration result types for AdcDdr.
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

import copy
from dataclasses import asdict, dataclass
import itertools
import threading
import time
from typing import Any, Callable, Iterable, Mapping, Sequence

import pyrogue as pr


class _AdcDdrCalibrationStopped(Exception):
    """Internal control flow for a user-requested process stop."""


def addAdcDdrResetCommands(
        device: Any,
        powerMode: Any,
        pn23Reset: Any,
        configUpdate: Callable[[], None] | None = None) -> None:
    """Add normalized digital and PN23 reset commands to an ADC config device."""

    def digitalReset() -> None:
        powerMode.setDisp('Digital Reset', write=True)
        try:
            if configUpdate is not None:
                configUpdate()
            # Retain a small explicit hold in addition to the blocking SPI
            # transactions that assert and release the reset state.
            time.sleep(0.001)
        finally:
            powerMode.setDisp('Chip Run', write=True)
            if configUpdate is not None:
                configUpdate()

    def resetPnLong() -> None:
        pn23Reset.set(True, write=True)
        try:
            if configUpdate is not None:
                configUpdate()
        finally:
            pn23Reset.set(False, write=True)
            if configUpdate is not None:
                configUpdate()

    device.add(pr.LocalCommand(
        name        = 'DigitalReset',
        description = 'Pulse the ADC digital datapath reset and return to normal operation',
        function    = digitalReset))

    device.add(pr.LocalCommand(
        name        = 'ResetPNLong',
        description = 'Synchronously restart the ADC PN23 test-pattern generator',
        function    = resetPnLong))


@dataclass(frozen=True)
class AdcDdrEye:
    """One contiguous passing delay window and its chosen sampling tap.

    Parameters
    ----------
    start : int
        First passing tap in the window.
    end : int
        Last passing tap in the window.
    width : int
        Number of passing taps in the window.
    selected : int
        Center tap selected for sampling.
    leftMargin : int
        Passing taps between ``selected`` and ``start``.
    rightMargin : int
        Passing taps between ``selected`` and ``end``.
    wraps : bool
        Whether the window crosses the end of a circular delay range.
    leftBounded : bool
        Whether a failing tap was observed beyond the left edge.
    rightBounded : bool
        Whether a failing tap was observed beyond the right edge.
    """

    start: int
    end: int
    width: int
    selected: int
    leftMargin: int
    rightMargin: int
    wraps: bool
    leftBounded: bool
    rightBounded: bool

    def contains(self, tap: int) -> bool:
        """Return whether ``tap`` lies inside this eye, including wraparound."""

        if self.wraps:
            return tap >= self.start or tap <= self.end
        return self.start <= tap <= self.end

    def asDict(self) -> dict[str, Any]:
        """Return a PyRogue-friendly dictionary representation."""

        return asdict(self)


def findAdcDdrEyes(
        passing: Mapping[int, bool],
        *,
        minimumWidth: int = 1,
        guardBand: int = 0,
        circular: bool = False) -> tuple[AdcDdrEye, ...]:
    """Return every qualifying window from a consecutive tap scan.

    Parameters
    ----------
    passing : Mapping[int, bool]
        Pass/fail result for each consecutively scanned delay tap.
    minimumWidth : int, optional
        Minimum accepted eye width in taps.
    guardBand : int, optional
        Required passing taps on both sides of the selected center.
    circular : bool, optional
        Merge passing runs at the high and low scan boundaries.

    Returns
    -------
    tuple[AdcDdrEye, ...]
        Qualifying eyes ordered by decreasing width and increasing center tap.

    Raises
    ------
    ValueError
        If the scan controls or tap domain are invalid.
    TypeError
        If a delay tap index is not an integer.
    RuntimeError
        If the scan contains no qualifying passing window.

    Notes
    -----
    For an even-width window, the lower of its two center positions is used.
    """

    if minimumWidth < 1:
        raise ValueError('minimumWidth must be at least one tap')
    if guardBand < 0:
        raise ValueError('guardBand must not be negative')
    if not passing:
        raise ValueError('passing scan must not be empty')

    # A contiguous numeric domain makes physical edges and margins meaningful.
    # Reject sparse maps rather than accidentally treating an untested gap as
    # adjacent delay taps.
    taps = sorted(passing)
    if any(not isinstance(tap, int) for tap in taps):
        raise TypeError('delay tap indices must be integers')
    if any(right != left+1 for left, right in zip(taps, taps[1:])):
        raise ValueError('passing scan tap indices must be consecutive')

    # Collapse the boolean scan into maximal passing runs. Keeping every run is
    # important for FCO calibration because different unit intervals can each
    # contain a valid eye even though only one can be the initial selection.
    runs = []
    run = []
    for tap in taps:
        if passing[tap]:
            run.append(tap)
        elif run:
            runs.append(run)
            run = []
    if run:
        runs.append(run)

    if not runs:
        raise RuntimeError('scan contains no passing delay window')

    scanStart = taps[0]
    scanEnd = taps[-1]
    # On circular delay elements, the high-end and low-end runs are two pieces
    # of one physical eye. Preserve their high-to-low ordering so start > end is
    # the explicit wrapped-eye representation used by AdcDdrEye.contains().
    if circular and len(runs) > 1 and runs[0][0] == scanStart and runs[-1][-1] == scanEnd:
        runs = runs[1:-1] + [runs[-1] + runs[0]]

    # GuardBand is a center-margin requirement, so it implies a minimum total
    # width even when MinimumEyeWidth is configured to a smaller value.
    requiredWidth = max(minimumWidth, (2*guardBand)+1)
    eyes = []
    for candidate in runs:
        if len(candidate) < requiredWidth:
            continue
        centerIndex = (len(candidate)-1)//2
        start = candidate[0]
        end = candidate[-1]
        wraps = start > end
        eyes.append(AdcDdrEye(
            start        = start,
            end          = end,
            width        = len(candidate),
            selected     = candidate[centerIndex],
            leftMargin   = centerIndex,
            rightMargin  = len(candidate)-centerIndex-1,
            wraps        = wraps,
            leftBounded  = wraps or start != scanStart,
            rightBounded = wraps or end != scanEnd))

    if not eyes:
        raise RuntimeError(
            f'scan contains no passing delay window at least {requiredWidth} taps wide')

    # This ordering makes itertools.product() try the historical preferred eye
    # combination first, followed by progressively less-preferred alternatives.
    return tuple(sorted(eyes, key=lambda eye: (-eye.width, eye.selected)))


def findAdcDdrEye(
        passing: Mapping[int, bool],
        *,
        minimumWidth: int = 1,
        guardBand: int = 0,
        circular: bool = False) -> AdcDdrEye:
    """Select the highest-priority qualifying eye from a tap scan.

    Parameters
    ----------
    passing : Mapping[int, bool]
        Pass/fail result for each consecutively scanned delay tap.
    minimumWidth : int, optional
        Minimum accepted eye width in taps.
    guardBand : int, optional
        Required passing taps on both sides of the selected center.
    circular : bool, optional
        Merge passing runs at the high and low scan boundaries.

    Returns
    -------
    AdcDdrEye
        Highest-priority qualifying eye.
    """

    return findAdcDdrEyes(
        passing,
        minimumWidth=minimumWidth,
        guardBand=guardBand,
        circular=circular)[0]


def checkAdcDdrPn23(samples: Sequence[int], sampleBits: int) -> dict[str, Any]:
    """Check an arbitrary-phase, MSB-first PN23 sample sequence.

    Parameters
    ----------
    samples : Sequence[int]
        Complete logical ADC samples in capture order.
    sampleBits : int
        Number of meaningful bits in each sample.

    Returns
    -------
    dict[str, Any]
        Pass status and diagnostics for each tested output transformation.

    Raises
    ------
    ValueError
        If ``sampleBits`` is invalid or too few bits were captured.

    Notes
    -----
    The first 23 captured bits establish the unknown LFSR phase. Remaining
    bits must satisfy ``x^23 + x^18 + 1``. All four combinations of output and
    format inversion are considered explicitly.
    """

    if sampleBits < 1:
        raise ValueError('sampleBits must be positive')
    if len(samples)*sampleBits <= 23:
        raise ValueError('PN23 verification requires more than 23 captured bits')

    sampleMask = (1 << sampleBits)-1
    transformations = (
        ('asCaptured', 0),
        ('formatMsbInverted', 1 << (sampleBits-1)),
        ('outputInverted', sampleMask),
        ('outputAndFormatInverted', sampleMask ^ (1 << (sampleBits-1))),
    )
    attempts = []
    for name, xorMask in transformations:
        # ADC PN words are serialized MSB first. Flatten complete logical words
        # in that same order so word boundaries disappear for the recurrence.
        bits = [
            ((sample ^ xorMask) >> bit) & 1
            for sample in samples
            for bit in range(sampleBits-1, -1, -1)
        ]
        initialState = sum(bit << (22-index) for index, bit in enumerate(bits[:23]))
        errorBits = [
            index
            for index in range(23, len(bits))
            if bits[index] != (bits[index-23] ^ bits[index-18])
        ]
        # The all-zero state satisfies the linear recurrence but is not part of
        # the maximal-length PN23 sequence and must not qualify a dead data bus.
        passed = initialState != 0 and not errorBits
        attempt = {
            'name': name,
            'xorMask': xorMask,
            'initialState': initialState,
            'checkedBits': len(bits)-23,
            'errorBits': errorBits,
            'passed': passed,
        }
        attempts.append(attempt)
        if passed:
            return {
                'passed': True,
                'selected': copy.deepcopy(attempt),
                'attempts': attempts,
            }

    return {
        'passed': False,
        'selected': None,
        'attempts': attempts,
    }


class AdcDdrCalibration(pr.Process):
    """Software-driven FCO and per-data-lane delay calibration.

    The process scans FCO eyes first, centers compatible data lanes in parallel,
    and finally qualifies the complete logical sample with a shared checkerboard
    phase plus optional PN23 coherence and recurrence. Device adapters describe
    how physical lanes map into logical channels and which sample bits each lane
    contributes.

    Parameters
    ----------
    config : Any
        ADC configuration device containing ``OutputTestMode``.
    readout : Any
        Normalized ``AdcDdr`` readout device.
    dataLaneToChannel : Sequence[int], optional
        Logical channel contributed by each physical data lane.
    dataLaneMasks : Sequence[int], optional
        Logical sample-bit mask contributed by each physical data lane.
    testMode : int, optional
        ADC checkerboard test-mode value.
    expectedPatterns : Iterable[int], optional
        Expected checkerboard sample values.
    configUpdate : Callable[[], None], optional
        Callback that transfers staged ADC configuration writes.
    pn23Mode : int, optional
        ADC PN23 test-mode value.
    **kwargs : Any
        Additional arguments forwarded to ``pyrogue.Process``.
    """

    FULL_C = 0
    VERIFY_CURRENT_C = 1
    VERIFY_GUARD_BAND_C = 2
    OUTCOME_IDLE_C = 0
    OUTCOME_RUNNING_C = 1
    OUTCOME_PASSED_C = 2
    OUTCOME_FAILED_C = 3
    OUTCOME_STOPPED_C = 4
    RUN_TIME_UPDATE_INTERVAL_C = 1.0
    PATTERN_TESTER_TIMEOUT_C = 256

    def __init__(
            self,
            *,
            config: Any,
            readout: Any,
            dataLaneToChannel: Sequence[int] | None = None,
            dataLaneMasks: Sequence[int] | None = None,
            testMode: int = 4,
            expectedPatterns: Iterable[int] | None = None,
            configUpdate: Callable[[], None] | None = None,
            pn23Mode: int = 5,
            **kwargs: Any) -> None:
        """Construct a calibration process for one normalized ADC readout."""

        self._config = config
        self._readout = readout
        self._dataLanes = readout._dataLanes
        self._fcoLanes = readout._fcoLanes
        self._channels = readout._channels

        # One-lane ADCs use the natural lane-to-channel mapping. Multi-lane ADC
        # adapters, such as AD9681, explicitly map both physical halves back to
        # the same set of logical channels.
        if dataLaneToChannel is None:
            dataLaneToChannel = [lane % self._channels for lane in range(self._dataLanes)]
        if len(dataLaneToChannel) != self._dataLanes:
            raise ValueError('dataLaneToChannel must contain one entry per data lane')
        if any(channel < 0 or channel >= self._channels for channel in dataLaneToChannel):
            raise ValueError('dataLaneToChannel contains an out-of-range channel')
        self._dataLaneToChannel = tuple(dataLaneToChannel)

        # The mask identifies which logical sample bits are actually carried by
        # a physical lane. It lets a lane be judged while its partner half is
        # still outside its eye.
        if dataLaneMasks is None:
            dataLaneMasks = [(1 << readout._sampleBits)-1] * self._dataLanes
        if len(dataLaneMasks) != self._dataLanes:
            raise ValueError('dataLaneMasks must contain one entry per data lane')
        sampleMask = (1 << readout._sampleBits)-1
        if any(mask <= 0 or mask & ~sampleMask for mask in dataLaneMasks):
            raise ValueError('dataLaneMasks contains an invalid sample-bit mask')
        self._dataLaneMasks = tuple(dataLaneMasks)
        # Greedily build the largest safe parallel sweep groups. Lanes on
        # different channels never interfere. Lanes on the same channel can
        # also move together when their masks are disjoint, as with AD9681's
        # lower-six-bit and upper-eight-bit halves. Overlapping contributors
        # remain in separate groups so an error can be attributed to one lane.
        groups = []
        for lane, (channel, mask) in enumerate(
                zip(self._dataLaneToChannel, self._dataLaneMasks)):
            for group in groups:
                if all(
                        self._dataLaneToChannel[other] != channel or
                        not (self._dataLaneMasks[other] & mask)
                        for other in group):
                    group.append(lane)
                    break
            else:
                groups.append([lane])
        self._dataLaneGroups = tuple(tuple(group) for group in groups)

        # Default to the ADC checkerboard mode. A frozenset intentionally drops
        # phase ordering here; per-lane eye scans need only observe both values.
        # The final full-sample check restores strict shared phase ordering.
        if expectedPatterns is None:
            checkerA = sum(1 << bit for bit in range(readout._sampleBits) if bit % 2)
            checkerB = ((1 << readout._sampleBits)-1) ^ checkerA
            expectedPatterns = (checkerA, checkerB)
        self._expectedPatterns = frozenset(expectedPatterns)
        if not self._expectedPatterns:
            raise ValueError('expectedPatterns must not be empty')
        self._testMode = testMode
        self._configUpdate = configUpdate
        self._pn23Mode = pn23Mode
        self._runDiagnostics = {}
        self._lastCaptureDiagnostics = {}
        self._deepPatternTesterActive = False

        kwargs.setdefault(
            'description',
            'Measure, verify, and apply normalized AdcDdr input-delay settings')
        super().__init__(function=self._runCalibration, **kwargs)

        # User controls, retained results, and diagnostics are LocalVariables;
        # all hardware access remains behind the normalized readout/config APIs.
        self.add(pr.LocalVariable(
            name        = 'Operation',
            description = 'Calibration or verification operation',
            value       = self.FULL_C,
            enum        = {
                self.FULL_C: 'Full calibration',
                self.VERIFY_CURRENT_C: 'Verify current',
                self.VERIFY_GUARD_BAND_C: 'Verify guard band',
            },
            mode        = 'RW'))

        self.add(pr.LocalVariable(
            name        = 'DelayStart',
            description = 'First delay tap included in a full scan',
            value       = 0,
            minimum     = 0,
            maximum     = (1 << readout._delayBits)-1,
            units       = 'tap',
            mode        = 'RW'))

        self.add(pr.LocalVariable(
            name        = 'DelayStop',
            description = 'Last delay tap included in a full scan',
            value       = (1 << readout._delayBits)-1,
            minimum     = 0,
            maximum     = (1 << readout._delayBits)-1,
            units       = 'tap',
            mode        = 'RW'))

        self.add(pr.LocalVariable(
            name        = 'UsePatternTester',
            description = (
                'Run deep hardware checkerboard and optional PN23 qualification '
                'after centering'),
            value       = readout._patternCheck,
            mode        = 'RW'))

        self.add(pr.LocalVariable(
            name        = 'PatternTesterSamples',
            description = 'Valid samples checked by each deep hardware qualification window',
            value       = 4096,
            minimum     = 1,
            maximum     = 0xFFFFFFFF,
            mode        = 'RW'))

        self.add(pr.LocalVariable(
            name        = 'SampleCount',
            description = 'Four-sample groups checked at each data tap',
            value       = 2,
            minimum     = 1,
            mode        = 'RW'))

        self.add(pr.LocalVariable(
            name        = 'VerifyPn23',
            description = (
                'After checkerboard alignment, compare one four-sample PN23 '
                'snapshot across channels and verify its recurrence'),
            value       = callable(getattr(config, 'ResetPNLong', None)),
            mode        = 'RW'))

        self.add(pr.LocalVariable(
            name        = 'Outcome',
            description = 'Explicit result of the current or most recent operation',
            value       = self.OUTCOME_IDLE_C,
            enum        = {
                self.OUTCOME_IDLE_C: 'IDLE',
                self.OUTCOME_RUNNING_C: 'RUNNING',
                self.OUTCOME_PASSED_C: 'PASSED',
                self.OUTCOME_FAILED_C: 'FAILED',
                self.OUTCOME_STOPPED_C: 'STOPPED',
            },
            mode        = 'RO'))

        self.add(pr.LocalVariable(
            name        = 'RunTime',
            description = 'Elapsed wall-clock duration of the current or last operation',
            value       = 0.0,
            units       = 's',
            disp        = '{:1.6f}',
            mode        = 'RO'))

        self.add(pr.LocalVariable(
            name        = 'SettleTime',
            description = 'Delay after changing a tap, relocking, or selecting test mode',
            value       = 0.001,
            minimum     = 0.0,
            units       = 's',
            mode        = 'RW'))

        self.add(pr.LocalVariable(
            name        = 'MinimumEyeWidth',
            description = 'Minimum passing width accepted by a full scan',
            value       = 8,
            minimum     = 1,
            units       = 'tap',
            mode        = 'RW'))

        self.add(pr.LocalVariable(
            name        = 'GuardBand',
            description = 'Passing taps required on both sides of a selected tap',
            value       = 2,
            minimum     = 0,
            units       = 'tap',
            mode        = 'RW'))

        self.add(pr.LocalVariable(
            name        = 'CircularDelays',
            description = 'Merge passing windows at the delay scan boundaries',
            value       = False,
            mode        = 'RW'))

        self.add(pr.LocalVariable(
            name        = 'Debug',
            description = 'Retain and publish detailed diagnostics when the operation ends',
            value       = False,
            mode        = 'RW'))

        self.add(pr.LocalVariable(
            name        = 'Diagnostics',
            description = 'Per-tap FCO words, lock state, and raw/masked data samples',
            value       = {},
            mode        = 'RO'))

        self.add(pr.LocalVariable(
            name        = 'Results',
            description = 'FCO and data-lane results from the last operation',
            value       = {},
            mode        = 'RO'))

        self.add(pr.LocalCommand(
            name        = 'ApplyResults',
            description = 'Reapply selected taps from the last full calibration',
            function    = self.applyResults))

    def _process(self) -> None:
        """Translate a user-requested stop into a normal process outcome."""

        try:
            super()._process()
        except _AdcDdrCalibrationStopped:
            # Process.Stop is an expected user action.  The calibration
            # function has already restored the test mode and original delays
            # in its finally block, so retain the partial progress without
            # reporting the stop as an execution error.
            self.Message.set('Calibration stopped')

    def _checkRun(self) -> None:
        """Raise the private stop exception at cooperative cancellation points."""

        if not self._runEn:
            raise _AdcDdrCalibrationStopped

    def _recordDiagnostic(
            self,
            kind: str,
            lane: int,
            tap: int,
            detail: dict[str, Any]) -> None:
        """Retain one per-tap diagnostic in the private working tree."""

        # Publishing this growing tree at every tap makes a long scan
        # increasingly expensive. The process wrapper publishes one immutable
        # copy after success, failure, or cancellation instead.
        self._runDiagnostics[kind].setdefault(lane, {})[tap] = detail
        self._runDiagnostics['Current'] = {
            'kind': kind,
            'lane': lane,
            'tap': tap,
        }

    def _configurePatternTester(
            self,
            channels: Sequence[int],
            mask: int,
            samples: int,
            *,
            pn23: bool = False,
            xorMask: int = 0) -> None:
        """Program one hardware measurement window for a channel/mask set."""

        patterns = sorted(self._expectedPatterns)
        tester = self._readout.PatternTester
        # Alternating patterns share one phase reference across every enabled
        # channel. This prevents each logical channel from independently calling
        # an opposite checkerboard phase valid.
        tester.Alternating.set(not pn23 and len(patterns) == 2, write=True)
        tester.Pn23.set(pn23, write=True)
        tester.ReferenceChannel.set(channels[0], write=True)
        tester.ChannelMask.set(sum(1 << channel for channel in channels), write=True)
        tester.FcoMask.set((1 << self._fcoLanes)-1, write=True)
        tester.DataMask.set(mask, write=True)
        tester.PatternA.set(xorMask if pn23 else patterns[0], write=True)
        tester.PatternB.set(0 if pn23 else patterns[-1], write=True)
        tester.Samples.set(samples, write=True)
        # Do not inherit mutable state from manual uses of the child device.
        # This timeout detects a stopped producer without limiting a healthy
        # continuous sample window.
        tester.Timeout.set(self.PATTERN_TESTER_TIMEOUT_C, write=True)

    def _runPatternTester(self) -> dict[str, Any]:
        """Start one hardware window and return its stable retained results."""

        tester = self._readout.PatternTester
        # Sequence is the completion handshake. It avoids depending on the exact
        # cycle in which Busy asserts or clears across the AXI-Lite boundary.
        sequence = int(tester.Sequence.get(read=True))
        tester.Start()
        while True:
            if not self._runEn:
                tester.Abort()
                self._checkRun()
            current = int(tester.Sequence.get(read=True))
            if current != sequence:
                break

        # Force one final hardware transaction before reading the cached status
        # fields populated by the completed measurement.
        tester.Busy.get(read=True)
        status = {
            'busy': bool(tester.Busy.get(read=False)),
            'timedOut': bool(tester.TimedOut.get(read=False)),
            'configError': bool(tester.ConfigError.get(read=False)),
            'aborted': bool(tester.Aborted.get(read=False)),
            'phaseAcquired': bool(tester.PhaseAcquired.get(read=False)),
            'allChannelsPass': bool(tester.AllChannelsPass.get(read=False)),
            'allFcoPass': bool(tester.AllFcoPass.get(read=False)),
        }
        if status['timedOut']:
            raise RuntimeError('ADC pattern tester timed out waiting for valid samples')
        if status['configError']:
            raise RuntimeError('ADC pattern tester rejected its measurement configuration')
        if status['aborted']:
            raise RuntimeError('ADC pattern tester measurement was aborted')

        channelPassed = int(tester.ChannelPassed.get(read=True))
        fcoPassed = int(tester.FcoPassed.get(read=True))
        channels = {
            channel: {
                'passed': bool(channelPassed & (1 << channel)),
                'wordErrorCount': int(tester.WordErrorCount[channel].get(read=True)),
                'bitErrorMask': int(tester.BitErrorMask[channel].get(read=True)),
            }
            for channel in range(self._channels)
        }
        fco = {
            lane: {
                'passed': bool(fcoPassed & (1 << lane)),
                'errorCount': int(tester.FcoErrorCount[lane].get(read=True)),
            }
            for lane in range(self._fcoLanes)
        }
        return {
            'sequence': current,
            'checkedSamples': int(tester.CheckedSamples.get(read=True)),
            'channelPassed': channelPassed,
            'fcoPassed': fcoPassed,
            'channels': channels,
            'fco': fco,
            'status': status,
        }

    def _captureGroupPassesSnapshot(
            self,
            lanes: Sequence[int]) -> dict[int, dict[str, Any]]:
        """Measure ordered per-lane patterns from atomic snapshots."""

        patterns = sorted(self._expectedPatterns)
        details = {
            lane: {
                'channel': self._dataLaneToChannel[lane],
                'mask': self._dataLaneMasks[lane],
                'expected': sorted({pattern & self._dataLaneMasks[lane]
                                    for pattern in patterns}),
                'captures': [],
                'passed': True,
            }
            for lane in lanes
        }
        channels = sorted({self._dataLaneToChannel[lane] for lane in lanes})
        for _ in range(self.SampleCount.value()):
            # Snapshot publishes every logical channel atomically. Read it once
            # and reuse that coherent capture for every lane-specific mask.
            self._readout.Snapshot()
            snapshotSequence = self._readout.SnapshotSequence.get(read=False)
            snapshot = self._readout._getDebugSamples(read=False)
            rawByChannel = {
                channel: snapshot[channel]
                for channel in channels
            }
            for lane, detail in details.items():
                mask = detail['mask']
                maskedPatterns = detail['expected']
                raw = rawByChannel[detail['channel']]
                masked = [sample & mask for sample in raw]
                try:
                    phase = maskedPatterns.index(masked[0])
                except ValueError:
                    phase = None
                    expected = []
                else:
                    expected = [
                        maskedPatterns[(phase+index) % len(maskedPatterns)]
                        for index in range(len(masked))
                    ]

                # Each physical lane acquires phase independently during the
                # scan so one channel leaving its eye cannot truncate another
                # channel's passing window. The assembled final checks impose
                # one shared phase after every lane has been centered.
                capturePassed = phase is not None and masked == expected
                detail['captures'].append({
                    'sequence': snapshotSequence,
                    'phase': phase,
                    'expectedSequence': expected,
                    'raw': raw,
                    'masked': masked,
                    'passed': capturePassed,
                })
                detail['passed'] &= capturePassed
        return details

    def _captureGroupPasses(
            self,
            lanes: Sequence[int]) -> dict[int, dict[str, Any]]:
        """Measure one grouped data tap using coherent debug snapshots."""

        return self._captureGroupPassesSnapshot(lanes)

    def _capturePasses(self, lane: int) -> bool:
        """Compatibility helper for verifying one physical data lane."""

        detail = self._captureGroupPasses((lane,))[lane]
        self._lastCaptureDiagnostics = detail
        return detail['passed']

    def _captureFinalPasses(self) -> dict[str, Any]:
        """Qualify complete logical samples with one shared pattern phase."""

        mask = (1 << self._readout._sampleBits)-1
        patterns = sorted(self._expectedPatterns)
        detail = {
            'mask': mask,
            'expected': patterns,
            'referenceChannel': 0,
            'captures': [],
            'passed': True,
        }

        for _ in range(self.SampleCount.value()):
            self._checkRun()
            self._readout.Snapshot()
            snapshotSequence = self._readout.SnapshotSequence.get(read=False)
            snapshot = self._readout._getDebugSamples(read=False)
            rawByChannel = {
                channel: snapshot[channel]
                for channel in range(self._channels)
            }
            maskedByChannel = {
                channel: [sample & mask for sample in raw]
                for channel, raw in rawByChannel.items()
            }

            # Acquire the A/B phase once from channel zero, then require every
            # channel—and therefore every assembled physical half—to match the
            # same ordered sequence. This detects split-lane sample epochs that
            # an FCO pattern cannot distinguish by itself.
            reference = maskedByChannel[detail['referenceChannel']]
            try:
                phase = patterns.index(reference[0])
            except ValueError:
                phase = None
                expected = []
            else:
                expected = [
                    patterns[(phase+index) % len(patterns)]
                    for index in range(len(reference))
                ]

            channels = {
                channel: {
                    'raw': rawByChannel[channel],
                    'masked': masked,
                    'passed': phase is not None and masked == expected,
                }
                for channel, masked in maskedByChannel.items()
            }
            capturePassed = all(channel['passed'] for channel in channels.values())
            detail['captures'].append({
                'sequence': snapshotSequence,
                'phase': phase,
                'expectedSequence': expected,
                'channels': channels,
                'passed': capturePassed,
            })
            detail['passed'] &= capturePassed

        return detail

    def _captureDeepPatternPasses(self) -> dict[str, Any]:
        """Run one deep full-channel checkerboard measurement in hardware."""

        mask = (1 << self._readout._sampleBits)-1
        channels = list(range(self._channels))
        samples = int(self.PatternTesterSamples.value())
        self._configurePatternTester(channels, mask, samples)
        measurement = self._runPatternTester()
        measurement['enabled'] = True
        measurement['performed'] = True
        measurement['mode'] = 'Checkerboard'
        measurement['requestedSamples'] = samples
        measurement['passed'] = (
            measurement['checkedSamples'] == samples and
            measurement['status']['allChannelsPass'] and
            measurement['status']['allFcoPass'])
        return measurement

    def _captureDeepPn23Passes(self, xorMask: int) -> dict[str, Any]:
        """Run one arbitrary-phase PN23 recurrence/coherence window."""

        mask = (1 << self._readout._sampleBits)-1
        channels = list(range(self._channels))
        samples = int(self.PatternTesterSamples.value())
        self._configurePatternTester(
            channels,
            mask,
            samples,
            pn23=True,
            xorMask=xorMask)
        measurement = self._runPatternTester()
        measurement['enabled'] = True
        measurement['performed'] = True
        measurement['mode'] = 'Pn23'
        measurement['xorMask'] = xorMask
        measurement['requestedSamples'] = samples
        measurement['passed'] = (
            measurement['checkedSamples'] == samples and
            measurement['status']['phaseAcquired'] and
            measurement['status']['allChannelsPass'] and
            measurement['status']['allFcoPass'])
        return measurement

    def _setPn23Mode(self) -> None:
        """Select PN23 and synchronously restart every selected generator."""

        resetPnLong = getattr(self._config, 'ResetPNLong', None)
        if not callable(resetPnLong):
            raise RuntimeError('PN23 verification requires config.ResetPNLong()')

        self._setTestMode(self._pn23Mode)
        resetPnLong()

    def _capturePn23Passes(self) -> dict[str, Any]:
        """Check channel coherence and PN23 recurrence in one atomic snapshot."""

        self._checkRun()
        self._readout.Snapshot()
        snapshotSequence = self._readout.SnapshotSequence.get(read=False)
        snapshot = self._readout._getDebugSamples(read=False)
        channels = {
            channel: [int(sample) for sample in snapshot[channel]]
            for channel in range(self._channels)
        }
        referenceChannel = 0
        reference = channels[referenceChannel]
        recurrence = checkAdcDdrPn23(reference, self._readout._sampleBits)
        channelResults = {
            channel: {
                'samples': samples,
                'matchesReference': samples == reference,
            }
            for channel, samples in channels.items()
        }
        coherencePassed = all(
            result['matchesReference']
            for result in channelResults.values())
        return {
            'sequence': snapshotSequence,
            'referenceChannel': referenceChannel,
            'channels': channelResults,
            'coherencePassed': coherencePassed,
            'recurrence': recurrence,
            'passed': coherencePassed and recurrence['passed'],
        }

    def _setTestMode(self, value: int) -> None:
        """Select an ADC output pattern and issue any required device update."""

        self._config.OutputTestMode.set(value, write=True)
        if self._configUpdate is not None:
            # Some ADC register interfaces shadow writes until a transfer/update
            # command is issued. Device adapters provide that command here.
            self._configUpdate()

    def _enterAlignmentPattern(self, settle: float) -> None:
        """Select checkerboard and establish a deterministic ADC sample epoch."""

        self._setTestMode(self._testMode)
        time.sleep(settle)
        digitalReset = getattr(self._config, 'DigitalReset', None)
        if not callable(digitalReset):
            raise RuntimeError('ADC calibration requires config.DigitalReset()')
        # Alternating patterns can originate in independent channel-local
        # digital pipelines. Reset those pipelines only after the pattern is
        # selected, then restart FPGA word alignment against the newly
        # synchronized ADC output.
        self.Message.set('Resetting ADC digital datapath for pattern alignment')
        digitalReset()
        time.sleep(settle)
        self._readout.Relock()
        time.sleep(settle)

    def _scanFco(
            self,
            lane: int,
            taps: Sequence[int],
            settle: float) -> dict[int, bool]:
        """Return the lock verdict at every requested tap for one FCO lane."""

        passing = {}
        for tap in taps:
            self._checkRun()
            self._readout.FcoDelay[lane].set(tap, write=True)
            # Changing FCO timing invalidates the frame-word lock. Reacquire it
            # at each tap before treating LockedMask as the measurement result.
            self._readout.Relock()
            time.sleep(settle)
            lockedMask = self._readout.LockedMask.get(read=True)
            passing[tap] = bool(lockedMask & (1 << lane))
            if self.Debug.value():
                word = self._readout.FcoWord[lane].get(read=True)
                self._recordDiagnostic('Fco', lane, tap, {
                    'passed': passing[tap],
                    'lockedMask': lockedMask,
                    'word': word,
                })
                self.Message.set(
                    f'FCO lane {lane}, tap {tap}: '
                    f'{"pass" if passing[tap] else "fail"}, '
                    f'word=0x{word:X}, lockedMask=0x{lockedMask:X}')
            self.incrementSteps()
        return passing

    def _scanDataGroup(
            self,
            lanes: Sequence[int],
            taps: Sequence[int],
            settle: float) -> dict[int, dict[int, bool]]:
        """Sweep a compatible physical-lane group through one common tap range."""

        passing = {lane: {} for lane in lanes}
        for tap in taps:
            self._checkRun()
            # All group members move before the capture, so every lane verdict
            # in this iteration describes the same physical sampling instant.
            self._readout._setDataDelays({lane: tap for lane in lanes})
            time.sleep(settle)
            details = self._captureGroupPasses(lanes)
            for lane, detail in details.items():
                passing[lane][tap] = detail['passed']
                self._runDiagnostics['Data'].setdefault(lane, {})[tap] = detail
            self._runDiagnostics['Current'] = {
                'kind': 'Data',
                'lanes': list(lanes),
                'tap': tap,
            }
            if self.Debug.value():
                passed = [lane for lane in lanes if details[lane]['passed']]
                failed = [lane for lane in lanes if not details[lane]['passed']]
                self.Message.set(
                    f'Data lanes {list(lanes)}, tap {tap}: '
                    f'passing={passed}, failing={failed}')
            self.incrementSteps()
        return passing

    def _fullCalibration(
            self,
            taps: Sequence[int],
            settle: float) -> dict[str, Any]:
        """Scan, center, and jointly qualify every FCO and data lane."""

        results = {'Fco': {}, 'Data': {}}
        fcoEyes = {}
        minimum = self.MinimumEyeWidth.value()
        guard = self.GuardBand.value()
        circular = self.CircularDelays.value()

        # FCO lanes and compatible data groups each consume one tap scan. FCO
        # combination retries are data-dependent, so they are intentionally not
        # included in the deterministic progress-bar total.
        self.setTotalSteps(len(taps)*(self._fcoLanes+len(self._dataLaneGroups))+1)
        self.setStep(0)

        # Locate all qualifying FCO windows. The preferred (widest) eye is
        # installed immediately, while alternatives are retained for the final
        # cross-lane phase qualification below.
        for lane in range(self._fcoLanes):
            self.Message.set(f'Scanning FCO lane {lane}')
            passing = self._scanFco(lane, taps, settle)
            try:
                eyes = findAdcDdrEyes(
                    passing,
                    minimumWidth=minimum,
                    guardBand=guard,
                    circular=circular)
            except RuntimeError as exc:
                results['Fco'][lane] = {
                    'passing': passing,
                    'diagnostics': copy.deepcopy(self._runDiagnostics['Fco'].get(lane, {})),
                }
                self.Results.set(results)
                raise RuntimeError(f'FCO lane {lane}: {exc}') from exc
            fcoEyes[lane] = eyes
            results['Fco'][lane] = {
                'eye': eyes[0].asDict(),
                'eyes': [eye.asDict() for eye in eyes],
                'passing': passing,
            }
            self._readout.FcoDelay[lane].set(eyes[0].selected, write=True)

        self._readout.Relock()
        time.sleep(settle)

        # Put the ADC into a known alternating pattern only after FCO lock is
        # established. Each overlap-safe lane group is swept once and centered
        # before the next group is measured.
        self._enterAlignmentPattern(settle)
        for lanes in self._dataLaneGroups:
            self.Message.set(f'Scanning data lanes {list(lanes)}')
            groupPassing = self._scanDataGroup(lanes, taps, settle)
            groupEyes = {}
            for lane in lanes:
                passing = groupPassing[lane]
                try:
                    eye = findAdcDdrEye(
                        passing,
                        minimumWidth=minimum,
                        guardBand=guard,
                        circular=circular)
                except RuntimeError as exc:
                    results['Data'][lane] = {
                        'passing': passing,
                        'diagnostics': copy.deepcopy(
                            self._runDiagnostics['Data'].get(lane, {})),
                    }
                    self.Results.set(results)
                    raise RuntimeError(f'Data lane {lane}: {exc}') from exc
                groupEyes[lane] = eye
                results['Data'][lane] = {'eye': eye.asDict(), 'passing': passing}
            # Center the complete group before scanning any remaining lanes
            # whose overlapping sample masks require a separate pass.
            self._readout._setDataDelays({
                lane: eye.selected
                for lane, eye in groupEyes.items()
            })

        # Per-lane FCO lock cannot distinguish equivalent frame windows that
        # imply different sample epochs. Try the Cartesian product of retained
        # eyes and accept the first combination whose fully assembled channel
        # data shares one ordered checkerboard phase.
        self.Message.set('Checking final full-channel pattern alignment')
        combinations = itertools.product(*(
            fcoEyes[lane]
            for lane in range(self._fcoLanes)
        ))
        attempts = []
        final = None
        for index, combination in enumerate(combinations):
            self._checkRun()
            if index != 0:
                # Data-eye locations are independent of which equivalent FCO
                # window establishes frame phase, so retries only move FCO taps
                # before repeating final qualification; the expensive data
                # sweeps do not need repeating.
                selected = {
                    lane: eye.selected
                    for lane, eye in enumerate(combination)
                }
                self.Message.set(
                    f'Retrying FCO eye combination '
                    f'{[selected[lane] for lane in range(self._fcoLanes)]}')
                for lane, tap in selected.items():
                    self._readout.FcoDelay[lane].set(tap, write=True)

            # Re-establish the ADC pattern epoch immediately before every final
            # attempt. This closes the long window between the reset preceding
            # data-eye scans and final qualification, during which another bank
            # calibrating in parallel may disturb shared ADC digital state. It
            # also restores checkerboard after a prior attempt reached PN23.
            self._enterAlignmentPattern(settle)

            checkerboard = self._captureFinalPasses()
            candidate = copy.deepcopy(checkerboard)
            candidate['snapshotPassed'] = checkerboard['passed']
            candidate['patternTester'] = {
                'enabled': self._deepPatternTesterActive,
                'performed': False,
                'requestedSamples': (
                    int(self.PatternTesterSamples.value())
                    if self._deepPatternTesterActive else 0),
                'passed': not self._deepPatternTesterActive,
            }
            if checkerboard['passed'] and self._deepPatternTesterActive:
                self.Message.set('Running deep hardware checkerboard qualification')
                candidate['patternTester'] = self._captureDeepPatternPasses()
            candidate['checkerboardPassed'] = (
                checkerboard['passed'] and candidate['patternTester']['passed'])
            candidate['pn23'] = {
                'enabled': bool(self.VerifyPn23.value()),
                'performed': False,
                'passed': not bool(self.VerifyPn23.value()),
            }
            if candidate['checkerboardPassed'] and self.VerifyPn23.value():
                self.Message.set('Checking final PN23 channel coherence and recurrence')
                self._setPn23Mode()
                time.sleep(settle)
                pn23 = self._capturePn23Passes()
                pn23['enabled'] = True
                pn23['performed'] = True
                pn23['snapshotPassed'] = pn23['passed']
                pn23['patternTester'] = {
                    'enabled': self._deepPatternTesterActive,
                    'performed': False,
                    'requestedSamples': (
                        int(self.PatternTesterSamples.value())
                        if self._deepPatternTesterActive else 0),
                    'passed': not self._deepPatternTesterActive,
                }
                if pn23['snapshotPassed'] and self._deepPatternTesterActive:
                    self.Message.set('Running deep hardware PN23 qualification')
                    pn23['patternTester'] = self._captureDeepPn23Passes(
                        int(pn23['recurrence']['selected']['xorMask']))
                pn23['passed'] = (
                    pn23['snapshotPassed'] and pn23['patternTester']['passed'])
                candidate['pn23'] = pn23
                candidate['passed'] = pn23['passed']
            else:
                candidate['passed'] = (
                    candidate['checkerboardPassed'] and candidate['pn23']['passed'])

            # Retain every attempted combination and its raw qualification so a
            # failed calibration explains exactly which phase choices were tried.
            attempts.append({
                'fcoDelays': [eye.selected for eye in combination],
                'fcoEyes': [eye.asDict() for eye in combination],
                'passed': candidate['passed'],
                'qualification': copy.deepcopy(candidate),
            })
            if candidate['passed']:
                final = candidate
                # Publish the eyes actually left in hardware, which may differ
                # from the individually preferred eyes selected above.
                for lane, eye in enumerate(combination):
                    results['Fco'][lane]['eye'] = eye.asDict()
                break

        if final is None:
            final = copy.deepcopy(attempts[-1]['qualification'])
        final['attempts'] = attempts
        results['Final'] = final
        self._runDiagnostics['Final'] = copy.deepcopy(final)
        self._runDiagnostics['Current'] = {'kind': 'Final'}
        self.incrementSteps()
        if not final['passed']:
            self.Results.set(results)
            raise RuntimeError('Final full-channel pattern qualification failed')
        return results

    def _verifyCurrent(
            self,
            originalFco: Sequence[int],
            originalData: Sequence[int],
            settle: float,
            guard: int) -> tuple[dict[str, Any], bool]:
        """Check installed taps, optionally including symmetric guard points."""

        start = self.DelayStart.value()
        stop = self.DelayStop.value()
        results = {'Fco': {}, 'Data': {}}
        passed = True
        candidatesPerLane = 1 if guard == 0 else 3

        # Verification checks every lane independently. Unlike a full scan, it
        # previously did not initialize or advance the Process progress fields,
        # which left the UI parked at step one for the entire operation.
        self.setTotalSteps(candidatesPerLane*(len(originalFco)+len(originalData)))
        self.setStep(0)

        self._enterAlignmentPattern(settle)
        for kind, currentValues in (
                ('Fco', originalFco),
                ('Data', originalData)):
            for lane, selected in enumerate(currentValues):
                checked = {}
                # Guard-band verification samples the selected point and the
                # requested distance on either side. A point outside the user's
                # allowed scan domain is an explicit failure, not a skipped test.
                candidates = [selected] if guard == 0 else [selected-guard, selected, selected+guard]
                for tap in candidates:
                    self._checkRun()
                    self.Message.set(
                        f'Verifying {kind} lane {lane}, tap {tap} '
                        f'(selected {selected})')
                    if tap < start or tap > stop:
                        checked[tap] = False
                    elif kind == 'Fco':
                        self._readout.FcoDelay[lane].set(tap, write=True)
                        self._readout.Relock()
                        time.sleep(settle)
                        checked[tap] = bool(
                            self._readout.LockedMask.get(read=True) & (1 << lane))
                    else:
                        self._readout._setDataDelays({lane: tap})
                        time.sleep(settle)
                        checked[tap] = self._capturePasses(lane)
                    self.incrementSteps()
                lanePassed = all(checked.values())
                results[kind][lane] = {
                    'selected': selected,
                    'guardBand': guard,
                    'checked': checked,
                    'passed': lanePassed,
                }
                passed &= lanePassed
                # Restore this lane before testing the next one. Multiple physical
                # lanes can contribute to the same logical sample, so leaving one
                # at its final guard candidate can invalidate the next lane's test.
                if kind == 'Fco':
                    self._readout.FcoDelay[lane].set(selected, write=True)
                    self._readout.Relock()
                else:
                    self._readout._setDataDelays({lane: selected})
                time.sleep(settle)
        return results, passed

    def _updateRunTime(self, runStart: float, stopEvent: threading.Event) -> None:
        """Publish elapsed wall time without burdening individual scan loops."""

        while not stopEvent.wait(self.RUN_TIME_UPDATE_INTERVAL_C):
            self.RunTime.set(time.monotonic()-runStart)

    def _runCalibration(self, *, dev: Any) -> dict[str, Any]:
        """Wrap the operation with a live elapsed-time monitor."""

        runStart = time.monotonic()
        timerStop = threading.Event()
        publishDiagnostics = bool(self.Debug.value())
        self._runDiagnostics = {}
        self.Diagnostics.set({})
        timerThread = threading.Thread(
            target = self._updateRunTime,
            args   = (runStart, timerStop),
            daemon = True)
        self.RunTime.set(0.0)
        self.Outcome.set(self.OUTCOME_RUNNING_C)
        timerThread.start()
        try:
            results = self._runCalibrationImpl(dev=dev)
        except _AdcDdrCalibrationStopped:
            self.Outcome.set(self.OUTCOME_STOPPED_C)
            publishDiagnostics = True
            raise
        except Exception as exc:
            self.Outcome.set(self.OUTCOME_FAILED_C)
            self.Message.set(f'FAILED: {exc}')
            publishDiagnostics = True
            raise
        else:
            self.Outcome.set(self.OUTCOME_PASSED_C)
            return results
        finally:
            runTime = time.monotonic()-runStart
            timerStop.set()
            timerThread.join()
            self.RunTime.set(runTime)
            if publishDiagnostics:
                self.Diagnostics.set(copy.deepcopy(self._runDiagnostics))

    def _runCalibrationImpl(self, *, dev: Any) -> dict[str, Any]:
        """Validate controls, execute the selected operation, and restore state."""

        # Fail early and clearly if the register model was constructed with a
        # geometry that disagrees with the RTL (for example a deviceFamily that
        # sets the wrong delay width). Otherwise a mismatch only surfaces as a
        # cryptic readback verify error partway through the scan.
        self._readout.checkGeometry()

        start = self.DelayStart.value()
        stop = self.DelayStop.value()
        settle = self.SettleTime.value()
        if start > stop:
            raise ValueError('DelayStart must not be greater than DelayStop')

        operation = self.Operation.value()
        self._deepPatternTesterActive = (
            bool(self.UsePatternTester.value()) and operation == self.FULL_C)
        if self._deepPatternTesterActive:
            # Fail before changing ADC state if the selected readout cannot
            # perform the requested deep hardware qualification.
            if not bool(self._readout.PatternCheck.get(read=True)):
                raise RuntimeError('ADC pattern tester is not present in this readout')
            if len(self._expectedPatterns) > 2:
                raise RuntimeError(
                    'ADC pattern tester supports at most two expected patterns')
            pn23Minimum = (23//self._readout._sampleBits)+1
            if (self.VerifyPn23.value() and
                    self.PatternTesterSamples.value() < pn23Minimum):
                raise ValueError(
                    f'PatternTesterSamples must be at least {pn23Minimum} '
                    f'for {self._readout._sampleBits}-bit PN23 verification')

        # Snapshot every mutable hardware setting before the operation. Verify,
        # failure, and stop paths restore these values in the common finally
        # block; only a successful full calibration retains newly selected taps.
        originalMode = self._config.OutputTestMode.get(read=True)
        originalFco = [variable.get(read=True) for variable in self._readout.FcoDelay.values()]
        originalData = self._readout._getDataDelays(read=True)
        results = {}
        retainResults = False
        self._runDiagnostics = {
            'TestMode': self._testMode,
            'ExpectedPatterns': sorted(self._expectedPatterns),
            'MeasurementBackend': 'Snapshot',
            'DeepPatternTester': {
                'enabled': self._deepPatternTesterActive,
                'samples': (
                    int(self.PatternTesterSamples.value())
                    if self._deepPatternTesterActive else 0),
            },
            'VerifyPn23': bool(self.VerifyPn23.value()),
            'Fco': {},
            'Data': {},
            'Final': {},
            'Current': {},
        }
        self.Results.set({})

        try:
            if operation == self.FULL_C:
                results = self._fullCalibration(list(range(start, stop+1)), settle)
            elif operation == self.VERIFY_CURRENT_C:
                results, passed = self._verifyCurrent(originalFco, originalData, settle, 0)
                if not passed:
                    self.Results.set(results)
                    raise RuntimeError('Current ADC delay verification failed')
            elif operation == self.VERIFY_GUARD_BAND_C:
                results, passed = self._verifyCurrent(
                    originalFco, originalData, settle, self.GuardBand.value())
                if not passed:
                    self.Results.set(results)
                    raise RuntimeError('ADC delay guard-band verification failed')
            else:
                raise ValueError(f'Unsupported calibration operation {operation}')
            self.Results.set(results)
            retainResults = operation == self.FULL_C
            return results
        finally:
            # Test mode is always temporary. Delay settings remain installed
            # only after a successful full calibration so ApplyResults and
            # downstream software see a coherent, qualified configuration.
            self._setTestMode(originalMode)
            if not retainResults:
                for variable, value in zip(self._readout.FcoDelay.values(), originalFco):
                    variable.set(value, write=True)
                self._readout._setDataDelays(dict(enumerate(originalData)))
            self._readout.Relock()

    def applyResults(self) -> None:
        """Reinstall the selected taps from the last complete calibration."""

        results = self.Results.value()
        # Partial scans and failed final qualifications can contain useful
        # diagnostics, but must never be applied as a hardware configuration.
        if (not results or not results.get('Final', {}).get('passed', False) or
                any('eye' not in lane for kind in ('Fco', 'Data')
                    for lane in results.get(kind, {}).values())):
            raise RuntimeError('No complete full-calibration result is available')
        for lane, result in results['Fco'].items():
            self._readout.FcoDelay[int(lane)].set(result['eye']['selected'], write=True)
        self._readout._setDataDelays({
            int(lane): result['eye']['selected']
            for lane, result in results['Data'].items()
        })
        self._readout.Relock()
