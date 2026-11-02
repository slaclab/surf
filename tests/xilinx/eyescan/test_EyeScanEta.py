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
# - Sweep: the scan time model of the eye scan (the pure point, point-count and
#   scan functions) and its two users, the EtaSeconds link variable of the
#   EyeScan child and the weighted progress the engine reports.
# - Stimulus: closed-form arithmetic over the prescale plan for the pure
#   functions; real Rogue transactions against Gthe3EyeModel and Gtye4EyeModel
#   with the seeded separable eye of the margin tests for the emulated scans.
# - Checks: pointSeconds sums the cumulative prescale plan at the calibrated
#   sampler rate plus the per-run overhead and keeps only the overhead when the
#   line rate is unknown; scanPointCounts equals the number of points an
#   emulated scan measures for every tested step and range; EtaSeconds follows
#   the knobs with no bus transaction, reads NaN while no line rate is set and
#   none has been measured, prices the lane width and divider of the family
#   descriptor before the first scan, and switches to the measured estimate once
#   a running scan is past 2 percent; progress grows in proportion to modelled
#   seconds.
#   The line rate is either set (recorded as set, no extra run) or measured with
#   one prescale 8 run right after the activation (recorded as measured with a
#   warning in the metadata and in Message, LineRateGbps left at 0), and the
#   measured rate feeds the next estimate.
# - Timing: countReads=1 and a zero settle keep the emulated runs short; the
#   estimate checks use no wall-clock waits.

import math
import time

import pytest

pr = pytest.importorskip('pyrogue', reason='Eye-scan tests require Rogue/PyRogue')
rogue = pytest.importorskip('rogue', reason='Eye-scan tests require Rogue/PyRogue')
yaml = pytest.importorskip('yaml', reason='Eye-scan tests require PyYAML')

import surf.xilinx.eyescan as es  # noqa: E402
from surf.xilinx.eyescan import _EyeScanEngine as engine  # noqa: E402

from tests.xilinx.eyescan.gthe3_eye_model import makeGtRoot  # noqa: E402
from tests.xilinx.eyescan.gtye4_eye_model import makeGtyRoot  # noqa: E402
from tests.xilinx.eyescan.test_EyeScanBathtub import Hook  # noqa: E402
from tests.xilinx.eyescan.test_EyeScanMargin import shifted  # noqa: E402

MAX_BITS_PER_SAMPLE_RUN = 65535

# (driver emulation, descriptor lane width): the pre-scan estimate prices this width at RXOUT_DIV 2
BOTH_FAMILIES = [
    pytest.param(makeGtRoot, 32, id='GTHE3'),
    pytest.param(makeGtyRoot, 64, id='GTYE4'),
]
MODES = ['Bathtub', 'Eye', 'Margin']


def modelled(width, rate, rungs, nUt=2, maxTime=30.0):
    """Seconds of the cumulative runs of ``rungs`` at ``rate`` Gb/s, from first principles."""
    seconds = 0.0
    for prescale in rungs:
        bits = MAX_BITS_PER_SAMPLE_RUN * (1 << (1 + prescale)) * width
        runSeconds = 0.0 if rate == 0 else min(maxTime, bits / (rate * 1e9 * engine.SAMPLER_EFFICIENCY))
        seconds += nUt * (runSeconds + engine.RUN_OVERHEAD)
    return seconds


@pytest.fixture
def rig():
    roots = []

    def make(hook=False, maker=makeGtRoot, **kw):
        root, gt, model = maker(requireReset=True, countReads=1, eyeFn=shifted, **kw)
        roots.append(root)
        if hook:
            rxHook = Hook(model)
            gt.EyeScan.setRxReset(rxHook.pulse, rxHook.ready, settle=0.0, fallWait=0.05, timeout=0.5)
        return gt.EyeScan, model

    yield make
    for root in roots:
        root.stop()


def test_the_calibrated_constants_are_the_measured_ones():
    assert engine.SAMPLER_EFFICIENCY == 0.965
    assert engine.RUN_OVERHEAD == 0.000561


