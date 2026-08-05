##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# Test methodology:
# - Sweep: Exercise ordinary, tied, boundary, full-range, narrow, guarded, and
#   circular passing windows over small representative delay ranges.
# - Stimulus: Supply deterministic tap-to-pass maps directly to the common eye
#   selector without PyRogue hardware access.
# - Checks: Verify selected taps, physical margins, boundary visibility,
#   wraparound reporting, deterministic ties, invalid-input rejection, and
#   topology-aware, overlap-safe parallel grouping plus restoration between
#   guard checks for coupled physical lanes. Exercise snapshot and pattern-tester
#   measurement backends plus verification progress, final qualification, and
#   live run-time reporting.
# - Timing: Fake register access and zero settling keep process tests short; the
#   live timer regression temporarily reduces its update interval.

import threading
import time

import pytest
import pyrogue as pr

from surf.devices.analog_devices import (
    AdcDdrCalibration,
    checkAdcDdrPn23,
    findAdcDdrEye,
    findAdcDdrEyes,
)


class FakeVariable:
    def __init__(self, value=0, getter=None):
        self._value = value
        self._getter = getter

    def get(self, read=False):
        return self._getter() if self._getter is not None else self._value

    def set(self, value, write=False):
        self._value = value

    def value(self):
        return self._value


class FakeConfig:
    def __init__(self):
        self.OutputTestMode = FakeVariable(0)
        self.ResetPNLong = FakeVariable(False)
        self.updateCount = 0

    def update(self):
        self.updateCount += 1


class FakePatternTester:
    def __init__(self, readout):
        self._readout = readout
        self.Alternating = FakeVariable(False)
        self.ReferenceChannel = FakeVariable(0)
        self.ChannelMask = FakeVariable(0)
        self.FcoMask = FakeVariable(0)
        self.DataMask = FakeVariable(0)
        self.PatternA = FakeVariable(0)
        self.PatternB = FakeVariable(0)
        self.Samples = FakeVariable(0)
        self.Sequence = FakeVariable(0)
        self.CheckedSamples = FakeVariable(0)
        self.ChannelPassed = FakeVariable(0)
        self.FcoPassed = FakeVariable(0)
        self.Busy = FakeVariable(False)
        self.TimedOut = FakeVariable(False)
        self.ConfigError = FakeVariable(False)
        self.Aborted = FakeVariable(False)
        self.PhaseAcquired = FakeVariable(False)
        self.AllChannelsPass = FakeVariable(False)
        self.AllFcoPass = FakeVariable(False)
        self.measurements = []

    def Start(self):
        alternating = bool(self.Alternating.value())
        mask = self.DataMask.value()
        patternA = self.PatternA.value() & mask
        patternB = self.PatternB.value() & mask
        sampleCount = self.Samples.value()
        channelMask = self.ChannelMask.value()
        channelPassed = 0
        for channel in range(self._readout._channels):
            if not channelMask & (1 << channel):
                continue
            samples = [
                self._readout._debugSample(channel, index) & mask
                for index in range(sampleCount)
            ]
            if alternating and samples:
                if samples[0] == patternA:
                    phase = 0
                elif samples[0] == patternB:
                    phase = 1
                else:
                    phase = None
                passed = phase is not None and all(
                    sample == (patternA, patternB)[(phase+index) % 2]
                    for index, sample in enumerate(samples)
                )
            else:
                passed = all(sample == patternA for sample in samples)
            if passed:
                channelPassed |= 1 << channel

        fcoMask = self.FcoMask.value()
        fcoPassed = self._readout._lockedMask() & fcoMask
        self.ChannelPassed.set(channelPassed)
        self.FcoPassed.set(fcoPassed)
        self.CheckedSamples.set(sampleCount)
        self.Busy.set(False)
        self.TimedOut.set(False)
        self.ConfigError.set(False)
        self.Aborted.set(False)
        self.PhaseAcquired.set(not alternating or bool(channelPassed))
        self.AllChannelsPass.set((channelPassed & channelMask) == channelMask)
        self.AllFcoPass.set((fcoPassed & fcoMask) == fcoMask)
        self.Sequence.set(self.Sequence.value()+1)
        self.measurements.append({
            'delays': tuple(
                variable.value() for variable in self._readout.DataDelay.values()),
            'channelMask': channelMask,
            'dataMask': mask,
            'samples': sampleCount,
        })

    def Abort(self):
        self.Busy.set(False)
        self.Aborted.set(True)
        self.Sequence.set(self.Sequence.value()+1)


