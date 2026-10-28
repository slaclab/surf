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
# - Sweep: the two-sided horizontal bathtub of the GTHE3 eye scan (sweep
#   construction, per-point adaptive prescale, Q-scale tail fits, measured and
#   extrapolated openings, link-drop handling, typed CLOSED, ABORTED and
#   UNLOCKED results) and its PyRogue Process front end (Start, Stop, Status,
#   Message) over an emulated GTHE3 DRP memory.
# - Stimulus: real Rogue transactions against Gthe3EyeModel with a seeded
#   dual-Dirac BER model (sigma 0.035 UI, edges at +-0.30 UI, UT_SIGN 1
#   shifted by one count), a constant-BER closed eye, and a callable RX reset
#   hook whose ready() follows a scripted sequence of link drops.
# - Checks: the default sweep covers every count of +-0.5 UI exactly once and
#   always contains 0; the Gaussian eye recovers sigma and the 1e-12 opening,
#   never reports a zero-error point as BER 0, and never breaks the phase
#   unification rule; a closed eye, an abort before the first point and a
#   second link drop end in typed results with consistent arrays; a first link
#   drop discards and re-measures the point; invalid arguments are refused
#   before any bus access; Stop ends a Process run within 1 s with the
#   registers restored.
# - Timing: countReads=1 and a zero settle keep the emulated runs short; the
#   model steps on status reads, so no test waits on real hardware time.

import sys
import threading
import time

import pytest

pr = pytest.importorskip('pyrogue', reason='Eye-scan tests require Rogue/PyRogue')

import numpy as np  # noqa: E402
rogue = pytest.importorskip('rogue', reason='Eye-scan tests require Rogue/PyRogue')

from surf.xilinx.eyescan import (  # noqa: E402
    GTHE3,
    BathtubResult,
    EyeScanEngine,
    EyeScanPort,
    ScanControl,
    ScanStatus,
    loadResult,
    maskWords,
    openRegion,
    qfunc,
    qinv,
    sdataMask,
)

from tests.xilinx.eyescan.gthe3_eye_model import makeGtRoot  # noqa: E402

SIGMA = 0.035
EDGE = 0.30
HALF = 64
FLOOR = 1e-9


def gauss(horz, ut):
    """Dual-Dirac BER of the seeded eye; UT_SIGN 1 is shifted by one count."""
    x = (horz + ut) / (2.0 * HALF)
    return 0.5 * (qfunc((EDGE - x) / SIGMA) + qfunc((x + EDGE) / SIGMA))


def closed(horz, ut):
    return 1e-3


class Hook:
    """Callable RX reset hook; ready() is False on the scripted call numbers.

    The activation handshake polls ready() a timing dependent number of times,
    so only the calls the scan loop makes are counted and scripted. With
    ``desyncOnDrop`` a scripted drop also leaves the model's sampler out of
    step, as the PHY re-init behind a real drop can.
    """

    def __init__(self, model, falseCalls=(), desyncOnDrop=False):
        self.model = model
        self.falseCalls = set(falseCalls)
        self.desyncOnDrop = desyncOnDrop
        self.calls = 0
        self.pulses = 0

    def pulse(self):
        self.pulses += 1
        self.model.pmaReset()

    def ready(self):
        # Frame 1 is the child's ready wrapper, frame 2 the engine caller
        if sys._getframe(2).f_code.co_name == '_handshake':
            return True
        self.calls += 1
        ready = self.calls not in self.falseCalls
        if not ready and self.desyncOnDrop:
            self.model.desynced = True
        return ready


def seedWords(model, gt):
    """Raw words of the scan registers with the control word's enable bits masked."""
    words = model.seedSnapshot(gt)
    words[model._pos.ctl[0]] &= ~0x0300
    return words


def warmRig(berFn, falseCalls=(), withHook=True, **kw):
    """Started root with an already active sampler and a scripted hook (none if withHook is False)."""
    kw.setdefault('countReads', 1)
    root, gt, model = makeGtRoot(requireReset=False, berFn=berFn, **kw)
    model.setField(gt.ES_ERRDET_EN, 1)
    model.setField(gt.ES_EYE_SCAN_EN, 1)
    model.activate()
    hook = None
    if withHook:
        hook = Hook(model, falseCalls)
        gt.EyeScan.setRxReset(hook.pulse, hook.ready, settle=0.0, fallWait=0.05, timeout=0.5)
    return root, gt, model, hook