def test_a_deep_floor_costs_the_whole_cumulative_plan():
    seconds = engine.pointSeconds(1e-9, 0.95, 32, 6.25)

    assert seconds == pytest.approx(modelled(32, 6.25, (0, 3, 6, 8, 10)), rel=1e-9)
    bits = 2 * MAX_BITS_PER_SAMPLE_RUN * 32 * sum(1 << (1 + p) for p in (0, 3, 6, 8, 10))
    assert bits == pytest.approx(11.35e9, rel=1e-3)


def test_a_shallow_floor_uses_the_single_first_rung():
    assert engine.pointSeconds(1e-6, 0.95, 32, 6.25) == pytest.approx(modelled(32, 6.25, (0,)), rel=1e-9)


def test_lpm_runs_one_ut_sign_and_halves_the_cost():
    dfe = engine.pointSeconds(1e-9, 0.95, 32, 6.25)
    lpm = engine.pointSeconds(1e-9, 0.95, 32, 6.25, nUt=1)

    assert lpm == pytest.approx(dfe / 2, rel=1e-9)


def test_an_unknown_line_rate_leaves_only_the_overhead_terms():
    assert engine.pointSeconds(1e-9, 0.95, 32, 0.0) == pytest.approx(10 * engine.RUN_OVERHEAD, rel=1e-12)
    assert engine.pointSeconds(1e-6, 0.95, 32, 0.0) == pytest.approx(2 * engine.RUN_OVERHEAD, rel=1e-12)


def test_a_fixed_prescale_is_one_rung():
    seconds = engine.pointSeconds(1e-9, 0.95, 32, 6.25, fixedPrescale=8)

    assert seconds == pytest.approx(modelled(32, 6.25, (8,)), rel=1e-9)


def test_a_long_run_is_cut_at_the_time_limit():
    seconds = engine.pointSeconds(1e-9, 0.95, 32, 6.25, maxTimePerRun=0.1)

    assert seconds == pytest.approx(modelled(32, 6.25, (0, 3, 6, 8, 10), maxTime=0.1), rel=1e-9)
    assert seconds < engine.pointSeconds(1e-9, 0.95, 32, 6.25)


def test_the_point_counts_of_the_documented_grids():
    eye = engine.scanPointCounts('Eye', horzStep=2, vertStep=4, horzRange=64, vertRange=127)
    margin = engine.scanPointCounts('Margin', horzStep=2, vertStep=4, horzRange=64, vertRange=127)
    bathtub = engine.scanPointCounts('Bathtub', horzStep=2, vertStep=4, horzRange=64, vertRange=127)

    assert eye['eye'] == 4095
    assert (margin['eye'], margin['horz'], margin['vert']) == (4095, 129, 255)
    assert bathtub['horz'] == 65


def test_an_unknown_mode_is_refused():
    with pytest.raises(ValueError, match='mode'):
        engine.scanPointCounts('Sphere', horzStep=2, vertStep=4, horzRange=64, vertRange=127)


GRIDS = [(8, 16, 64, 64), (4, 8, 32, 40), (64, 16, 64, 16)]


@pytest.mark.parametrize('horzStep, vertStep, horzRange, vertRange', GRIDS)
def test_the_eye_point_count_is_what_the_engine_measures(rig, horzStep, vertStep, horzRange, vertRange):
    child, model = rig(hook=True)

    res = child.runEye(horzStep=horzStep, vertStep=vertStep, horzRange=horzRange, vertRange=vertRange,
                       floor=1e-3, probeWindow=0.3)

    counts = engine.scanPointCounts('Eye', horzStep=horzStep, vertStep=vertStep,
                                    horzRange=horzRange, vertRange=vertRange)
    assert res.status in (es.ScanStatus.OK, es.ScanStatus.CLOSED)
    assert int(res.measured.sum()) == counts['eye']


