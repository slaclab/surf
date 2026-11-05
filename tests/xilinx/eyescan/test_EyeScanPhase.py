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
# - Sweep: the phase-unification bit (bit 11 of ES_HORZ_OFFSET) under the
#   'sign' and 'rate' rules on emulated GTHE3 and GTYE4 lanes: the bit written
#   at the activation probe, the line-rate measurement run and every scan
#   point, the encoding edges, the descriptor default, the expert keyword and
#   the refusal of a 'rate' scan without a line rate.
# - Stimulus: real Rogue transactions against Gthe3EyeModel and Gtye4EyeModel
#   with the seeded dual-Dirac BER model of the bathtub tests and a callable
#   RX reset hook; the model logs the signed count and bit 11 of every run.
# - Checks: under 'sign' bit 11 is set only for negative counts and the
#   model sees no phase violation; under 'rate' it is set for every count
#   above 10 Gb/s and for none at or below it; bits [10:0] always decode back
#   to the requested count; a bad keyword raises before any bus transaction; a
#   'rate' scan without a line rate is a typed ERROR naming LineRateGbps that
#   writes nothing and never pulses the RX reset, from the keyword and from the
#   descriptor default, on the synchronous calls and on the Start path.
# - Timing: countReads=1 and a zero settle keep the emulated runs short; the
#   model steps on status reads, so no test waits on real hardware time.

import dataclasses
from types import SimpleNamespace

import pytest

pr = pytest.importorskip('pyrogue', reason='Eye-scan tests require Rogue/PyRogue')
rogue = pytest.importorskip('rogue', reason='Eye-scan tests require Rogue/PyRogue')

import surf.xilinx.eyescan as es  # noqa: E402
from surf.xilinx.eyescan import FAMILIES, ScanStatus  # noqa: E402

from tests.xilinx.eyescan.gthe3_eye_model import bitOf, makeGtRoot  # noqa: E402
from tests.xilinx.eyescan.gtye4_eye_model import makeGtyRoot  # noqa: E402
from tests.xilinx.eyescan.test_EyeScanBathtub import Hook, gauss  # noqa: E402
from tests.xilinx.eyescan.test_EyeScanMargin import shifted  # noqa: E402

RATE_HIGH = 15.46875

# Everything that differs between the two families, keyed by family name
FAMS = {
    'GTHE3': SimpleNamespace(name='GTHE3', make=makeGtRoot),
    'GTYE4': SimpleNamespace(name='GTYE4', make=makeGtyRoot),
}


def gtyRig(**kw):
    """Started GTYE4 root with a cold lane, a hook and the model; returns (root, gt, model, hook)."""
    kw.setdefault('requireReset', True)
    kw.setdefault('berFn', gauss)
    kw.setdefault('countReads', 1)
    root, gt, model = makeGtyRoot(**kw)
    hook = Hook(model)
    gt.EyeScan.setRxReset(hook.pulse, hook.ready, settle=0.0, fallWait=0.05, timeout=0.5)
    return root, gt, model, hook


# ----------------------------------------------------------------------
# Tracer: one emulated GTYE4 bathtub under the 'rate' rule, and the refusal
# ----------------------------------------------------------------------
def test_rate_rule_above_ten_gbps_sets_bit_11_on_every_run():
    root, gt, model, hook = gtyRig()
    try:
        res = gt.EyeScan.runBathtub(step=16, lineRateGbps=RATE_HIGH, phaseUnification='rate', probeWindow=0.3)

        assert res.status is ScanStatus.OK, res.message
        assert res.meta['phaseUnification'] == 'rate'
        counts = [int(c) for c in res.horzCounts]
        # One entry per run; a point takes several runs, so each count repeats
        seen = [count for count, _ in model.horzLog]
        assert [c for i, c in enumerate(seen) if i == 0 or c != seen[i - 1]][2:-2] == counts
        # The first run is the activation probe at the eye centre, the second is the run at +half
        # that finds the data transitions; the same two runs follow the last point
        assert seen[0] == 0
        assert seen[1] == 64
        assert seen[-2:] == [0, 64]
        assert all(bit == 1 for _, bit in model.horzLog)
    finally:
        root.stop()