@pytest.fixture
def rigs():
    roots = []

    def make(*args, **kw):
        rig = warmRig(*args, **kw)
        roots.append(rig[0])
        return rig
    yield make
    for root in roots:
        root.stop()


@pytest.fixture(scope='module')
def gaussian():
    """One full-range bathtub of the Gaussian eye from a cold lane, shared by the checks."""
    root, gt, model = makeGtRoot(requireReset=True, berFn=gauss, countReads=1)
    before = seedWords(model, gt)
    hook = Hook(model)
    gt.EyeScan.setRxReset(hook.pulse, hook.ready, settle=0.0, fallWait=0.05, timeout=0.5)
    try:
        result = gt.EyeScan.runBathtub(floor=FLOOR, probeWindow=0.3)
        yield SimpleRun(result, gt, model, hook, before)
    finally:
        root.stop()


class SimpleRun:
    def __init__(self, result, gt, model, hook, before):
        self.result = result
        self.gt = gt
        self.model = model
        self.hook = hook
        self.before = before


def test_gaussian_eye_bathtub_is_ok_with_both_fits(gaussian):
    res = gaussian.result

    assert isinstance(res, BathtubResult)
    assert res.status is ScanStatus.OK, res.message
    assert res.openingAtFloorUI is not None and res.openingAtFloorUI > 0
    assert res.leftFit.ok and res.rightFit.ok, (res.leftFit.reason, res.rightFit.reason)
    assert res.leftFit.sigma == pytest.approx(SIGMA, rel=0.05)
    assert res.rightFit.sigma == pytest.approx(SIGMA, rel=0.05)
    assert res.extrapolated is True and res.insufficientData is False
    truth = 2.0 * (EDGE - SIGMA * qinv(2e-12))
    assert res.openingAtTargetUI == pytest.approx(truth, abs=0.01)
    assert res.targetBer == 1e-12
    assert res.linkDrops == 0
    assert gaussian.hook.pulses == 1


def test_gaussian_eye_sweep_arrays_are_full_and_aligned(gaussian):
    res = gaussian.result
    n = 2 * HALF + 1

    assert np.array_equal(res.horzCounts, np.arange(-HALF, HALF + 1))
    assert res.uiPerCount == pytest.approx(1.0 / (2 * HALF))
    assert res.errors.shape == (2, n) and res.bits.shape == (2, n)
    assert res.errors.dtype == np.int64 and res.bits.dtype == np.int64
    for column in (res.prescale, res.ber, res.berUpper, res.isBound):
        assert column.shape == (n,)
    assert np.all(np.diff(res.horzCounts) > 0)
    assert np.all((res.bits > 0).any(axis=0))


def test_gaussian_eye_never_reports_ber_zero(gaussian):
    res = gaussian.result

    assert res.isBound.any()
    assert not np.any(res.ber == 0)
    assert np.all(np.isnan(res.ber[res.isBound]))
    assert np.all(res.berUpper[res.isBound] <= FLOOR)
    measured = res.bits.sum(axis=0) > 0
    assert np.all(np.isfinite(res.berUpper[measured]))
    seen = np.isfinite(res.ber)
    assert np.all(res.berUpper[seen] >= res.ber[seen])
    assert gaussian.model.phaseViolations == 0


def test_gaussian_eye_opening_uses_the_upper_bound_of_every_point(gaussian):
    res = gaussian.result
    confidence = res.meta['confidence']

    region = openRegion(res.horzCounts, res.errors, res.bits, FLOOR, confidence)
    assert region is not None
    first, last = region
    assert res.openingAtFloorUI == pytest.approx(
        (res.horzCounts[last] - res.horzCounts[first]) * res.uiPerCount)
    assert np.all(res.berUpper[first:last + 1] <= FLOOR)
    if first > 0:
        assert res.berUpper[first - 1] > FLOOR
    if last < res.horzCounts.size - 1:
        assert res.berUpper[last + 1] > FLOOR


