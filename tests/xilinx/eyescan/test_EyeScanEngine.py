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
# - Sweep: sampler activation of the GTHE3 eye scan (reset policy, reset hook
#   handshake, soft re-cold, probe boundaries, shared-word priming, scan
#   lock) and one BER point (exact bit counts, adaptive prescale ladder, DFE
#   and LPM accumulation, zero-error bounds, restore, abort in every state)
#   over an emulated GTHE3 DRP memory with an eye-scan state machine.
# - Stimulus: real Rogue transactions against Gthe3EyeModel, optionally behind
#   a Pgp4AxiL window (LaneMemory) so the variable-form hook toggles the real
#   Ctrl.ResetRx bit. Callable hooks count their pulses and drive the model's
#   pmaReset(). The model log is ordered, so read-before-write is checkable.
# - Checks: a cold lane activates only through the hook; Auto and Always
#   reset the RX on every activation, including a lane whose enables are
#   already set, and refuse without a hook before any enable write; Never
#   never resets; a dead
#   sampler (status 0x0, 0x1, 0x2 or END with no samples) is NOT_ENABLED in
#   bounded time with an actionable message; the shared words 0x3C, 0x4F,
#   0x93 and 0x97, the mask words and the Pgp4AxiL Ctrl word keep their
#   neighbouring bits; an exception during the reset hold still deasserts the
#   reset.
#   A scanned point sums both UT signs in DFE mode and uses UT_SIGN 0 only in
#   LPM mode, reports a zero-error point as an upper bound and never as BER 0,
#   decodes the data width at the start of every scan, writes the horizontal
#   offset as x & 0xFFF, and restores every register it touched after success,
#   error or abort while the enables stay set.
# - Timing: Short settle, fall, timeout and probe-window values; the model
#   steps on status reads, so no test waits on real hardware time.

import math
import threading
import time
from collections import Counter
from types import SimpleNamespace

import pytest

pr = pytest.importorskip('pyrogue', reason='Eye-scan tests require Rogue/PyRogue')

import numpy as np  # noqa: E402
rogue = pytest.importorskip('rogue', reason='Eye-scan tests require Rogue/PyRogue')

import surf.xilinx.eyescan._EyeScan as escan  # noqa: E402
from surf.xilinx.eyescan import (  # noqa: E402
    GTHE3,
    EyeScanAborted,
    EyeScanEngine,
    EyeScanError,
    EyeScanNotActive,
    EyeScanPort,
    EyeScanTimeout,
    ResetPolicy,
    RxResetHook,
    ScanControl,
    ScanStatus,
)

from surf.xilinx.eyescan._EyeScanPort import IDLE_TIMEOUT  # noqa: E402
from tests.xilinx.eyescan.gthe3_eye_model import makeGtRoot, makeLaneRoot  # noqa: E402
from tests.xilinx.eyescan.test_EyeScanBathtub import heldElsewhere  # noqa: E402

WINDOW = 0.3


@pytest.fixture
def rigs():
    roots = []

    def make(kind='gt', **kw):
        rig = makeLaneRoot(**kw) if kind == 'lane' else makeGtRoot(**kw)
        roots.append(rig[0])
        return rig
    yield make
    for root in roots:
        root.stop()


class FakeReset:
    """Callable reset and ready pair that pulses the model's PMA reset."""

    def __init__(self, model=None, lowReads=2, neverFalls=False, neverRises=False):
        self.model = model
        self.lowReads = lowReads
        self.neverFalls = neverFalls
        self.neverRises = neverRises
        self.pulses = 0
        self._low = 0
        self._pulsed = False

    def pulse(self):
        self.pulses += 1
        self._pulsed = True
        self._low = self.lowReads
        if self.model is not None:
            self.model.pmaReset()

    def ready(self):
        if not self._pulsed or self.neverFalls:
            return True
        if self.neverRises:
            return False
        if self._low > 0:
            self._low -= 1
            return False
        return True


def register(gt, fake, **kw):
    kw.setdefault('settle', 0.0)
    kw.setdefault('fallWait', 0.05)
    kw.setdefault('timeout', 0.5)
    gt.EyeScan.setRxReset(fake.pulse, fake.ready, **kw)


def warm(gt, model):
    """Both enables set and the sampler alive, as after an earlier scan."""
    model.setField(gt.ES_ERRDET_EN, 1)
    model.setField(gt.ES_EYE_SCAN_EN, 1)
    model.activate()