def test_rate_rule_without_a_line_rate_is_refused_before_any_write():
    root, gt, model, hook = gtyRig()
    try:
        assert gt.EyeScan.LineRateGbps.value() == 0
        res = gt.EyeScan.runBathtub(step=16, phaseUnification='rate', probeWindow=0.3)

        assert res.status is ScanStatus.ERROR
        assert 'LineRateGbps' in res.message
        assert model.writes == []
        assert hook.pulses == 0
    finally:
        root.stop()


# ----------------------------------------------------------------------
# Both rules on both families
# ----------------------------------------------------------------------
@pytest.fixture(params=['GTHE3', 'GTYE4'])
def fam(request):
    return FAMS[request.param]


@pytest.fixture
def rig(fam):
    roots = []

    def make(**kw):
        root, gt, model = fam.make(requireReset=True, berFn=gauss, countReads=1, **kw)
        roots.append(root)
        hook = Hook(model)
        gt.EyeScan.setRxReset(hook.pulse, hook.ready, settle=0.0, fallWait=0.05, timeout=0.5)
        return gt.EyeScan, model, hook, logHorz(model)

    yield make
    for root in roots:
        root.stop()


def logHorz(model):
    """Record (signed count, bit 11) of the horizontal field at every run start of ``model``."""
    log = []
    original = model._start

    def start():
        log.append((model._horzCount(), bitOf(model._field(model._pos.horz), 11)))
        original()

    model._start = start
    return log


def expectedBit(rule, rate, count, threshold=10.0):
    if rule == 'sign':
        return int(count < 0)
    return int(rate > threshold)


@pytest.mark.parametrize('rate', [RATE_HIGH, 6.25])
def test_sign_rule_sets_bit_11_only_for_negative_counts(rig, rate):
    child, model, hook, log = rig()

    res = child.runBathtub(step=16, lineRateGbps=rate, phaseUnification='sign', probeWindow=0.3)

    assert res.status is ScanStatus.OK, res.message
    assert res.meta['phaseUnification'] == 'sign'
    assert len(log) > len(res.horzCounts)
    assert all(bit == int(count < 0) for count, bit in log)
    assert model.phaseViolations == 0


@pytest.mark.parametrize('rate, bit', [(RATE_HIGH, 1), (6.25, 0)])
def test_rate_rule_sets_the_same_bit_11_for_every_count_and_every_run(rig, rate, bit):
    child, model, hook, log = rig()

    res = child.runBathtub(step=16, lineRateGbps=rate, phaseUnification='rate', probeWindow=0.3)

    assert res.status is ScanStatus.OK, res.message
    assert res.meta['phaseUnification'] == 'rate'
    assert {count for count, _ in log} >= {int(c) for c in res.horzCounts}
    assert {b for _, b in log} == {bit}


@pytest.mark.parametrize('kind', ['eye', 'margin'])
def test_rate_rule_covers_the_eye_and_margin_runs(rig, kind):
    child, model, hook, log = rig(eyeFn=shifted)

    if kind == 'eye':
        res = child.runEye(horzStep=8, vertStep=16, floor=1e-3, lineRateGbps=RATE_HIGH,
                           phaseUnification='rate', probeWindow=0.3)
    else:
        res = child.runMargin(horzStep=8, vertStep=16, horzRange=32, vertRange=32, floor=1e-3,
                              bathtubFloor=1e-3, lineRateGbps=RATE_HIGH, phaseUnification='rate',
                              probeWindow=0.3)

    assert res.meta['phaseUnification'] == 'rate'
    assert len(log) > 1
    assert {b for _, b in log} == {1}


def wordOf(rule, rate, count, family):
    engine = es.EyeScanEngine(SimpleNamespace(family=family))
    engine._phase = (rule, rate)
    return engine._horzWord(count)