class FakeReadout:
    def __init__(self):
        self._dataLanes = 2
        self._fcoLanes = 1
        self._channels = 2
        self._sampleBits = 14
        self._delayBits = 3
        self.FcoDelay = {0: FakeVariable(3)}
        self.FcoWord = {0: FakeVariable(0x3F00)}
        self.DataDelay = {0: FakeVariable(2), 1: FakeVariable(4)}
        self.PatternCheck = FakeVariable(True)
        self.SnapshotSequence = FakeVariable(0)
        self.LockedMask = FakeVariable(getter=self._lockedMask)
        self.nodes = {
            f'DebugSampleRaw[{channel}][{index}]': FakeVariable(
                getter=lambda channel=channel, index=index: self._debugSample(channel, index))
            for channel in range(2)
            for index in range(4)
        }
        self.relockCount = 0
        self.snapshotDelays = []
        self.dataDelayWrites = []
        self.PatternTester = FakePatternTester(self)

    def _lockedMask(self):
        return int(2 <= self.FcoDelay[0].value() <= 5)

    def _debugSample(self, channel, index):
        tap = self.DataDelay[channel].value()
        passing = (1 <= tap <= 4) if channel == 0 else (3 <= tap <= 7)
        if not passing:
            return 0
        return 0x2AAA if index % 2 == 0 else 0x1555

    def _getDebugSamples(self, read=False):
        return [
            [
                self.nodes[f'DebugSampleRaw[{channel}][{index}]'].get(read=read)
                for index in range(4)
            ]
            for channel in range(self._channels)
        ]

    def _getDataDelays(self, read=False):
        return [variable.get(read=read) for variable in self.DataDelay.values()]

    def _setDataDelays(self, values):
        self.dataDelayWrites.append(dict(values))
        for lane, value in values.items():
            self.DataDelay[lane].set(value, write=True)

    def Snapshot(self):
        self.snapshotDelays.append(tuple(
            variable.value() for variable in self.DataDelay.values()))
        self.SnapshotSequence.set(self.SnapshotSequence.value()+1)

    def Relock(self):
        self.relockCount += 1


class CoupledFakeReadout(FakeReadout):
    def __init__(self):
        super().__init__()
        self._channels = 1
        self.nodes = {
            f'DebugSampleRaw[0][{index}]': FakeVariable(
                getter=lambda index=index: self._debugSample(0, index))
            for index in range(4)
        }

    def _debugSample(self, channel, index):
        # Both physical lanes form one logical sample. Each lane's guard points
        # pass against the selected value of the other lane, but the combination
        # of both upper guard points does not.
        passing = not (
            self.DataDelay[0].value() == 3 and
            self.DataDelay[1].value() == 5)
        if not passing:
            return 0
        return 0x2AAA if index % 2 == 0 else 0x1555


class MaskedCoupledFakeReadout(FakeReadout):
    def __init__(self):
        super().__init__()
        self._channels = 1
        self.DataDelay = {0: FakeVariable(0), 1: FakeVariable(0)}
        self.nodes = {
            f'DebugSampleRaw[0][{index}]': FakeVariable(
                getter=lambda index=index: self._debugSample(0, index))
            for index in range(4)
        }

    def _debugSample(self, channel, index):
        expected = 0x2AAA if index % 2 == 0 else 0x1555
        sample = 0
        if 1 <= self.DataDelay[0].value() <= 3:
            sample |= expected & 0x003F
        if 4 <= self.DataDelay[1].value() <= 6:
            sample |= expected & 0x3FC0
        return sample


class PhaseMismatchedCoupledFakeReadout(MaskedCoupledFakeReadout):
    def _debugSample(self, channel, index):
        expected = 0x2AAA if index % 2 == 0 else 0x1555
        opposite = 0x1555 if index % 2 == 0 else 0x2AAA
        sample = 0
        if 1 <= self.DataDelay[0].value() <= 3:
            sample |= expected & 0x003F
        if 4 <= self.DataDelay[1].value() <= 6:
            sample |= opposite & 0x3FC0
        return sample