def test_cold_auto_probe_activates_through_hook(rigs):
    root, gt, model = rigs()
    fake = FakeReset(model)
    register(gt, fake)

    result = gt.EyeScan.probe(probeWindow=WINDOW)

    assert result.status is ScanStatus.OK
    assert fake.pulses == 1
    assert result.policy is ResetPolicy.Auto
    assert result.hookRegistered and result.enablesChanged and result.resetCalled
    assert (result.eyeScanEnReadback, result.errDetEnReadback) == (1, 1)
    assert result.statusAfter == 0x5
    assert result.sampleCount > 0
    assert result.sawFall and result.tFall is not None and result.tReady is not None
    assert result.tReady >= result.tFall
    assert gt.EyeScan.Status.get() == 'OK'
    assert model.getField(gt.ES_CONTROL) == 0
    assert model.getField(gt.ES_EYE_SCAN_EN) == 1 and model.getField(gt.ES_ERRDET_EN) == 1


def test_reset_policy_decides_when_the_hook_is_called(rigs):
    root, gt, model = rigs()
    warm(gt, model)
    fake = FakeReset(model)
    register(gt, fake)

    result = gt.EyeScan.probe(probeWindow=WINDOW)
    assert result.status is ScanStatus.OK and not result.enablesChanged and result.resetCalled
    assert fake.pulses == 1

    result = gt.EyeScan.probe(resetPolicy=ResetPolicy.Always, probeWindow=WINDOW)
    assert result.status is ScanStatus.OK and result.resetCalled and not result.enablesChanged
    assert fake.pulses == 2

    result = gt.EyeScan.probe(resetPolicy='Never', probeWindow=WINDOW)
    assert result.status is ScanStatus.OK and not result.resetCalled
    assert fake.pulses == 2


def test_auto_resets_on_every_activation_of_a_warm_lane(rigs):
    root, gt, model = rigs()
    warm(gt, model)
    fake = FakeReset(model)
    register(gt, fake)

    for expected in (1, 2, 3):
        result = gt.EyeScan.probe(resetPolicy=ResetPolicy.Auto, probeWindow=WINDOW)

        assert result.status is ScanStatus.OK and result.resetCalled
        assert not result.enablesChanged
        assert result.sawFall and result.tReady is not None
        assert fake.pulses == expected


@pytest.mark.parametrize('policy', [ResetPolicy.Auto, ResetPolicy.Always])
def test_no_hook_on_a_warm_lane_is_refused_before_any_scan(rigs, policy):
    root, gt, model = rigs()
    warm(gt, model)
    start = time.monotonic()

    result = gt.EyeScan.probe(resetPolicy=policy, probeWindow=WINDOW)

    assert time.monotonic() - start < WINDOW
    assert result.status is ScanStatus.NOT_ENABLED
    assert not result.hookRegistered and not result.resetCalled
    assert 'setRxReset' in result.message
    assert result.statusAfter == 0 and result.sampleCount == 0
    assert gt.EyeScan.Status.get() == 'NOT_ENABLED'
    assert model.getField(gt.ES_CONTROL) == 0
    assert model.getField(gt.ES_EYE_SCAN_EN) == 1 and model.getField(gt.ES_ERRDET_EN) == 1


def test_no_hook_never_still_scans_a_warm_lane(rigs):
    root, gt, model = rigs()
    warm(gt, model)

    result = gt.EyeScan.probe(resetPolicy=ResetPolicy.Never, probeWindow=WINDOW)

    assert result.status is ScanStatus.OK and not result.hookRegistered and not result.resetCalled


def test_no_hook_cold_lane_is_refused_without_enabling_the_sampler(rigs):
    root, gt, model = rigs()

    result = gt.EyeScan.probe(probeWindow=WINDOW)

    assert result.status is ScanStatus.NOT_ENABLED and 'setRxReset' in result.message
    assert model.getField(gt.ES_EYE_SCAN_EN) == 0 and model.getField(gt.ES_ERRDET_EN) == 0


def test_never_on_a_cold_lane_does_not_call_the_hook(rigs):
    root, gt, model = rigs()
    fake = FakeReset(model)
    register(gt, fake)

    result = gt.EyeScan.probe(resetPolicy=ResetPolicy.Never, probeWindow=WINDOW)

    assert result.status is ScanStatus.NOT_ENABLED
    assert fake.pulses == 0 and not result.resetCalled
    assert result.enablesChanged


def test_reset_policy_variable_is_used_when_no_override_is_given(rigs):
    root, gt, model = rigs()
    child = gt.EyeScan
    assert child.ResetPolicy.enum == {0: 'Auto', 1: 'Always', 2: 'Never'}
    assert child.ResetPolicy.valueDisp() == 'Auto'
    assert child.ResetPolicy.inGroup('NoConfig')
    fake = FakeReset(model)
    register(gt, fake)

    child.ResetPolicy.setDisp('Never')
    result = child.probe(probeWindow=WINDOW)

    assert result.policy is ResetPolicy.Never
    assert result.status is ScanStatus.NOT_ENABLED and fake.pulses == 0