@pytest.mark.parametrize('rule', ['sign', 'rate'])
@pytest.mark.parametrize('rate', [RATE_HIGH, 6.25])
@pytest.mark.parametrize('count', [-64, -1, 0, 1, 64])
def test_bits_10_to_0_decode_back_to_the_count_under_both_rules(fam, rule, rate, count):
    word = wordOf(rule, rate, count, FAMILIES[fam.name])

    assert 0 <= word < 1 << 12
    low = word & 0x7FF
    assert (low ^ 0x400) - 0x400 == count
    assert (word >> 11) & 1 == expectedBit(rule, rate, count)


def test_the_rate_threshold_is_exclusive_on_the_bus(rig):
    child, model, hook, log = rig()
    engine = child._engine()

    for rate, bit in ((10.0, 0), (10.000001, 1)):
        del log[:]
        res = engine.point(horz=1, lineRateGbps=rate, phaseUnification='rate', floor=1e-3, probeWindow=0.3)

        assert res.status is ScanStatus.OK, res.message
        assert log and {b for _, b in log} == {bit}, rate
        assert {count for count, _ in log} == {0, 1}


def test_the_two_rules_differ_only_where_the_rate_puts_bit_11(fam):
    family = FAMILIES[fam.name]
    counts = range(-64, 65)

    high = [c for c in counts if wordOf('sign', RATE_HIGH, c, family) != wordOf('rate', RATE_HIGH, c, family)]
    low = [c for c in counts if wordOf('sign', 6.25, c, family) != wordOf('rate', 6.25, c, family)]

    assert high == [c for c in counts if c >= 0]
    assert low == [c for c in counts if c < 0]
    assert all(wordOf('sign', RATE_HIGH, c, family) ^ wordOf('rate', RATE_HIGH, c, family) == 0x800 for c in high)


def test_no_scan_rule_writes_the_sign_encoding(fam):
    family = FAMILIES[fam.name]
    engine = es.EyeScanEngine(SimpleNamespace(family=family))

    assert engine._phase is None
    assert [engine._horzWord(c) for c in (-1, 0, 1)] == [0xFFF, 0, 1]


def test_an_unknown_rule_raises_before_any_bus_transaction(rig):
    child, model, hook, log = rig()
    seen = model.transactions
    engine = child._engine()
    calls = (
        lambda: child.runBathtub(phaseUnification='xyz', lineRateGbps=6.25),
        lambda: child.runEye(phaseUnification='xyz', lineRateGbps=6.25),
        lambda: child.runMargin(phaseUnification='xyz', lineRateGbps=6.25),
        lambda: engine.point(phaseUnification='xyz', lineRateGbps=6.25),
        lambda: engine.bathtub(phaseUnification='RATE', lineRateGbps=6.25),
        lambda: engine.eye(phaseUnification='', lineRateGbps=6.25),
        lambda: engine.margin(phaseUnification=1, lineRateGbps=6.25),
    )

    for call in calls:
        with pytest.raises(ValueError, match='phaseUnification'):
            call()

    assert model.transactions == seen
    assert hook.pulses == 0
    assert child.Status.get() != 'Running'


def test_none_records_the_descriptor_rule(rig, fam):
    child, model, hook, log = rig()

    res = child.runBathtub(step=16, lineRateGbps=6.25, probeWindow=0.3)

    assert res.meta['phaseUnification'] == FAMILIES[fam.name].phaseUnification == 'sign'
    assert all(bit == int(count < 0) for count, bit in log)


# ----------------------------------------------------------------------
# Refusal of a 'rate' scan without a line rate
# ----------------------------------------------------------------------
@pytest.mark.parametrize('kind', ['bathtub', 'eye', 'margin'])
def test_the_refusal_holds_for_every_scan(rig, kind):
    child, model, hook, log = rig()

    if kind == 'bathtub':
        res = child.runBathtub(phaseUnification='rate', probeWindow=0.3)
    elif kind == 'eye':
        res = child.runEye(phaseUnification='rate', probeWindow=0.3)
    else:
        res = child.runMargin(phaseUnification='rate', probeWindow=0.3)

    assert res.status is ScanStatus.ERROR
    assert 'LineRateGbps' in res.message
    assert res.meta['phaseUnification'] == 'rate'
    assert model.writes == [] and hook.pulses == 0 and log == []
    assert child.Status.get() == 'ERROR'