class MultiWindowFcoFakeReadout(MaskedCoupledFakeReadout):
    def __init__(self):
        super().__init__()
        self._fcoLanes = 2
        self.FcoDelay = {0: FakeVariable(0), 1: FakeVariable(0)}
        self.FcoWord = {0: FakeVariable(0xF0), 1: FakeVariable(0xF0)}

    def _lockedMask(self):
        mask = 0
        if self.FcoDelay[0].value() in (1, 2, 3, 5, 6):
            mask |= 0x1
        if self.FcoDelay[1].value() in (1, 2, 4, 5, 6):
            mask |= 0x2
        return mask

    def _fcoPhaseAligned(self):
        lowWindow = (
            self.FcoDelay[0].value() in (1, 2, 3) and
            self.FcoDelay[1].value() in (1, 2))
        highWindow = (
            self.FcoDelay[0].value() in (5, 6) and
            self.FcoDelay[1].value() in (4, 5, 6))
        return lowWindow or highWindow

    def _debugSample(self, channel, index):
        expected = 0x2AAA if index % 2 == 0 else 0x1555
        opposite = 0x1555 if index % 2 == 0 else 0x2AAA
        sample = 0
        if 1 <= self.DataDelay[0].value() <= 3:
            sample |= expected & 0x003F
        if 4 <= self.DataDelay[1].value() <= 6:
            upper = expected if self._fcoPhaseAligned() else opposite
            sample |= upper & 0x3FC0
        return sample


def _pn23Words(state=0x654321, count=4, width=14):
    mask = (1 << 23)-1
    words = []
    for _ in range(count):
        word = 0
        for _ in range(width):
            word = (word << 1) | ((state >> 22) & 1)
            state = (
                ((state << 1) & mask) |
                (((state >> 22) ^ (state >> 17)) & 1))
        words.append(word)
    return words


class Pn23FakeReadout(FakeReadout):
    def __init__(self, config, fault=None):
        super().__init__()
        self._config = config
        self._fault = fault
        self._pn23 = _pn23Words(count=5)

    def _debugSample(self, channel, index):
        if self._config.OutputTestMode.value() != 5:
            return super()._debugSample(channel, index)
        if self._fault == 'channelShift' and channel == 1:
            return self._pn23[index+1]
        sample = self._pn23[index]
        if self._fault == 'commonCorruption' and index == 2:
            sample ^= 0x1
        return sample


class Pn23MultiWindowFcoFakeReadout(MultiWindowFcoFakeReadout):
    def __init__(self, config):
        super().__init__()
        self._config = config
        self._pn23 = _pn23Words()

    def _fcoPhaseAligned(self):
        # Both preferred and alternate FCO combinations look valid under the
        # repetitive checkerboard; PN23 must disambiguate them.
        return True

    def _debugSample(self, channel, index):
        if self._config.OutputTestMode.value() != 5:
            return super()._debugSample(channel, index)
        sample = self._pn23[index]
        if self.FcoDelay[1].value() == 5 and index == 2:
            sample ^= 0x1
        return sample


def test_selects_center_and_reports_margins():
    eye = findAdcDdrEye({0: False, 1: True, 2: True, 3: True, 4: True, 5: False})

    assert eye.start == 1
    assert eye.end == 4
    assert eye.width == 4
    assert eye.selected == 2
    assert eye.leftMargin == 1
    assert eye.rightMargin == 2
    assert eye.leftBounded
    assert eye.rightBounded
    assert eye.contains(3)
    assert not eye.contains(5)


def test_tie_selects_lowest_center():
    eye = findAdcDdrEye({
        0: False,
        1: True,
        2: True,
        3: False,
        4: False,
        5: True,
        6: True,
        7: False,
    })

    assert (eye.start, eye.end, eye.selected) == (1, 2, 1)


def test_returns_all_qualifying_eyes_in_priority_order():
    eyes = findAdcDdrEyes({
        0: False,
        1: True,
        2: True,
        3: False,
        4: True,
        5: True,
        6: True,
        7: False,
    })

    assert [(eye.start, eye.end, eye.selected) for eye in eyes] == [
        (4, 6, 5),
        (1, 2, 1),
    ]
    assert findAdcDdrEye({tap: True for tap in range(4)}) == findAdcDdrEyes(
        {tap: True for tap in range(4)})[0]