def test_no_hook_cold_auto_is_bounded_and_names_set_rx_reset(rigs):
    root, gt, model = rigs()
    start = time.monotonic()

    result = gt.EyeScan.probe(probeWindow=WINDOW)

    assert time.monotonic() - start < WINDOW + 1.0
    assert result.status is ScanStatus.NOT_ENABLED
    assert not result.hookRegistered and not result.resetCalled
    assert 'setRxReset' in result.message
    assert gt.EyeScan.Status.get() == 'NOT_ENABLED'
    assert model.getField(gt.ES_CONTROL) == 0


def test_no_hook_always_fails_before_any_run(rigs):
    root, gt, model = rigs()

    result = gt.EyeScan.probe(resetPolicy=ResetPolicy.Always, probeWindow=WINDOW)

    assert result.status is ScanStatus.NOT_ENABLED
    assert 'setRxReset' in result.message
    assert model.runs == 0


@pytest.mark.parametrize('stuck', [0x0, 0x1, 0x2])
def test_a_sampler_that_never_reaches_end_is_not_enabled(rigs, stuck):
    root, gt, model = rigs(requireReset=False, stuckStatus=stuck)
    register(gt, FakeReset(model))
    start = time.monotonic()

    result = gt.EyeScan.probe(probeWindow=WINDOW)

    assert time.monotonic() - start < WINDOW + 1.0
    assert result.status is ScanStatus.NOT_ENABLED
    assert f'0x{stuck:X}' in result.message
    assert model.getField(gt.ES_CONTROL) == 0


def test_end_with_no_samples_is_not_enabled(rigs):
    root, gt, model = rigs(requireReset=False, zeroSamples=True)
    register(gt, FakeReset(model))

    result = gt.EyeScan.probe(probeWindow=WINDOW)

    assert result.status is ScanStatus.NOT_ENABLED
    assert result.statusAfter == 0x5 and result.sampleCount == 0


def test_end_with_one_sample_is_active(rigs):
    root, gt, model = rigs(requireReset=False)
    model.countReads = 1
    register(gt, FakeReset(model))

    result = gt.EyeScan.probe(probeWindow=WINDOW)

    assert result.status is ScanStatus.OK and result.sampleCount >= 1


def test_ready_that_never_falls_is_not_an_error(rigs):
    root, gt, model = rigs()
    fake = FakeReset(model, neverFalls=True)
    register(gt, fake, fallWait=0.05)

    result = gt.EyeScan.probe(probeWindow=WINDOW)

    assert result.status is ScanStatus.OK
    assert not result.sawFall and result.tFall is None
    assert result.tReady is not None


def test_ready_that_never_rises_ends_not_enabled_within_timeout(rigs):
    root, gt, model = rigs()
    fake = FakeReset(model, neverRises=True)
    register(gt, fake, timeout=0.3)
    start = time.monotonic()

    result = gt.EyeScan.probe(probeWindow=WINDOW)

    assert time.monotonic() - start < 0.3 + 1.0
    assert result.status is ScanStatus.NOT_ENABLED
    assert result.resetCalled and result.sawFall and result.tReady is None
    assert 'ready' in result.message
    assert model.runs == 0


def test_variable_hook_keeps_the_ctrl_word_and_deasserts_reset(rigs):
    root, gt, lane, model, mem = rigs('lane')
    word = 0
    for var, value in ((lane.Ctrl.TxDiffCtrl, 0x1f), (lane.Ctrl.TxPreCursor, 7),
                       (lane.Ctrl.TxPostCursor, 7), (lane.Ctrl.Loopback, 3)):
        word |= value << var.bitOffset[0]
    mem.words[mem.ctrlAddr] = word

    result = gt.EyeScan.probe(probeWindow=WINDOW)

    assert result.status is ScanStatus.OK and result.resetCalled and result.sawFall
    assert mem.words[mem.ctrlAddr] == word
    assert lane.Ctrl.ResetRx.get() is False
    assert lane.Ctrl.TxDiffCtrl.get() == 0x1f
    assert lane.Ctrl.TxPreCursor.get() == 7 and lane.Ctrl.TxPostCursor.get() == 7
    assert any(value & (1 << mem.resetLsb) for _, value in mem.writes), 'reset was never asserted'


def test_exception_during_the_hold_still_deasserts_reset(rigs, monkeypatch):
    root, gt, lane, model, mem = rigs('lane')
    word = (0x1f << lane.Ctrl.TxDiffCtrl.bitOffset[0]) | (7 << lane.Ctrl.TxPreCursor.bitOffset[0]) \
        | (7 << lane.Ctrl.TxPostCursor.bitOffset[0])
    mem.words[mem.ctrlAddr] = word

    def boom(seconds):
        raise RuntimeError('injected hold failure')

    monkeypatch.setattr(escan, 'time', SimpleNamespace(sleep=boom))
    result = gt.EyeScan.probe(probeWindow=WINDOW)
    monkeypatch.undo()

    assert result.status is ScanStatus.ERROR
    assert 'injected hold failure' in result.message
    assert lane.Ctrl.ResetRx.get() is False
    assert mem.words[mem.ctrlAddr] == word
    assert model.getField(gt.ES_CONTROL) == 0