@pytest.mark.parametrize('horzStep, vertStep, horzRange, vertRange', GRIDS)
def test_the_margin_sweep_counts_are_what_the_engine_measures(rig, horzStep, vertStep, horzRange, vertRange):
    child, model = rig(hook=True)

    res = child.runMargin(horzStep=horzStep, vertStep=vertStep, horzRange=horzRange, vertRange=vertRange,
                          floor=1e-3, bathtubFloor=1e-3, probeWindow=0.3)

    counts = engine.scanPointCounts('Margin', horzStep=horzStep, vertStep=vertStep,
                                    horzRange=horzRange, vertRange=vertRange)
    assert res.status is es.ScanStatus.OK, res.message
    assert int(res.eye.measured.sum()) == counts['eye']
    assert res.horz.positions.size == counts['horz'] and res.vert.positions.size == counts['vert']


def knobs(**over):
    base = dict(floor=1e-6, bathtubFloor=1e-9, confidence=0.95, horzStep=2, vertStep=4, horzRange=64,
                vertRange=127, equalizer='dfe', fixedPrescale=None, lineRateGbps=0.0, width=32,
                maxTimePerRun=30.0)
    base.update(over)
    return base


def test_the_margin_estimate_is_the_eye_plus_the_cross():
    seconds = engine.estimateScanSeconds('Margin', **knobs())

    eye = 4095 * engine.pointSeconds(1e-6, 0.95, 32, 0.0)
    cross = (129 + 255) * engine.pointSeconds(1e-9, 0.95, 32, 0.0)
    assert seconds == pytest.approx(eye + cross, rel=1e-9)


def test_the_estimate_adds_the_activation_and_the_line_rate_run():
    base = engine.estimateScanSeconds('Eye', **knobs(lineRateGbps=6.25))

    assert engine.estimateScanSeconds('Eye', activationSeconds=1.5, **knobs(lineRateGbps=6.25)) \
        == pytest.approx(base + 1.5, rel=1e-12)
    measured = engine.estimateScanSeconds('Eye', measureLineRate=True, **knobs(lineRateGbps=6.25))
    assert measured == pytest.approx(base + modelled(32, 6.25, (8,), nUt=1), rel=1e-9)


def test_bathtub_and_eye_estimates_use_their_own_floor():
    bathtub = engine.estimateScanSeconds('Bathtub', **knobs(lineRateGbps=6.25))
    eye = engine.estimateScanSeconds('Eye', **knobs(lineRateGbps=6.25))

    assert bathtub == pytest.approx(65 * engine.pointSeconds(1e-9, 0.95, 32, 6.25), rel=1e-9)
    assert eye == pytest.approx(4095 * engine.pointSeconds(1e-6, 0.95, 32, 6.25), rel=1e-9)


@pytest.mark.parametrize('maker, width', BOTH_FAMILIES)
def test_eta_reads_nan_while_no_line_rate_is_known(rig, maker, width):
    child, model = rig(maker=maker)

    for mode in MODES:
        child.Mode.setDisp(mode)
        assert math.isnan(child.EtaSeconds.get()), mode
    assert child.LineRateGbps.value() == 0.0 and child._measuredLineRate == 0.0


@pytest.mark.parametrize('maker, width', BOTH_FAMILIES)
def test_eta_before_any_scan_is_the_estimate_of_the_knobs_at_the_set_rate(rig, maker, width):
    child, model = rig(maker=maker)
    child.LineRateGbps.set(6.25)

    for mode in MODES:
        child.Mode.setDisp(mode)
        expected = engine.estimateScanSeconds(mode, **knobs(lineRateGbps=6.25, width=width))
        assert math.isfinite(child.EtaSeconds.get()), mode
        assert child.EtaSeconds.get() == pytest.approx(expected, rel=1e-9), mode
    # The descriptor lane is what is priced: the other family's width would give another number
    other = engine.estimateScanSeconds('Margin', **knobs(lineRateGbps=6.25, width=96 - width))
    assert child.EtaSeconds.get() != pytest.approx(other, rel=1e-6)