def test_pn23_recurrence_acquires_arbitrary_phase_and_handles_formatting():
    words = _pn23Words()

    result = checkAdcDdrPn23(words, 14)
    assert result['passed']
    assert result['selected']['name'] == 'asCaptured'
    assert result['selected']['checkedBits'] == 33

    # Datasheet PN23 values are shown after two's-complement formatting, which
    # flips the logical sample MSB relative to the underlying PN bit stream.
    formatted = [0x1FFF, 0x1FE0, 0x2001, 0x1C00]
    result = checkAdcDdrPn23(formatted, 14)
    assert result['passed']
    assert result['selected']['name'] == 'formatMsbInverted'

    corrupted = list(words)
    corrupted[2] ^= 0x1
    assert not checkAdcDdrPn23(corrupted, 14)['passed']
    assert not checkAdcDdrPn23([0, 0, 0, 0], 14)['passed']


def test_minimum_width_and_guard_band_reject_narrow_windows():
    passing = {tap: 1 <= tap <= 3 for tap in range(5)}

    assert findAdcDdrEye(passing, minimumWidth=3).width == 3
    assert findAdcDdrEye(passing, guardBand=1).selected == 2
    with pytest.raises(RuntimeError, match='at least 4 taps'):
        findAdcDdrEye(passing, minimumWidth=4)
    with pytest.raises(RuntimeError, match='at least 5 taps'):
        findAdcDdrEye(passing, guardBand=2)


def test_scan_boundary_visibility():
    left = findAdcDdrEye({0: True, 1: True, 2: False, 3: False})
    right = findAdcDdrEye({0: False, 1: False, 2: True, 3: True})
    full = findAdcDdrEye({tap: True for tap in range(4)})

    assert not left.leftBounded and left.rightBounded
    assert right.leftBounded and not right.rightBounded
    assert not full.leftBounded and not full.rightBounded


def test_circular_window_merges_scan_boundaries():
    passing = {tap: tap in (0, 1, 6, 7) for tap in range(8)}
    linear = findAdcDdrEye(passing)
    circular = findAdcDdrEye(passing, circular=True)

    assert linear.width == 2
    assert (circular.start, circular.end) == (6, 1)
    assert circular.width == 4
    assert circular.selected == 7
    assert circular.leftMargin == 1
    assert circular.rightMargin == 2
    assert circular.wraps
    assert circular.leftBounded and circular.rightBounded
    assert circular.contains(0)
    assert circular.contains(7)
    assert not circular.contains(3)


@pytest.mark.parametrize(
    ('passing', 'kwargs', 'exception', 'message'),
    [
        ({}, {}, ValueError, 'must not be empty'),
        ({0: False, 1: False}, {}, RuntimeError, 'no passing'),
        ({0: True, 2: True}, {}, ValueError, 'consecutive'),
        ({0: True}, {'minimumWidth': 0}, ValueError, 'at least one'),
        ({0: True}, {'guardBand': -1}, ValueError, 'must not be negative'),
    ])
def test_rejects_invalid_scans(passing, kwargs, exception, message):
    with pytest.raises(exception, match=message):
        findAdcDdrEye(passing, **kwargs)


def make_calibration():
    config = FakeConfig()
    readout = FakeReadout()
    calibration = AdcDdrCalibration(
        name='Calibration',
        config=config,
        readout=readout,
        configUpdate=config.update)
    root = pr.Root(name='Root', pollEn=False)
    root.add(calibration)
    root.start()
    calibration._testRoot = root
    calibration.DelayStop.set(7)
    calibration.MinimumEyeWidth.set(3)
    calibration.GuardBand.set(1)
    calibration.SampleCount.set(1)
    calibration.SettleTime.set(0.0)
    calibration._runEn = True
    return calibration, config, readout, root


def test_ad9681_topology_builds_one_parallel_lane_group():
    config = FakeConfig()
    readout = FakeReadout()
    readout._dataLanes = 16
    readout._channels = 8

    calibration = AdcDdrCalibration(
        name='Calibration',
        config=config,
        readout=readout,
        dataLaneToChannel=tuple(range(8))+tuple(range(8)),
        dataLaneMasks=(0x003F,)*8+(0x3FC0,)*8)

    assert calibration._dataLaneGroups == (tuple(range(16)),)


@pytest.fixture
def calibration_fixture():
    calibration, config, readout, root = make_calibration()
    try:
        yield calibration, config, readout
    finally:
        calibration._runEn = False
        root.stop()