def test_second_registration_wins(rigs):
    root, gt, model = rigs()
    first, second = FakeReset(model), FakeReset(model)
    register(gt, first)
    register(gt, second)

    result = gt.EyeScan.probe(probeWindow=WINDOW)

    assert result.status is ScanStatus.OK
    assert (first.pulses, second.pulses) == (0, 1)


def test_clear_rx_reset_removes_the_hook(rigs):
    root, gt, model = rigs()
    fake = FakeReset(model)
    register(gt, fake)
    gt.EyeScan.clearRxReset()
    assert gt.EyeScan.RxResetHook.get() == 'none'

    result = gt.EyeScan.probe(probeWindow=WINDOW)

    assert result.status is ScanStatus.NOT_ENABLED and 'setRxReset' in result.message
    assert fake.pulses == 0


def test_ready_variable_is_evaluated_as_a_bool(rigs):
    root, gt, lane, model, mem = rigs('lane')
    count = lane.RxStatus.FrameCnt
    gt.EyeScan.setRxReset(lambda: None, count)
    ready = gt.EyeScan._hook.ready

    mem.words[count.address] = 5
    assert ready() is True
    mem.words[count.address] = 0
    assert ready() is False


def test_registration_errors_touch_no_hardware(rigs):
    root, gt, lane, model, mem = rigs('lane')
    before = (mem.reads, len(mem.writes), model.transactions)

    with pytest.raises(TypeError):
        gt.EyeScan.setRxReset(7, lane.RxStatus.PhyRxActive)
    with pytest.raises(ValueError):
        gt.EyeScan.setRxReset(lane.RxStatus.PhyRxActive, lane.RxStatus.PhyRxActive)

    assert (mem.reads, len(mem.writes), model.transactions) == before


def test_soft_cold_stops_the_sampler_and_the_next_probe_resets_again(rigs):
    root, gt, model = rigs()
    fake = FakeReset(model)
    register(gt, fake)
    assert gt.EyeScan.probe(probeWindow=WINDOW).status is ScanStatus.OK

    cold = gt.EyeScan.softCold(probeWindow=WINDOW)

    assert cold.stopped
    assert (cold.eyeScanEn, cold.errDetEn) == (0, 0)
    assert cold.sampleCount == 0 and cold.statusAfter in (0x0, 0x1)
    assert cold.sawFall and cold.tReady is not None
    assert fake.pulses == 2
    assert model.getField(gt.ES_EYE_SCAN_EN) == 0 and model.getField(gt.ES_ERRDET_EN) == 0
    assert model.getField(gt.ES_CONTROL) == 0

    again = gt.EyeScan.probe(probeWindow=WINDOW)
    assert again.status is ScanStatus.OK and again.enablesChanged
    assert fake.pulses == 3


def test_soft_cold_without_a_hook_raises_before_any_write(rigs):
    root, gt, model = rigs()

    with pytest.raises(EyeScanError, match='setRxReset'):
        gt.EyeScan.softCold(probeWindow=WINDOW)

    assert model.writes == []


def test_priming_reads_each_shared_word_before_its_first_write(rigs):
    root, gt, model = rigs()
    pos = model._pos
    before = model.seedSnapshot(gt)
    fake = FakeReset(model)
    register(gt, fake)

    result = gt.EyeScan.probe(probeWindow=WINDOW)

    assert result.status is ScanStatus.OK
    for word in (pos.ctl[0], pos.horz[0], pos.ut[0]):
        kinds = [kind for kind, addr, _ in model.log if addr == word]
        assert 'W' in kinds and kinds.index('R') < kinds.index('W'), hex(word)
    after = model.seedSnapshot(gt)
    ctl = pos.ctl[0]
    assert after.pop(ctl) == before.pop(ctl) | 0x0300
    assert after == before


def test_a_second_scan_while_one_holds_the_lock_is_refused(rigs):
    root, gt, model = rigs()
    with heldElsewhere(gt.EyeScan._scanLock):
        with pytest.raises(EyeScanError):
            gt.EyeScan.probe(probeWindow=WINDOW)
        with pytest.raises(EyeScanError):
            gt.EyeScan.softCold(probeWindow=WINDOW)

    assert model.writes == []


# ----------------------------------------------------------------------
# One BER point
# ----------------------------------------------------------------------