@pytest.mark.parametrize('maker, width', BOTH_FAMILIES)
def test_eta_follows_the_knobs(rig, maker, width):
    child, model = rig(maker=maker)
    child.LineRateGbps.set(6.25)
    before = child.EtaSeconds.get()

    child.HorzStep.set(4)

    assert child.EtaSeconds.get() < before
    child.Mode.setDisp('Bathtub')
    bathtub = child.EtaSeconds.get()
    child.Mode.setDisp('Eye')
    assert child.EtaSeconds.get() != bathtub


@pytest.mark.parametrize('maker, width', BOTH_FAMILIES)
def test_eta_evaluation_issues_no_bus_transaction(rig, maker, width):
    child, model = rig(maker=maker)
    count = model.transactions

    child.EtaSeconds.get()
    child.LineRateGbps.set(6.25)
    child.HorzStep.set(8)
    child.EtaSeconds.get()
    child.EtaSeconds.value()

    assert model.transactions == count


@pytest.mark.parametrize('maker, width', BOTH_FAMILIES)
def test_eta_is_a_noconfig_read_only_link_variable(rig, maker, width):
    child, model = rig(maker=maker)
    var = child.EtaSeconds

    assert isinstance(var, pr.LinkVariable) and var.mode == 'RO'
    assert var.inGroup('NoConfig') and var.units == 's'
    assert 'NaN' in var.description and 'LineRateGbps' in var.description
    assert f'W {width}' in var.description and 'RXOUT_DIV 2' in var.description


@pytest.mark.parametrize('family', ['GTXE2', 'GTPE2', 'GTZE9'])
def test_the_eta_description_of_a_family_without_a_descriptor_names_no_lane(family):
    child = es.EyeScan(name='E', family=family)

    assert 'NaN' in child.EtaSeconds.description and 'LineRateGbps' in child.EtaSeconds.description
    assert "the family's lane values" in child.EtaSeconds.description
    assert 'W ' not in child.EtaSeconds.description
    assert math.isnan(child.EtaSeconds.value())


def test_eta_with_an_invalid_knob_reads_nan_instead_of_raising(rig):
    child, model = rig()
    child.LineRateGbps.set(6.25)
    child.EyeBerFloor.set(0.0)

    value = child.EtaSeconds.get()

    assert value != value


def test_the_measured_estimate_replaces_the_model_past_two_percent(rig):
    child, model = rig()
    child.Running.set(True)
    child._scanStart = time.monotonic() - 10.0
    try:
        child.Progress.set(0.01)
        early = child.EtaSeconds.get()
        child.LineRateGbps.set(6.25)
        earlyRated = child.EtaSeconds.get()
        child.LineRateGbps.set(0.0)
        child.Progress.set(0.5)
        half = child.EtaSeconds.get()
        child.Progress.set(0.8)
        late = child.EtaSeconds.get()
    finally:
        child.Running.set(False)

    assert half == pytest.approx(10.0, rel=0.05)
    assert late == pytest.approx(10.0 / 0.8 * 0.2, rel=0.05)
    assert late < half
    # Under 2 percent the model is used: NaN without a rate, the estimate of the knobs with one
    assert math.isnan(early)
    assert earlyRated == pytest.approx(
        engine.estimateScanSeconds('Margin', **knobs(lineRateGbps=6.25)), rel=1e-9)