def test_full_calibration_applies_results_and_can_reapply(calibration_fixture):
    calibration, config, readout = calibration_fixture

    assert calibration.Debug.value() is True
    assert calibration.UsePatternTester.value() is False
    results = calibration._runCalibration(dev=calibration)

    assert results['Fco'][0]['eye']['selected'] == 3
    assert results['Data'][0]['eye']['selected'] == 2
    assert results['Data'][1]['eye']['selected'] == 5
    assert results['Final']['passed']
    assert config.OutputTestMode.value() == 0
    assert config.updateCount == 2
    assert readout.FcoDelay[0].value() == 3
    assert readout.DataDelay[0].value() == 2
    assert readout.DataDelay[1].value() == 5
    assert calibration._dataLaneGroups == ((0, 1),)
    assert readout.dataDelayWrites[:8] == [
        {0: tap, 1: tap}
        for tap in range(8)
    ]
    assert readout.dataDelayWrites[8] == {0: 2, 1: 5}
    assert readout.snapshotDelays == [(tap, tap) for tap in range(8)] + [(2, 5)]
    assert calibration.RunTime.value() > 0.0

    readout.FcoDelay[0].set(0)
    readout.DataDelay[0].set(0)
    readout.DataDelay[1].set(0)
    calibration.applyResults()
    assert readout.FcoDelay[0].value() == 3
    assert readout.DataDelay[0].value() == 2
    assert readout.DataDelay[1].value() == 5


def test_full_calibration_can_use_pattern_tester(calibration_fixture):
    calibration, _, readout = calibration_fixture
    calibration.UsePatternTester.set(True)

    results = calibration._runCalibration(dev=calibration)

    assert results['Data'][0]['eye']['selected'] == 2
    assert results['Data'][1]['eye']['selected'] == 5
    assert results['Final']['passed']
    assert readout.snapshotDelays == []
    assert len(readout.PatternTester.measurements) == 9
    assert all(
        measurement['samples'] == 4
        for measurement in readout.PatternTester.measurements)
    assert calibration.Diagnostics.value()['MeasurementBackend'] == 'PatternTester'
    assert calibration.RunTime.value() > 0.0


@pytest.mark.parametrize('usePatternTester', [False, True])
def test_full_calibration_adds_snapshot_pn23_qualification(usePatternTester):
    config = FakeConfig()
    readout = Pn23FakeReadout(config)
    calibration = AdcDdrCalibration(
        name='Calibration',
        config=config,
        readout=readout,
        configUpdate=config.update,
        pn23Reset=config.ResetPNLong)
    root = pr.Root(name='Root', pollEn=False)
    root.add(calibration)
    root.start()
    try:
        calibration.DelayStop.set(7)
        calibration.MinimumEyeWidth.set(3)
        calibration.GuardBand.set(1)
        calibration.SampleCount.set(1)
        calibration.SettleTime.set(0.0)
        calibration.UsePatternTester.set(usePatternTester)
        calibration._runEn = True

        results = calibration._runCalibration(dev=calibration)

        assert calibration.VerifyPn23.value()
        assert results['Final']['checkerboardPassed']
        assert results['Final']['pn23']['enabled']
        assert results['Final']['pn23']['performed']
        assert results['Final']['pn23']['coherencePassed']
        assert results['Final']['pn23']['recurrence']['passed']
        assert results['Final']['pn23']['passed']
        assert results['Final']['passed']
        assert config.OutputTestMode.value() == 0
        assert not config.ResetPNLong.value()
        # PN23 always uses one atomic debug snapshot, independently of the data
        # eye and checkerboard backend selected for the rest of calibration.
        assert readout.snapshotDelays[-1] == (2, 5)
    finally:
        calibration._runEn = False
        root.stop()


@pytest.mark.parametrize(
    ('fault', 'coherencePassed', 'recurrencePassed'),
    [
        ('channelShift', False, True),
        ('commonCorruption', True, False),
    ])