def noopHook():
    """Reset hook whose pulse changes nothing, for models that activate on the enables alone."""
    return RxResetHook(pulse=lambda: None, ready=lambda: True, settle=0.0, timeout=0.5,
                       fallWait=0.01, hold=0.0, description='test hook')


def engineOf(gt, control=None, hook=None):
    return EyeScanEngine(EyeScanPort(gt, GTHE3), hook if hook is not None else noopHook(), control)


def ber(horz, ut):
    return 1e-3 if ut == 0 else 2e-3


def zero(horz, ut):
    return 0.0


def seedWords(model, gt):
    """Raw words of the scan registers with the control word's enable bits masked."""
    words = model.seedSnapshot(gt)
    words[model._pos.ctl[0]] &= ~0x0300
    return words


def test_scan_control_sleep_stops_within_the_abort_slice():
    control = ScanControl()
    threading.Timer(0.05, control.abort).start()
    start = time.monotonic()

    with pytest.raises(EyeScanAborted):
        control.sleep(5.0)

    assert time.monotonic() - start < 0.5
    assert control.aborted


def test_scan_control_follows_an_external_abort_source_and_reports_progress():
    flag = []
    seen = []
    control = ScanControl(isAborted=lambda: bool(flag), onProgress=lambda done, total: seen.append((done, total)))
    control.check()
    control.progress(3, 9)
    flag.append(True)

    assert seen == [(3, 9)]
    with pytest.raises(EyeScanAborted):
        control.check()


@pytest.mark.parametrize('prescale', [0, 10])
def test_run_once_bits_follow_the_sample_count_exactly(rigs, prescale):
    root, gt, model = rigs(requireReset=False, berFn=zero)
    warm(gt, model)
    engine = engineOf(gt)
    engine.port.prime()

    errors, bits = engine.runOnce(prescale, time.monotonic() + 5.0, 32)

    samples = model.getField(gt.es_sample_count)
    assert samples == 65535
    assert bits == samples * 2 ** (1 + prescale) * 32
    assert isinstance(bits, int)
    assert errors == model.getField(gt.es_error_count)


def test_run_once_with_a_saturated_error_counter_uses_the_scaled_samples(rigs):
    root, gt, model = rigs(requireReset=False, berFn=ber)
    warm(gt, model)
    engine = engineOf(gt)
    engine.port.prime()

    errors, bits = engine.runOnce(10, time.monotonic() + 5.0, 32)

    samples = model.getField(gt.es_sample_count)
    assert errors == 65535 and 0 < samples < 65535
    assert bits == samples * 2 ** 11 * 32


def test_run_once_deadline_in_count_returns_the_partial_counts(rigs):
    root, gt, model = rigs(requireReset=False, countReads=100000)
    warm(gt, model)
    engine = engineOf(gt)
    engine.port.prime()

    errors, bits = engine.runOnce(2, time.monotonic() + 0.1, 32)

    samples = model.getField(gt.es_sample_count)
    assert 0 < samples < 65535
    assert bits == samples * 2 ** 3 * 32


def test_dfe_sums_both_ut_signs_and_stops_after_the_first_rung_with_errors(rigs):
    root, gt, model = rigs(requireReset=False, berFn=ber)

    result = engineOf(gt).point(0)

    assert result.status is ScanStatus.OK
    assert result.rungs == (0,)
    assert all(e > 100 for e in result.errors) and all(b > 0 for b in result.bits)
    assert result.errors[1] > result.errors[0]
    assert not result.isBound
    assert result.ber == pytest.approx(sum(result.errors) / sum(result.bits))
    assert result.ber == pytest.approx(1.5e-3, rel=0.05)
    assert model.runs == 3, 'probe plus one run per UT sign'


def test_lpm_uses_ut_sign_zero_only(rigs):
    root, gt, model = rigs(requireReset=False, berFn=ber)

    result = engineOf(gt).point(0, equalizer='lpm')

    assert result.status is ScanStatus.OK
    assert result.errors[0] > 100 and result.errors[1] == 0
    assert result.bits[0] > 0 and result.bits[1] == 0
    assert result.ber == pytest.approx(1e-3, rel=0.05)
    assert model.runs == 2, 'probe plus one run'


def test_zero_error_point_climbs_the_ladder_and_reports_a_bound(rigs):
    root, gt, model = rigs(requireReset=False, berFn=zero)

    result = engineOf(gt).point(0, floor=1e-9, confidence=0.95)

    assert result.status is ScanStatus.OK
    assert result.rungs == (0, 3, 6, 8, 10)
    assert result.prescale == 10
    assert result.errors == (0, 0)
    assert result.isBound and math.isnan(result.ber)
    assert result.berUpper == pytest.approx(math.log(20) / sum(result.bits))
    assert sum(result.bits) >= math.log(20) / 1e-9