def test_progress_is_weighted_by_the_modelled_seconds(rig):
    child, model = rig(hook=True)
    marks = []
    control = es.ScanControl(onProgress=lambda done, total: marks.append((done, total)))
    args = dict(horzStep=8, vertStep=8, horzRange=32, vertRange=48, floor=1e-3, bathtubFloor=1e-9,
                lineRateGbps=6.25)

    res = child._engine(control).margin(probeWindow=0.3, **args)

    assert res.status is es.ScanStatus.OK, res.message
    counts = engine.scanPointCounts('Margin', horzStep=8, vertStep=8, horzRange=32, vertRange=48)
    eye = counts['eye'] * engine.pointSeconds(1e-3, 0.95, 32, 6.25)
    cross = (counts['horz'] + counts['vert']) * engine.pointSeconds(1e-9, 0.95, 32, 6.25)
    assert len(marks) == counts['eye'] + counts['horz'] + counts['vert']
    totals = {total for _, total in marks}
    assert len(totals) == 1
    total = totals.pop()
    assert total == pytest.approx((eye + cross) * 1e6, rel=1e-3)
    dones = [done for done, _ in marks]
    assert dones == sorted(dones) and dones[-1] == total
    eyeShare = dones[counts['eye'] - 1] / total
    assert eyeShare == pytest.approx(eye / (eye + cross), rel=1e-3)
    assert eyeShare != pytest.approx(counts['eye'] / len(marks), rel=0.1)


RATE_PRESCALE = 8


def prescale8Runs(model):
    return [entry for entry in model.runLog if entry[3] == RATE_PRESCALE]


def finish(child, timeout=120):
    child._thread.join(timeout)
    assert not child._thread.is_alive()


def test_line_rate_is_a_noconfig_read_write_local_variable_defaulting_to_zero(rig):
    child, model = rig()
    var = child.LineRateGbps

    assert isinstance(var, pr.LocalVariable) and var.mode == 'RW'
    assert var.inGroup('NoConfig') and var.units == 'Gb/s'
    assert var.value() == 0.0 and not var.hidden
    assert 'not defined' in var.description


def test_neither_eta_nor_line_rate_reaches_a_saved_yaml(rig):
    child, model = rig()
    root = child.root

    config = yaml.safe_load(root.getYaml(readFirst=False, modes=['RW', 'WO'], excGroups='NoConfig'))
    state = yaml.safe_load(root.getYaml(readFirst=False, modes=['RW', 'RO', 'WO'], excGroups='NoState'))
    everything = yaml.safe_load(root.getYaml(readFirst=False, modes=['RW', 'RO', 'WO']))

    def keys(tree, found=None):
        found = set() if found is None else found
        if isinstance(tree, dict):
            for key, value in tree.items():
                found.add(key)
                keys(value, found)
        return found

    assert not keys(config) & {'EtaSeconds', 'LineRateGbps'}
    assert not keys(state) & {'EtaSeconds', 'LineRateGbps'}
    assert {'EtaSeconds', 'LineRateGbps'} <= keys(everything)


@pytest.mark.parametrize('kind', ['eye', 'bathtub', 'margin'])
def test_a_set_line_rate_is_recorded_as_set_and_runs_no_extra_measurement(rig, kind):
    child, model = rig(hook=True)
    child.LineRateGbps.set(6.25)

    res = runKind(child, kind)

    assert res.meta['lineRateGbps'] == 6.25 and res.meta['lineRateSource'] == 'set'
    assert res.meta['warnings'] == []
    assert prescale8Runs(model) == []


def runKind(child, kind, **kw):
    if kind == 'eye':
        return child.runEye(horzStep=8, vertStep=16, floor=1e-3, probeWindow=0.3, **kw)
    if kind == 'bathtub':
        return child.runBathtub(step=8, floor=1e-3, probeWindow=0.3, **kw)
    return child.runMargin(horzStep=8, vertStep=16, horzRange=32, vertRange=32, floor=1e-3, bathtubFloor=1e-3,
                           probeWindow=0.3, **kw)


@pytest.mark.parametrize('kind', ['eye', 'bathtub', 'margin'])
def test_an_undefined_line_rate_is_measured_once_and_warned_about(rig, kind):
    child, model = rig(hook=True)

    res = runKind(child, kind)

    assert res.meta['lineRateSource'] == 'measured' and res.meta['lineRateGbps'] > 0
    assert len(res.meta['warnings']) == 1
    text = res.meta['warnings'][0]
    assert 'LineRateGbps is not defined' in text and 'less accurate' in text
    assert len(prescale8Runs(model)) == 1
    # The probe of the activation is run 0 and run 1 is the run at +half that finds the data transitions;
    # the measurement is the very next run at the eye centre
    assert model.runLog[1] == (64, 0, 0, 0)
    assert model.runLog[2] == (0, 0, 0, RATE_PRESCALE)
    assert child.LineRateGbps.value() == 0.0