def test_pn23_qualification_rejects_relative_and_common_errors(
        fault, coherencePassed, recurrencePassed):
    config = FakeConfig()
    readout = Pn23FakeReadout(config, fault=fault)
    calibration = AdcDdrCalibration(
        name='Calibration',
        config=config,
        readout=readout,
        configUpdate=config.update,
        pn23Reset=config.ResetPNLong)
    root = pr.Root(name='Root', pollEn=False)
    root.add(calibration)
    root.start()
    try:
        calibration.DelayStop.set(7)
        calibration.MinimumEyeWidth.set(3)
        calibration.GuardBand.set(1)
        calibration.SampleCount.set(1)
        calibration.SettleTime.set(0.0)
        calibration._runEn = True

        with pytest.raises(RuntimeError, match='Final full-channel pattern qualification failed'):
            calibration._runCalibration(dev=calibration)

        pn23 = calibration.Results.value()['Final']['pn23']
        assert pn23['coherencePassed'] is coherencePassed
        assert pn23['recurrence']['passed'] is recurrencePassed
        assert not pn23['passed']
        assert config.OutputTestMode.value() == 0
        assert readout.FcoDelay[0].value() == 3
        assert readout.DataDelay[0].value() == 2
        assert readout.DataDelay[1].value() == 4
    finally:
        calibration._runEn = False
        root.stop()


def test_pattern_tester_selection_requires_hardware_capability(calibration_fixture):
    calibration, _, readout = calibration_fixture
    calibration.UsePatternTester.set(True)
    readout.PatternCheck.set(False)

    with pytest.raises(RuntimeError, match='pattern tester is not present'):
        calibration._runCalibration(dev=calibration)

    assert calibration.RunTime.value() > 0.0


def test_run_time_updates_while_calibration_is_running(calibration_fixture):
    calibration, _, _ = calibration_fixture
    started = threading.Event()
    release = threading.Event()
    calibration.RUN_TIME_UPDATE_INTERVAL_C = 0.01

    def operation(*, dev):
        started.set()
        assert release.wait(1.0)

    calibration._runCalibrationImpl = operation
    worker = threading.Thread(
        target=calibration._runCalibration,
        kwargs={'dev': calibration})
    worker.start()
    try:
        assert started.wait(1.0)
        deadline = time.monotonic()+1.0
        while calibration.RunTime.value() == 0.0 and time.monotonic() < deadline:
            time.sleep(0.005)
        runningTime = calibration.RunTime.value()
        assert runningTime > 0.0
    finally:
        release.set()
        worker.join(1.0)

    assert not worker.is_alive()
    assert calibration.RunTime.value() >= runningTime


def test_failed_calibration_restores_mode_and_all_delays(calibration_fixture):
    calibration, config, readout = calibration_fixture
    calibration.MinimumEyeWidth.set(6)
    config.OutputTestMode.set(7)

    with pytest.raises(RuntimeError, match='at least 6 taps'):
        calibration._runCalibration(dev=calibration)

    assert config.OutputTestMode.value() == 7
    assert readout.FcoDelay[0].value() == 3
    assert readout.DataDelay[0].value() == 2
    assert readout.DataDelay[1].value() == 4
    assert calibration.RunTime.value() > 0.0


def test_failed_data_scan_reports_lane_and_retains_partial_results(calibration_fixture):
    calibration, _, readout = calibration_fixture
    calibration.Debug.set(True)
    for node in readout.nodes.values():
        node._getter = lambda: 0

    with pytest.raises(RuntimeError, match='Data lane 0: scan contains no passing'):
        calibration._runCalibration(dev=calibration)

    results = calibration.Results.value()
    assert results['Fco'][0]['eye']['selected'] == 3
    assert not any(results['Data'][0]['passing'].values())
    assert results['Data'][0]['diagnostics'][0]['expected'] == [0x1555, 0x2AAA]
    assert results['Data'][0]['diagnostics'][0]['captures'][0]['raw'] == [0, 0, 0, 0]
    diagnostics = calibration.Diagnostics.value()
    assert diagnostics['Fco'][0][0]['word'] == 0x3F00
    assert diagnostics['Current'] == {'kind': 'Data', 'lanes': [0, 1], 'tap': 7}