def test_the_refusal_holds_for_an_engine_point(rig):
    child, model, hook, log = rig()

    res = child._engine().point(horz=0, phaseUnification='rate', measureLineRate=True)

    assert res.status is ScanStatus.ERROR
    assert 'LineRateGbps' in res.message
    assert model.writes == [] and hook.pulses == 0 and log == []


def test_a_non_positive_rate_argument_is_refused_under_the_rate_rule(rig):
    child, model, hook, log = rig()

    for rate in (0.0, -6.25):
        res = child.runBathtub(step=16, lineRateGbps=rate, phaseUnification='rate', probeWindow=0.3)

        assert res.status is ScanStatus.ERROR and 'LineRateGbps' in res.message
    assert model.writes == []


def test_a_set_line_rate_variable_satisfies_the_rate_rule(rig):
    child, model, hook, log = rig()
    child.LineRateGbps.set(RATE_HIGH)

    res = child.runBathtub(step=16, phaseUnification='rate', probeWindow=0.3)

    assert res.status is ScanStatus.OK, res.message
    assert {b for _, b in log} == {1}


def test_the_sign_rule_with_an_undefined_rate_still_measures_and_warns(rig):
    child, model, hook, log = rig()

    res = child.runBathtub(step=16, phaseUnification='sign', probeWindow=0.3)

    assert res.status is ScanStatus.OK, res.message
    assert res.meta['lineRateSource'] == 'measured'
    assert len(res.meta['warnings']) == 1
    assert all(bit == int(count < 0) for count, bit in log)


def test_a_descriptor_default_of_rate_refuses_a_scan_without_a_rate(rig, fam, monkeypatch):
    monkeypatch.setitem(FAMILIES, fam.name, dataclasses.replace(FAMILIES[fam.name], phaseUnification='rate'))
    child, model, hook, log = rig()

    res = child.runBathtub(probeWindow=0.3)

    assert res.status is ScanStatus.ERROR and 'LineRateGbps' in res.message
    assert res.meta['phaseUnification'] == 'rate'
    assert model.writes == [] and hook.pulses == 0

    ok = child.runBathtub(step=16, lineRateGbps=RATE_HIGH, probeWindow=0.3)
    assert ok.status is ScanStatus.OK, ok.message
    assert ok.meta['phaseUnification'] == 'rate'
    assert {b for _, b in log} == {1}


def test_the_start_path_shows_the_refusal(rig, fam, monkeypatch, tmp_path):
    monkeypatch.setitem(FAMILIES, fam.name, dataclasses.replace(FAMILIES[fam.name], phaseUnification='rate'))
    child, model, hook, log = rig()
    child.OutputDir.set(str(tmp_path))
    child.Mode.setDisp('Bathtub')
    child.HorzStep.set(16)

    child.Start()
    child._thread.join(60)

    assert not child._thread.is_alive()
    assert child.Status.get() == 'ERROR'
    assert 'LineRateGbps' in child.Message.get()
    assert model.writes == [] and hook.pulses == 0


def test_the_rule_has_no_variable(rig):
    child, model, hook, log = rig()

    assert not [name for name in child.nodes if 'phase' in name.lower()]


def test_gtye4_phase_unification_default_matches_the_hardware_record():
    assert FAMILIES['GTYE4'].phaseUnification == 'sign'

    root, gt, model, hook = gtyRig()
    log = logHorz(model)
    try:
        assert gt.EyeScan.LineRateGbps.value() == 0
        res = gt.EyeScan.runBathtub(step=16, probeWindow=0.3)

        assert res.status is ScanStatus.OK, res.message
        assert res.meta['phaseUnification'] == 'sign'
        assert res.meta['lineRateSource'] == 'measured'
        assert len(res.meta['warnings']) == 1
        assert all(bit == int(count < 0) for count, bit in log)

        log.clear()
        ok = gt.EyeScan.runBathtub(step=16, lineRateGbps=6.25, probeWindow=0.3)

        assert ok.status is ScanStatus.OK, ok.message
        assert ok.meta['phaseUnification'] == 'sign'
        assert all(bit == int(count < 0) for count, bit in log)
    finally:
        root.stop()