def test_fixed_prescale_runs_exactly_one_rung(rigs):
    root, gt, model = rigs(requireReset=False, berFn=zero)

    result = engineOf(gt).point(0, fixedPrescale=4)

    assert result.rungs == (4,) and result.prescale == 4
    assert result.bits[0] == 65535 * 2 ** 5 * 32
    assert result.isBound


def test_point_restores_every_register_after_success(rigs):
    root, gt, model = rigs(requireReset=False, berFn=ber)
    pos = model._pos
    before = seedWords(model, gt)

    result = engineOf(gt).point(7)

    assert result.status is ScanStatus.OK
    assert seedWords(model, gt) == before
    assert model.getField(gt.ES_EYE_SCAN_EN) == 1 and model.getField(gt.ES_ERRDET_EN) == 1
    assert model.getField(gt.ES_CONTROL) == 0
    assert model.getField(gt.ES_PRESCALE) == 0xA
    # After the last RUN the first write is ES_CONTROL=0, and the restore
    # clears ES_CONTROL again before it touches any other register
    lastRun = max(i for i, (kind, addr, value) in enumerate(model.log)
                  if kind == 'W' and addr == pos.ctl[0] and value >> pos.ctl[1] & 1)
    tail = [addr for kind, addr, _ in model.log[lastRun + 1:] if kind == 'W']
    assert tail[0] == pos.ctl[0] and tail[1] == pos.ctl[0]
    assert tail[2] == pos.horz[0]


@pytest.mark.parametrize('nth', [1, 2, 3])
@pytest.mark.parametrize('target', ['WAIT', 'RESET', 'COUNT', 'END'])
def test_abort_in_every_state_restores_and_reports_aborted(rigs, target, nth):
    control = ScanControl()
    seen = Counter()

    def onState(name):
        seen[name] += 1
        if name == target and seen[name] == nth:
            control.abort()

    root, gt, model = rigs(requireReset=False, berFn=ber, onState=onState)
    before = seedWords(model, gt)

    result = engineOf(gt, control).point(0)

    assert result.status is ScanStatus.ABORTED
    assert control.aborted
    assert model.getField(gt.ES_CONTROL) == 0
    assert seedWords(model, gt) == before
    assert model.getField(gt.ES_EYE_SCAN_EN) == 1 and model.getField(gt.ES_ERRDET_EN) == 1


def test_a_run_that_never_ends_times_out_in_bounded_time_with_the_restore_done(rigs):
    holder = []

    def onState(name):
        # The activation probe reaches END, every later run then sticks in COUNT
        if name == 'END' and holder:
            holder[0].stuckStatus = 0x6

    root, gt, model = rigs(requireReset=False, berFn=ber, onState=onState)
    holder.append(model)
    before = seedWords(model, gt)
    start = time.monotonic()

    result = engineOf(gt).point(0, maxTimePerRun=0.2)

    assert time.monotonic() - start < 0.2 + 2.0
    assert result.status is ScanStatus.TIMEOUT
    assert model.getField(gt.ES_CONTROL) == 0
    assert seedWords(model, gt) == before


def scanLike(port):
    """Write the registers a scan changes to values that differ from the seeded ones."""
    port.write('horzOffset', 0x155)
    port.write('vsUtSign', 1)
    port.write('prescale', 3)
    port.writeMasks(port.bitsPerSample())


def stickInCount(model):
    """The sampler stays in COUNT for every status read, RUN or not."""
    model.stuckStatus = 0x6
    model.stuckIgnoresRun = True


def test_restore_writes_every_field_when_the_idle_wait_times_out(rigs):
    root, gt, model = rigs(requireReset=False)
    port = EyeScanPort(gt, GTHE3)
    before = seedWords(model, gt)
    port.prime()
    snap = port.snapshot()
    scanLike(port)
    assert seedWords(model, gt) != before
    stickInCount(model)

    with pytest.raises(EyeScanTimeout):
        port.restore(snap)

    assert seedWords(model, gt) == before
    assert model.getField(gt.ES_CONTROL) == 0


def test_a_sampler_stuck_in_count_after_stop_still_gets_every_register_restored(rigs):
    holder = []

    def onState(name):
        # The activation probe reaches END, then the sampler never leaves COUNT again
        if name == 'END' and holder:
            stickInCount(holder[0])

    root, gt, model = rigs(requireReset=False, berFn=ber, onState=onState)
    holder.append(model)
    before = seedWords(model, gt)
    start = time.monotonic()

    result = engineOf(gt).point(0, maxTimePerRun=0.2)

    assert time.monotonic() - start < 0.2 + 2 * IDLE_TIMEOUT + 2.0
    assert result.status is ScanStatus.ERROR
    assert 'restore failed' in result.message and 'TIMEOUT' in result.message
    assert seedWords(model, gt) == before
    assert model.getField(gt.ES_CONTROL) == 0
    assert model.getField(gt.ES_EYE_SCAN_EN) == 1 and model.getField(gt.ES_ERRDET_EN) == 1