def test_verify_current_and_guard_band_restore_hardware_state(calibration_fixture):
    calibration, config, readout = calibration_fixture
    calibration.Operation.set(calibration.VERIFY_CURRENT_C)

    results = calibration._runCalibration(dev=calibration)
    assert all(result['passed'] for lanes in results.values() for result in lanes.values())
    assert calibration.TotalSteps.value() == 3
    assert calibration.Step.value() == 3
    assert calibration.Progress.value() == 1.0

    calibration.Operation.set(calibration.VERIFY_GUARD_BAND_C)
    calibration.GuardBand.set(2)
    with pytest.raises(RuntimeError, match='guard-band verification failed'):
        calibration._runCalibration(dev=calibration)

    assert not calibration.Results.value()['Data'][0]['passed']
    assert config.OutputTestMode.value() == 0
    assert readout.FcoDelay[0].value() == 3
    assert readout.DataDelay[0].value() == 2
    assert readout.DataDelay[1].value() == 4
    assert calibration.TotalSteps.value() == 9
    assert calibration.Step.value() == 9
    assert calibration.Progress.value() == 1.0
    assert calibration.RunTime.value() > 0.0


def test_guard_verification_restores_each_coupled_lane_before_advancing():
    config = FakeConfig()
    readout = CoupledFakeReadout()
    calibration = AdcDdrCalibration(
        name='Calibration',
        config=config,
        readout=readout,
        dataLaneToChannel=(0, 0),
        configUpdate=config.update)
    root = pr.Root(name='Root', pollEn=False)
    root.add(calibration)
    root.start()
    try:
        calibration.SampleCount.set(1)
        calibration.SettleTime.set(0.0)
        calibration._runEn = True
        assert calibration._dataLaneGroups == ((0,), (1,))
        results, passed = calibration._verifyCurrent([3], [2, 4], 0.0, 1)

        assert passed
        assert all(result['passed'] for lanes in results.values() for result in lanes.values())
        assert readout.DataDelay[0].value() == 2
        assert readout.DataDelay[1].value() == 4
    finally:
        calibration._runEn = False
        root.stop()


@pytest.mark.parametrize('usePatternTester', [False, True])
def test_full_calibration_masks_unaligned_partner_lane(usePatternTester):
    config = FakeConfig()
    readout = MaskedCoupledFakeReadout()
    calibration = AdcDdrCalibration(
        name='Calibration',
        config=config,
        readout=readout,
        dataLaneToChannel=(0, 0),
        dataLaneMasks=(0x003F, 0x3FC0),
        configUpdate=config.update)
    root = pr.Root(name='Root', pollEn=False)
    root.add(calibration)
    root.start()
    try:
        calibration.DelayStop.set(7)
        calibration.MinimumEyeWidth.set(3)
        calibration.GuardBand.set(1)
        calibration.SampleCount.set(1)
        calibration.SettleTime.set(0.0)
        calibration.UsePatternTester.set(usePatternTester)
        calibration._runEn = True

        results = calibration._runCalibration(dev=calibration)

        assert calibration._dataLaneGroups == ((0, 1),)
        assert results['Data'][0]['eye']['selected'] == 2
        assert results['Data'][1]['eye']['selected'] == 5
        assert results['Final']['passed']
        if usePatternTester:
            assert readout.snapshotDelays == []
            assert [measurement['delays'] for measurement in readout.PatternTester.measurements] == (
                [delays for tap in range(8) for delays in ((tap, tap), (tap, tap))] +
                [(2, 5)])
            assert [measurement['dataMask'] for measurement in
                    readout.PatternTester.measurements[:-1]] == [0x003F, 0x3FC0]*8
        else:
            assert readout.snapshotDelays == (
                [(tap, tap) for tap in range(8)] +
                [(2, 5)])
        assert readout.DataDelay[0].value() == 2
        assert readout.DataDelay[1].value() == 5
    finally:
        calibration._runEn = False
        root.stop()


def test_final_qualification_rejects_split_lane_phase_mismatch():
    config = FakeConfig()
    readout = PhaseMismatchedCoupledFakeReadout()
    calibration = AdcDdrCalibration(
        name='Calibration',
        config=config,
        readout=readout,
        dataLaneToChannel=(0, 0),
        dataLaneMasks=(0x003F, 0x3FC0),
        configUpdate=config.update)
    root = pr.Root(name='Root', pollEn=False)
    root.add(calibration)
    root.start()
    try:
        calibration.DelayStop.set(7)
        calibration.MinimumEyeWidth.set(3)
        calibration.GuardBand.set(1)
        calibration.SampleCount.set(1)
        calibration.SettleTime.set(0.0)
        calibration._runEn = True

        with pytest.raises(RuntimeError, match='Final full-channel pattern qualification failed'):
            calibration._runCalibration(dev=calibration)

        results = calibration.Results.value()
        assert all('eye' in results['Data'][lane] for lane in range(2))
        assert not results['Final']['passed']
        assert not results['Final']['captures'][0]['channels'][0]['passed']
        assert readout.FcoDelay[0].value() == 3
        assert readout.DataDelay[0].value() == 0
        assert readout.DataDelay[1].value() == 0
        with pytest.raises(RuntimeError, match='No complete full-calibration result'):
            calibration.applyResults()
    finally:
        calibration._runEn = False
        root.stop()