def test_gaussian_eye_ut_comparison_has_errors_on_both_signs(gaussian):
    cmp = gaussian.result.utComparison

    assert cmp is not None
    assert cmp['errors0'] > 0 and cmp['errors1'] > 0
    assert cmp['errors0'] + cmp['errors1'] >= 100
    assert cmp['bits0'] > 0 and cmp['bits1'] > 0
    assert cmp['horz'] > 0
    assert cmp['ber0'] == pytest.approx(cmp['errors0'] / cmp['bits0'])
    assert cmp['ber1'] == pytest.approx(cmp['errors1'] / cmp['bits1'])
    assert 0 <= cmp['prescale'] <= 31


def test_gaussian_eye_restores_every_register(gaussian):
    gt, model = gaussian.gt, gaussian.model

    assert seedWords(model, gt) == gaussian.before
    assert model.getField(gt.ES_CONTROL) == 0
    assert model.getField(gt.ES_EYE_SCAN_EN) == 1 and model.getField(gt.ES_ERRDET_EN) == 1


def test_meta_holds_the_run_parameters(gaussian):
    meta = gaussian.result.meta

    expected = {'family', 'hwVerified', 'bitsPerSample', 'rxOutDiv', 'horzHalfRange', 'uiPerCount',
                'equalizer', 'resetPolicy', 'floor', 'confidence', 'targetBer', 'step', 'fixedPrescale',
                'ladder', 'linkDrops', 'readyAvailable', 'rxResetHook', 'elapsed'}
    assert expected <= set(meta)
    assert meta['family'] == 'GTHE3'
    assert meta['bitsPerSample'] == 32 and meta['rxOutDiv'] == 2 and meta['horzHalfRange'] == HALF
    assert meta['equalizer'] == 'dfe' and meta['resetPolicy'] == 'Auto'
    assert meta['floor'] == FLOOR and meta['step'] == 1 and meta['fixedPrescale'] is None
    assert meta['readyAvailable'] is True and meta['linkDrops'] == 0
    assert meta['elapsed'] > 0
    assert gaussian.result.activation is not None and gaussian.result.activation.status is ScanStatus.OK


@pytest.mark.parametrize('raw, points', [(1, 129), (0, 65)])
def test_default_sweep_covers_every_count_of_the_half_range_once(rigs, raw, points):
    root, gt, model, hook = rigs(closed)
    model.setField(gt.RXOUT_DIV, raw)

    res = gt.EyeScan.runBathtub()

    half = (points - 1) // 2
    assert np.array_equal(res.horzCounts, np.arange(-half, half + 1))
    assert int(np.sum(res.horzCounts == 0)) == 1
    assert res.horzCounts[0] == -half and res.horzCounts[-1] == half
    assert res.errors.shape == (2, points)