def test_restore_reraises_the_first_error_after_writing_every_field(rigs):
    root, gt, model = rigs(requireReset=False)
    port = EyeScanPort(gt, GTHE3)
    before = seedWords(model, gt)
    port.prime()
    snap = port.snapshot()
    scanLike(port)
    stickInCount(model)
    attempts = []

    def boom(value, verify=True):
        attempts.append(value)
        raise RuntimeError('vs code boom')

    port.var('vsCode').set = boom

    with pytest.raises(EyeScanTimeout):
        port.restore(snap)

    assert attempts == [snap['vsCode']]
    assert seedWords(model, gt) == before


def test_restore_leaves_the_sampler_stopped_even_when_es_control_was_set_before(rigs):
    root, gt, model = rigs(requireReset=False, berFn=ber)
    pos = model._pos
    model.setField(gt.ES_CONTROL, 1)
    controlBits = ((1 << pos.ctl[2]) - 1) << pos.ctl[1]
    before = seedWords(model, gt)
    before[pos.ctl[0]] &= ~controlBits
    port = EyeScanPort(gt, GTHE3)
    port.prime()
    assert 'control' not in port.snapshot()

    result = engineOf(gt).point(0)

    after = seedWords(model, gt)
    after[pos.ctl[0]] &= ~controlBits
    assert result.status is ScanStatus.OK
    assert model.getField(gt.ES_CONTROL) == 0
    assert after == before
    assert model.getField(gt.ES_EYE_SCAN_EN) == 1 and model.getField(gt.ES_ERRDET_EN) == 1


def test_unsupported_width_is_refused_without_any_write(rigs):
    root, gt, model = rigs(requireReset=False, berFn=ber)
    model.setField(gt.RX_INT_DATAWIDTH, 2)

    result = engineOf(gt).point(0)

    assert result.status is ScanStatus.ERROR
    assert 'RX_DATA_WIDTH raw 6' in result.message and 'RX_INT_DATAWIDTH raw 2' in result.message
    assert model.writes == []


def test_width_is_decoded_at_the_start_of_every_scan(rigs):
    root, gt, model = rigs(requireReset=False, berFn=zero)
    model.setField(gt.RX_DATA_WIDTH, 4)
    engine = engineOf(gt)

    first = engine.point(0, fixedPrescale=0)
    model.setField(gt.RX_INT_DATAWIDTH, 0)
    second = engine.point(0, fixedPrescale=0)

    assert first.bits[0] == 65535 * 2 * 32
    assert second.bits[0] == 65535 * 2 * 16
    assert second.bits[0] * 2 == first.bits[0]


def test_restore_failure_after_an_abort_is_an_error_naming_the_abort(rigs):
    control = ScanControl()
    control.abort()
    root, gt, model = rigs(requireReset=False, berFn=ber)
    engine = engineOf(gt, control)

    def boom(snapshot):
        raise RuntimeError('restore boom')

    engine.port.restore = boom
    result = engine.point(0)

    assert result.status is ScanStatus.ERROR
    assert 'ABORTED' in result.message and 'restore boom' in result.message


def test_restore_failure_after_success_is_an_error(rigs):
    root, gt, model = rigs(requireReset=False, berFn=ber)
    engine = engineOf(gt)

    def boom(snapshot):
        raise RuntimeError('restore boom')

    engine.port.restore = boom
    result = engine.point(0)

    assert result.status is ScanStatus.ERROR
    assert 'OK' in result.message and 'restore boom' in result.message


def test_negative_and_positive_offsets_use_the_unified_phase_encoding(rigs):
    seen = []

    def recording(horz, ut):
        seen.append(horz)
        return 1e-3

    root, gt, model = rigs(requireReset=False, berFn=recording)
    pos = model._pos
    engine = engineOf(gt)

    left = engine.point(-5, fixedPrescale=0)
    right = engine.point(5, fixedPrescale=0)

    assert left.status is ScanStatus.OK and right.status is ScanStatus.OK
    assert model.phaseViolations == 0
    assert {-5, 5} <= set(seen)
    written = {value >> pos.horz[1] for kind, addr, value in model.log if kind == 'W' and addr == pos.horz[0]}
    assert {(-5) & 0xFFF, 5} <= written