@pytest.mark.parametrize('usePatternTester', [False, True])
def test_final_qualification_retries_alternate_fco_eye_combinations(usePatternTester):
    config = FakeConfig()
    readout = MultiWindowFcoFakeReadout()
    calibration = AdcDdrCalibration(
        name='Calibration',
        config=config,
        readout=readout,
        dataLaneToChannel=(0, 0),
        dataLaneMasks=(0x003F, 0x3FC0),
        configUpdate=config.update)
    root = pr.Root(name='Root', pollEn=False)
    root.add(calibration)
    root.start()
    try:
        calibration.DelayStop.set(7)
        calibration.MinimumEyeWidth.set(2)
        calibration.GuardBand.set(0)
        calibration.SampleCount.set(1)
        calibration.SettleTime.set(0.0)
        calibration.UsePatternTester.set(usePatternTester)
        calibration._runEn = True

        results = calibration._runCalibration(dev=calibration)

        assert len(results['Fco'][0]['eyes']) == 2
        assert len(results['Fco'][1]['eyes']) == 2
        assert results['Final']['passed']
        assert [attempt['fcoDelays'] for attempt in results['Final']['attempts']] == [
            [2, 5],
            [2, 1],
        ]
        assert not results['Final']['attempts'][0]['passed']
        assert results['Final']['attempts'][1]['passed']
        assert results['Fco'][0]['eye']['selected'] == 2
        assert results['Fco'][1]['eye']['selected'] == 1
        assert readout.FcoDelay[0].value() == 2
        assert readout.FcoDelay[1].value() == 1
        assert readout.DataDelay[0].value() == 2
        assert readout.DataDelay[1].value() == 5
    finally:
        calibration._runEn = False
        root.stop()


def test_pn23_failure_retries_alternate_fco_eye_combination_in_checkerboard_mode():
    config = FakeConfig()
    readout = Pn23MultiWindowFcoFakeReadout(config)
    calibration = AdcDdrCalibration(
        name='Calibration',
        config=config,
        readout=readout,
        dataLaneToChannel=(0, 0),
        dataLaneMasks=(0x003F, 0x3FC0),
        configUpdate=config.update,
        pn23Reset=config.ResetPNLong)
    root = pr.Root(name='Root', pollEn=False)
    root.add(calibration)
    root.start()
    try:
        calibration.DelayStop.set(7)
        calibration.MinimumEyeWidth.set(2)
        calibration.GuardBand.set(0)
        calibration.SampleCount.set(1)
        calibration.SettleTime.set(0.0)
        calibration._runEn = True

        results = calibration._runCalibration(dev=calibration)

        attempts = results['Final']['attempts']
        assert [attempt['fcoDelays'] for attempt in attempts] == [[2, 5], [2, 1]]
        assert all(
            attempt['qualification']['checkerboardPassed']
            for attempt in attempts)
        assert not attempts[0]['qualification']['pn23']['passed']
        assert attempts[1]['qualification']['pn23']['passed']
        assert attempts[1]['passed']
        assert results['Fco'][1]['eye']['selected'] == 1
    finally:
        calibration._runEn = False
        root.stop()


def test_cancellation_is_graceful_and_restores_hardware(calibration_fixture):
    calibration, config, readout = calibration_fixture
    originalCheck = calibration._checkRun
    checks = 0

    def stop_during_fco_scan():
        nonlocal checks
        checks += 1
        if checks == 3:
            calibration._runEn = False
        originalCheck()

    calibration._checkRun = stop_during_fco_scan
    calibration._process()

    assert calibration.Message.value() == 'Calibration stopped'
    assert calibration.Step.value() == 2
    assert calibration.Progress.value() < 1.0
    assert config.OutputTestMode.value() == 0
    assert readout.FcoDelay[0].value() == 3
    assert readout.DataDelay[0].value() == 2
    assert readout.DataDelay[1].value() == 4
    assert calibration.RunTime.value() > 0.0