@pytest.mark.parametrize('step', [3, 4, 64])
def test_any_valid_step_gives_a_symmetric_sweep_through_zero(rigs, step):
    root, gt, model, hook = rigs(closed)

    res = gt.EyeScan.runBathtub(step=step)

    ks = np.arange(0, HALF // step + 1)
    expected = np.unique(np.concatenate([ks * step, -ks * step]))
    assert np.array_equal(res.horzCounts, expected)
    assert 0 in res.horzCounts and np.abs(res.horzCounts).max() <= HALF
    assert np.array_equal(res.horzCounts, -res.horzCounts[::-1])
    assert res.meta['step'] == step


def test_invalid_step_is_refused_without_a_write(rigs):
    root, gt, model, hook = rigs(closed)
    writes = len(model.writes)

    for step in (0, -1, 65, 2.5, True):
        with pytest.raises(ValueError):
            gt.EyeScan.runBathtub(step=step)

    assert len(model.writes) == writes


def test_invalid_arguments_are_refused_before_any_bus_access(rigs):
    root, gt, model, hook = rigs(closed)
    before = model.transactions
    cases = [
        {'floor': 0.0}, {'floor': 1.0}, {'confidence': 1.0}, {'targetBer': 0.0}, {'targetBer': 1.5},
        {'equalizer': 'ctle'}, {'fixedPrescale': 32}, {'maxTimePerRun': 0.0},
    ]

    for kwargs in cases:
        with pytest.raises(ValueError):
            gt.EyeScan.runBathtub(**kwargs)

    assert model.transactions == before


def test_a_floor_whose_bit_count_is_not_finite_is_refused_before_any_write(rigs):
    root, gt, model, hook = rigs(closed)
    before = model.transactions

    with pytest.raises(ValueError, match='floor'):
        gt.EyeScan.runBathtub(floor=1e-320)
    with pytest.raises(ValueError, match='floor'):
        gt.EyeScan.runEye(floor=1e-320)
    with pytest.raises(ValueError, match='floor'):
        gt.EyeScan.runMargin(floor=1e-320)
    with pytest.raises(ValueError, match='bathtubFloor'):
        gt.EyeScan.runMargin(bathtubFloor=1e-320)

    assert model.transactions == before


def test_an_analysis_failure_returns_error_with_the_measured_counts(rigs, monkeypatch, tmp_path):
    root, gt, model, hook = rigs(gauss)

    def failing(*args, **kwargs):
        raise RuntimeError('injected analysis failure')

    monkeypatch.setattr('surf.xilinx.eyescan._EyeScanEngine.openRegion', failing)

    res = gt.EyeScan.runBathtub(step=16, floor=1e-6)

    assert res.status is ScanStatus.ERROR
    assert 'RuntimeError' in res.message and 'injected analysis failure' in res.message
    assert res.horzCounts.tolist() == list(range(-64, 65, 16))
    assert res.errors.shape == res.bits.shape == (2, 9) and res.bits.sum() > 0 and res.errors.sum() > 0
    assert (res.prescale >= 0).all() and res.prescale.shape == (9,)
    assert np.isnan(res.ber).all() and np.isnan(res.berUpper).all() and not res.isBound.any()
    assert not res.leftFit.ok and not res.rightFit.ok
    assert res.openingAtFloorUI is None and res.openingAtTargetUI is None
    assert res.insufficientData and not res.extrapolated
    assert res.meta['floor'] == 1e-6 and res.meta['linkDrops'] == 0
    outcome = gt.EyeScan.save(res, str(tmp_path), png=False)
    assert outcome.errors == []
    assert sorted(path.suffix for path in tmp_path.iterdir()) == ['.csv', '.npz']
    arrays, meta = loadResult(outcome.npzPath)
    assert arrays['horz_bits'].sum() == res.bits.sum() and arrays['horz_errors'].sum() == res.errors.sum()


def test_lpm_eye_has_no_second_ut_accumulation(rigs):
    root, gt, model, hook = rigs(gauss)

    res = gt.EyeScan.runBathtub(step=8, equalizer='lpm')

    assert res.status is ScanStatus.OK, res.message
    assert np.all(res.errors[1] == 0) and np.all(res.bits[1] == 0)
    assert res.errors[0].sum() > 0 and res.bits[0].sum() > 0
    assert res.utComparison is None
    assert res.meta['equalizer'] == 'lpm'


def test_closed_eye_is_a_typed_result_with_full_arrays(rigs):
    root, gt, model, hook = rigs(closed)

    res = gt.EyeScan.runBathtub()

    assert res.status is ScanStatus.CLOSED
    assert res.horzCounts.size == 129 and res.errors.shape == (2, 129)
    assert res.insufficientData is True and res.extrapolated is False
    assert res.openingAtTargetUI is None
    assert res.openingAtFloorUI is None
    assert not res.leftFit.ok and not res.rightFit.ok
    assert gt.EyeScan.Status.get() == 'CLOSED'


def test_eye_with_one_open_point_is_ok(rigs):
    def narrow(horz, ut):
        return 0.0 if horz == 0 else 1e-3

    root, gt, model, hook = rigs(narrow)

    res = gt.EyeScan.runBathtub(step=8)

    assert res.status is ScanStatus.OK
    assert res.openingAtFloorUI == 0.0
    assert res.insufficientData is True


def test_abort_before_the_first_point_returns_empty_arrays_and_restores(rigs):
    root, gt, model, hook = rigs(gauss, falseCalls=())
    before = seedWords(model, gt)
    control = ScanControl()
    control.abort()

    res = gt.EyeScan.runBathtub(control=control)

    assert res.status is ScanStatus.ABORTED
    assert res.horzCounts.size == 0
    assert res.errors.shape == (2, 0) and res.bits.shape == (2, 0)
    assert res.ber.size == 0 and res.prescale.size == 0
    assert res.extrapolated is False and res.insufficientData is True
    assert model.getField(gt.ES_CONTROL) == 0
    assert seedWords(model, gt) == before


def maskWrites(model, gt, value):
    addr = gt.ES_SDATA_MASK[0].offset >> 2
    return sum(1 for kind, a, v in model.log if kind == 'W' and a == addr and v == value)


@pytest.mark.parametrize('falseCall', [11, 12])
def test_first_link_drop_discards_and_remeasures_the_point(rigs, falseCall):
    root, gt, model, hook = rigs(gauss, falseCalls={falseCall})
    before = seedWords(model, gt)
    mask0 = maskWords(sdataMask(32, GTHE3.busWidth))[0]

    res = gt.EyeScan.runBathtub(step=8)

    assert res.status is ScanStatus.OK, res.message
    assert res.linkDrops == 1 and res.meta['linkDrops'] == 1
    assert res.horzCounts.size == 17 and res.errors.shape == (2, 17)
    assert np.array_equal(res.horzCounts, np.arange(-HALF, HALF + 1, 8))
    assert maskWrites(model, gt, mask0) >= 2, 'masks rewritten after the drop'
    assert seedWords(model, gt) == before


def test_second_link_drop_ends_unlocked_keeping_the_completed_points(rigs):
    root, gt, model, hook = rigs(gauss, falseCalls={11, 21})
    before = seedWords(model, gt)

    res = gt.EyeScan.runBathtub(step=8)

    assert res.status is ScanStatus.UNLOCKED
    assert res.linkDrops == 2
    assert 0 < res.horzCounts.size < 17
    assert res.errors.shape == (2, res.horzCounts.size)
    assert np.all(np.diff(res.horzCounts) > 0)
    assert model.getField(gt.ES_CONTROL) == 0
    assert seedWords(model, gt) == before
    assert gt.EyeScan.Status.get() == 'UNLOCKED'


def test_ready_that_never_returns_after_a_drop_ends_unlocked_in_bounded_time(rigs):
    root, gt, model, hook = rigs(gauss, falseCalls=range(11, 100000))
    start = time.monotonic()

    res = gt.EyeScan.runBathtub(step=8)

    assert res.status is ScanStatus.UNLOCKED
    assert time.monotonic() - start < 5.0
    assert res.linkDrops == 1


def test_without_a_hook_auto_and_always_refuse_a_warm_lane_without_scanning(rigs):
    root, gt, model, hook = rigs(gauss, withHook=False)
    before = seedWords(model, gt)

    for policy in ('Auto', 'Always'):
        res = gt.EyeScan.runBathtub(step=16, resetPolicy=policy)

        assert res.status is ScanStatus.NOT_ENABLED
        assert 'setRxReset' in res.message
        assert res.horzCounts.size == 0
        assert gt.EyeScan.Status.get() == 'NOT_ENABLED'
    assert model.getField(gt.ES_CONTROL) == 0
    assert seedWords(model, gt) == before


def test_without_a_hook_policy_never_scans_and_ready_is_unavailable(rigs):
    root, gt, model, hook = rigs(gauss, withHook=False)

    res = gt.EyeScan.runBathtub(step=16, resetPolicy='Never')

    assert res.status is ScanStatus.OK, res.message
    assert res.meta['readyAvailable'] is False
    assert res.meta['rxResetHook'] == 'none'
    assert res.linkDrops == 0


def test_engine_bathtub_matches_the_child_call(rigs):
    root, gt, model, hook = rigs(closed)
    engine = EyeScanEngine(EyeScanPort(gt, GTHE3), gt.EyeScan._hook)

    res = engine.bathtub(step=32)

    assert res.status is ScanStatus.CLOSED
    assert np.array_equal(res.horzCounts, np.arange(-HALF, HALF + 1, 32))


def waitFor(predicate, timeout):
    end = time.monotonic() + timeout
    while time.monotonic() < end:
        if predicate():
            return True
        time.sleep(0.02)
    return False


def test_process_start_runs_a_bathtub_in_bathtub_mode(tmp_path):
    root, gt, model = makeGtRoot(requireReset=True, berFn=gauss, countReads=1)
    try:
        hook = Hook(model)
        gt.EyeScan.setRxReset(hook.pulse, hook.ready, settle=0.0, fallWait=0.05, timeout=0.5)
        gt.EyeScan.Mode.setDisp('Bathtub')
        gt.EyeScan.HorzStep.set(1)
        gt.EyeScan.OutputDir.set(str(tmp_path))
        gt.EyeScan.Start()

        assert waitFor(lambda: gt.EyeScan.Running.value() is False and gt.EyeScan.lastResult is not None, 120)
        assert gt.EyeScan.Status.get() == 'OK'
        assert gt.EyeScan.lastResult.status is ScanStatus.OK
        assert gt.EyeScan.lastResult.horzCounts.size == 129
        assert gt.EyeScan.Message.get().startswith('OK')
        assert gt.EyeScan.Progress.value() == pytest.approx(1.0)
        assert gt.EyeScan.ResultFile.get().startswith(str(tmp_path))
    finally:
        root.stop()


def test_process_stop_ends_within_one_second_and_restores(tmp_path):
    root, gt, model = makeGtRoot(requireReset=True, berFn=gauss, countReads=1)
    try:
        before = seedWords(model, gt)
        hook = Hook(model)
        gt.EyeScan.setRxReset(hook.pulse, hook.ready, settle=0.0, fallWait=0.05, timeout=0.5)
        gt.EyeScan.Mode.setDisp('Bathtub')
        gt.EyeScan.HorzStep.set(1)
        gt.EyeScan.OutputDir.set(str(tmp_path))
        gt.EyeScan.Start()
        assert waitFor(lambda: gt.EyeScan.Progress.value() > 0.05, 60)

        start = time.monotonic()
        gt.EyeScan.Stop()
        stopped = time.monotonic() - start

        assert stopped < 1.0
        assert waitFor(lambda: gt.EyeScan.Running.value() is False, 2.0)
        assert gt.EyeScan.Status.get() == 'ABORTED'
        assert gt.EyeScan.Message.get().startswith('Scan stopped')
        assert gt.EyeScan.lastResult.status is ScanStatus.ABORTED
        assert model.getField(gt.ES_CONTROL) == 0
        assert seedWords(model, gt) == before
    finally:
        root.stop()


def test_process_reports_a_scan_error_with_the_status_name(tmp_path):
    root, gt, model = makeGtRoot(requireReset=True, berFn=gauss, countReads=1)
    try:
        # Cold lane, no hook registered: the sampler never activates
        gt.EyeScan.Mode.setDisp('Bathtub')
        gt.EyeScan.OutputDir.set(str(tmp_path))
        gt.EyeScan.Start()

        assert waitFor(lambda: gt.EyeScan.Running.value() is False and gt.EyeScan.Status.get() != 'Idle', 30)
        assert gt.EyeScan.Status.get() == 'NOT_ENABLED'
        assert gt.EyeScan.Message.get().startswith('Error: NOT_ENABLED')
    finally:
        root.stop()


def test_a_second_scan_is_refused_while_a_process_run_holds_the_lock(tmp_path):
    root, gt, model = makeGtRoot(requireReset=True, berFn=gauss, countReads=1)
    try:
        hook = Hook(model)
        gt.EyeScan.setRxReset(hook.pulse, hook.ready, settle=0.0, fallWait=0.05, timeout=0.5)
        gt.EyeScan.Mode.setDisp('Bathtub')
        gt.EyeScan.HorzStep.set(1)
        gt.EyeScan.OutputDir.set(str(tmp_path))
        gt.EyeScan.Start()
        assert waitFor(lambda: gt.EyeScan.Progress.value() > 0.02, 60)
        errors = []

        def other():
            try:
                gt.EyeScan.runBathtub(step=64)
            except Exception as exc:
                errors.append(exc)

        thread = threading.Thread(target=other)
        thread.start()
        thread.join(5)
        gt.EyeScan.Stop()

        assert len(errors) == 1 and 'in progress' in str(errors[0])
    finally:
        root.stop()