@pytest.mark.parametrize('kwargs', [
    {'floor': 0.0}, {'floor': 1.0}, {'confidence': 0.0}, {'confidence': 1.0},
    {'fixedPrescale': 32}, {'fixedPrescale': -1}, {'maxTimePerRun': 0.0}, {'equalizer': 'bogus'},
    {'fixedPrescale': 3.5}, {'fixedPrescale': True}, {'fixedPrescale': np.float64(4.0)},
])
def test_invalid_arguments_are_refused_before_any_bus_access(rigs, kwargs):
    root, gt, model = rigs(requireReset=False)

    with pytest.raises(ValueError):
        engineOf(gt).point(0, **kwargs)

    assert model.transactions == 0


def stuckHook():
    """Reset hook whose ready never returns True, so the soft re-cold handshake fails."""
    return RxResetHook(pulse=lambda: None, ready=lambda: False, settle=0.0, timeout=0.1,
                       fallWait=0.01, hold=0.0, description='stuck hook')


def failingRestore(engine):
    def boom(snapshot):
        raise RuntimeError('restore boom')

    engine.port.restore = boom


def test_soft_cold_reports_a_restore_failure_after_a_failed_body(rigs):
    root, gt, model = rigs(requireReset=False)
    engine = engineOf(gt, hook=stuckHook())
    failingRestore(engine)

    with pytest.raises(EyeScanError) as info:
        engine.softCold(WINDOW)

    text = str(info.value)
    assert 'restore failed' in text and 'restore boom' in text
    assert 'could not confirm the RX reset' in text
    assert isinstance(info.value.__cause__, EyeScanError)
    assert 'could not confirm the RX reset' in str(info.value.__cause__)


def test_soft_cold_body_failure_with_a_clean_restore_is_raised_unchanged(rigs):
    root, gt, model = rigs(requireReset=False)

    with pytest.raises(EyeScanError) as info:
        engineOf(gt, hook=stuckHook()).softCold(WINDOW)

    assert 'could not confirm the RX reset' in str(info.value)
    assert 'restore failed' not in str(info.value)
    assert info.value.__cause__ is None or isinstance(info.value.__cause__, EyeScanNotActive)


def test_soft_cold_restore_failure_after_a_good_body_is_raised(rigs):
    root, gt, model = rigs(requireReset=False)
    engine = engineOf(gt)
    failingRestore(engine)

    with pytest.raises(RuntimeError, match='restore boom'):
        engine.softCold(WINDOW)


def test_child_soft_cold_publishes_the_typed_status_of_its_exception(rigs):
    root, gt, lane, model, mem = rigs('lane')
    control = ScanControl()
    control.abort()

    with pytest.raises(EyeScanAborted):
        gt.EyeScan.softCold(probeWindow=WINDOW, control=control)

    assert gt.EyeScan.Status.get() == 'ABORTED'


@pytest.mark.parametrize('exc, status', [
    (EyeScanAborted('stop'), 'ABORTED'),
    (EyeScanTimeout('slow'), 'TIMEOUT'),
    (EyeScanNotActive('dead'), 'NOT_ENABLED'),
    (EyeScanError('bad'), 'ERROR'),
    (RuntimeError('boom'), 'ERROR'),
])
def test_child_soft_cold_status_follows_the_exception_type(rigs, monkeypatch, exc, status):
    root, gt, model = rigs(requireReset=False)

    def raiser(self, probeWindow):
        raise exc

    monkeypatch.setattr(escan.EyeScanEngine, 'softCold', raiser)

    with pytest.raises(type(exc)):
        gt.EyeScan.softCold(probeWindow=WINDOW)

    assert gt.EyeScan.Status.get() == status


def test_fixed_prescale_numpy_integer_is_accepted(rigs):
    root, gt, model = rigs(requireReset=False, berFn=zero)
    model.setField(gt.RX_DATA_WIDTH, 4)

    result = engineOf(gt).point(0, fixedPrescale=np.int64(4))

    assert result.status is ScanStatus.OK
    assert result.bits[0] == 65535 * 2**5 * 32


def test_offset_beyond_the_half_range_is_refused_without_a_write(rigs):
    root, gt, model = rigs(requireReset=False)

    with pytest.raises(ValueError):
        engineOf(gt).point(65)

    assert model.writes == []


def test_point_through_the_lane_hook_keeps_the_link_configuration(rigs):
    root, gt, lane, model, mem = rigs('lane', berFn=ber)
    word = (0x1f << lane.Ctrl.TxDiffCtrl.bitOffset[0]) | (7 << lane.Ctrl.TxPreCursor.bitOffset[0]) \
        | (7 << lane.Ctrl.TxPostCursor.bitOffset[0])
    mem.words[mem.ctrlAddr] = word
    before = seedWords(model, gt)

    result = gt.EyeScan._engine().point(0)

    assert result.status is ScanStatus.OK
    assert mem.words[mem.ctrlAddr] == word
    assert seedWords(model, gt) == before
    assert model.resets == 1