def test_a_scan_that_was_given_a_rate_overrides_the_variable(rig):
    child, model = rig(hook=True)
    child.LineRateGbps.set(6.25)

    res = runKind(child, 'eye', lineRateGbps=0.0)

    assert res.meta['lineRateSource'] == 'measured'
    assert len(prescale8Runs(model)) == 1


def test_direct_engine_calls_default_to_no_measurement(rig):
    child, model = rig(hook=True)

    res = child._engine().eye(horzStep=8, vertStep=16, floor=1e-3, probeWindow=0.3)

    assert res.meta['lineRateSource'] == 'undefined' and res.meta['lineRateGbps'] == 0.0
    assert res.meta['warnings'] == []
    assert prescale8Runs(model) == []


def test_a_start_run_with_an_undefined_rate_ends_with_the_warning_in_message(rig, tmp_path):
    child, model = rig(hook=True)
    child.OutputDir.set(str(tmp_path))
    child.Mode.setDisp('Eye')
    child.HorzStep.set(8)
    child.VertStep.set(16)
    child.EyeBerFloor.set(1e-3)

    child.Start()
    finish(child)

    assert child.Status.get() == 'OK', child.Message.get()
    message = child.Message.get()
    assert 'LineRateGbps is not defined' in message and 'less accurate' in message
    assert child.lastResult.meta['lineRateSource'] == 'measured'


def test_a_start_run_with_a_set_rate_has_no_warning(rig, tmp_path):
    child, model = rig(hook=True)
    child.OutputDir.set(str(tmp_path))
    child.LineRateGbps.set(6.25)
    child.Mode.setDisp('Eye')
    child.HorzStep.set(8)
    child.VertStep.set(16)
    child.EyeBerFloor.set(1e-3)

    child.Start()
    finish(child)

    assert child.Status.get() == 'OK', child.Message.get()
    assert 'not defined' not in child.Message.get()
    assert prescale8Runs(model) == []


@pytest.mark.parametrize('maker, width', BOTH_FAMILIES)
def test_eta_is_nan_then_priced_at_the_measured_rate_then_the_set_one(rig, maker, width):
    child, model = rig(hook=True, maker=maker)
    child.Mode.setDisp('Eye')
    activation = 0.05 + 0.05 + 0.0 + 0.1

    def expected(rate, measure):
        return engine.estimateScanSeconds(
            'Eye', measureLineRate=measure, activationSeconds=activation, **knobs(lineRateGbps=rate, width=width))

    assert math.isnan(child.EtaSeconds.get())

    runKind(child, 'eye')
    measured = child.EtaSeconds.get()
    rate = child._measuredLineRate
    assert rate > 0 and child.LineRateGbps.value() == 0.0
    assert child._laneInfo['width'] == width and child._laneInfo['divider'] == 2
    assert math.isfinite(measured)
    assert measured == pytest.approx(expected(rate, True), rel=1e-9)

    child.LineRateGbps.set(6.25)
    assert child.EtaSeconds.get() == pytest.approx(expected(6.25, False), rel=1e-9)


def test_eta_follows_a_change_of_the_line_rate(rig):
    child, model = rig()
    child.Mode.setDisp('Eye')
    assert math.isnan(child.EtaSeconds.get())

    child.LineRateGbps.set(6.25)
    slow = child.EtaSeconds.get()
    child.LineRateGbps.set(10.0)
    fast = child.EtaSeconds.get()

    assert math.isfinite(slow) and math.isfinite(fast) and fast < slow
    child.LineRateGbps.set(0.0)
    assert math.isnan(child.EtaSeconds.get())
