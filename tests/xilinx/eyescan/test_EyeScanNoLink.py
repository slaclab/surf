# Test methodology:
# - Sweep: the scans and the probe of a lane that has no link, on emulated
#   GTHE3 and GTYE4 lanes. A lane that delivers no data shows up in three ways:
#   a static input whose offset sampler counts no errors anywhere, not even at
#   the two ends of the UI where a live link shows its data transitions; an
#   activation whose centre run reaches END with fewer samples than a full run;
#   and runs that reach END with no samples while a scan is under way.
# - Stimulus: real Rogue transactions against Gthe3EyeModel and Gtye4EyeModel
#   with a callable RX reset hook. A berFn that returns 0.0 is the static
#   input; the seeded dual-Dirac model of the bathtub tests is a healthy lane;
#   with neither berFn nor eyeFn the model is a clean link whose transitions
#   show at the two ends of the UI; endSamples is the short END of a run that
#   the receiver cut short; an onState callback that zeroes the sample counter
#   (or sticks the status in COUNT) after the activation run is a link that
#   drops once the sampler is armed, and a scripted ready() is a drop the hook
#   reports.
# - Checks: a full-range bathtub, eye and margin of the static lane end CLOSED
#   with both causes (sampler out of step, link closed or unlocked) in the
#   message and in the scan warnings, keep and save every measured point and
#   restore the registers apart from the enables; the probe of the static lane
#   is CLOSED with the same text after at most two extra runs at the ends of
#   the UI, and a probe whose edge run counts no samples is NOT_ENABLED; the
#   same edge runs follow every clean activation of the three scans, so a
#   static lane ends CLOSED on any step or range, including grids that never
#   land on the ends of the UI (an edge run without samples in a scan leaves the
#   decision to the scan points); a centre run that
#   ends short of 65535 samples is treated like a full error counter, under
#   Auto (reset again up to SYNC_RESETS times) and under Never; a run that
#   reaches END by itself with no samples during a scan is a link drop and the
#   second one ends the scan UNLOCKED, as does a timeout while the ready signal
#   reads False; a timeout with ready True stays TIMEOUT and so does a point.
#   The recovery from a first drop repeats the eye-centre run: a drop that
#   leaves the sampler out of step ends the scan CLOSED with the two-cause
#   warning and every point kept, a drop that keeps it in step adds nothing.
#   Healthy lanes are unchanged.
# - Timing: countReads=1 and a zero settle keep the emulated runs short; the
#   model steps on status reads, so no test waits on real hardware time. The
#   stuck runs use a 0.2 s run deadline.

import pytest

pr = pytest.importorskip('pyrogue', reason='Eye-scan tests require Rogue/PyRogue')

import numpy as np  # noqa: E402
rogue = pytest.importorskip('rogue', reason='Eye-scan tests require Rogue/PyRogue')

from surf.xilinx.eyescan import EyeScanEngine, ResetPolicy, ScanStatus, loadResult  # noqa: E402
from surf.xilinx.eyescan._EyeScanEngine import SYNC_RESETS  # noqa: E402

from tests.xilinx.eyescan.gthe3_eye_model import SAMPLE_MAX, makeGtRoot  # noqa: E402
from tests.xilinx.eyescan.gtye4_eye_model import makeGtyRoot  # noqa: E402
from tests.xilinx.eyescan.test_EyeScanBathtub import Hook, gauss, seedWords  # noqa: E402

FLOOR = 1e-9
WINDOW = 0.3

# The two causes a lane without a link can have
OUT_OF_STEP = 'out of step with the data sampler'
LINK_DOWN = 'link is closed or unlocked'

FAMS = {'GTHE3': makeGtRoot, 'GTYE4': makeGtyRoot}


def static(horz, ut):
    """A static input: no errors at any offset."""
    return 0.0


@pytest.fixture(params=['GTHE3', 'GTYE4'])
def rig(request):
    roots = []

    def make(falseCalls=(), desyncOnDrop=False, **kw):
        kw.setdefault('requireReset', True)
        kw.setdefault('berFn', gauss)
        kw.setdefault('countReads', 1)
        root, gt, model = FAMS[request.param](**kw)
        roots.append(root)
        hook = Hook(model, falseCalls, desyncOnDrop)
        gt.EyeScan.setRxReset(hook.pulse, hook.ready, settle=0.0, fallWait=0.05, timeout=0.5)
        return gt, model, hook

    yield make
    for root in roots:
        root.stop()


def test_a_static_lane_scans_to_closed_with_the_warning_and_its_data(rig, tmp_path):
    gt, model, hook = rig(berFn=static)
    before = seedWords(model, gt)

    res = gt.EyeScan.runBathtub(step=16, floor=FLOOR, probeWindow=WINDOW)

    assert res.status is ScanStatus.CLOSED, res.message
    assert OUT_OF_STEP in res.message and LINK_DOWN in res.message
    assert any(OUT_OF_STEP in w and LINK_DOWN in w for w in res.meta['warnings'])
    assert list(res.horzCounts) == [-64, -48, -32, -16, 0, 16, 32, 48, 64]
    assert res.bits.sum() > 0 and res.errors.sum() == 0
    assert model.getField(gt.ES_CONTROL) == 0
    assert seedWords(model, gt) == before

    outcome = gt.EyeScan.save(res, str(tmp_path), png=False)
    assert outcome.errors == []
    _, meta = loadResult(outcome.npzPath)
    assert OUT_OF_STEP in meta['message'] and LINK_DOWN in meta['message']


def test_a_healthy_bathtub_stays_open_without_a_warning(rig):
    gt, model, hook = rig()

    res = gt.EyeScan.runBathtub(step=16, floor=FLOOR, probeWindow=WINDOW)

    assert res.status is ScanStatus.OK, res.message
    assert OUT_OF_STEP not in res.message and LINK_DOWN not in res.message
    assert not any(OUT_OF_STEP in w for w in res.meta['warnings'])


def test_the_default_model_shows_transitions_at_the_ends_of_the_ui(rig):
    gt, model, hook = rig(berFn=None)

    res = gt.EyeScan.runBathtub(step=16, floor=FLOOR, probeWindow=WINDOW)

    assert res.status is ScanStatus.OK, res.message
    assert res.errors[:, 0].sum() > 0 and res.errors[:, -1].sum() > 0
    assert res.errors[:, 1:-1].sum() == 0


def warm(gt, model):
    """An already active sampler, as the Never policy finds it."""
    model.setField(gt.ES_ERRDET_EN, 1)
    model.setField(gt.ES_EYE_SCAN_EN, 1)
    model.activate()


def emptyAfterActivation(model):
    """Every run after the activation run reaches END with no samples; a reset ends the condition."""
    reset = model.pmaReset

    def pulse():
        model.zeroSamples = False
        reset()

    def onState(name):
        if name == 'END':
            model.zeroSamples = True

    model.pmaReset = pulse
    model.onState = onState


def stickAfterActivation(model):
    """Every run after the activation run stays in COUNT until its deadline."""
    def onState(name):
        if name == 'END':
            model.stuckStatus = 0x6

    model.onState = onState


def test_the_probe_of_a_static_lane_is_closed_with_the_warning(rig):
    gt, model, hook = rig(berFn=static)
    before = seedWords(model, gt)

    res = gt.EyeScan.probe(resetPolicy=ResetPolicy.Auto, probeWindow=WINDOW)

    assert res.status is ScanStatus.CLOSED, res.message
    assert OUT_OF_STEP in res.message and LINK_DOWN in res.message
    assert OUT_OF_STEP in res.syncWarning and LINK_DOWN in res.syncWarning
    assert 'counts -64 and +64' in res.syncWarning
    assert res.sampleCount == SAMPLE_MAX
    assert hook.pulses == 1
    # The activation run, then the runs at +half and -half
    assert model.runs == 3
    assert model.getField(gt.ES_CONTROL) == 0
    assert seedWords(model, gt) == before


def test_the_probe_of_a_static_lane_under_never_is_closed_with_the_warning(rig):
    gt, model, hook = rig(berFn=static)
    warm(gt, model)

    res = gt.EyeScan.probe(resetPolicy=ResetPolicy.Never, probeWindow=WINDOW)

    assert res.status is ScanStatus.CLOSED, res.message
    assert OUT_OF_STEP in res.message and LINK_DOWN in res.message
    assert OUT_OF_STEP in res.syncWarning and LINK_DOWN in res.syncWarning
    assert res.sampleCount == SAMPLE_MAX
    assert hook.pulses == 0 and not res.resetCalled
    assert model.getField(gt.ES_CONTROL) == 0


@pytest.mark.parametrize('berFn', [gauss, None])
def test_the_probe_of_a_healthy_lane_stays_ok_after_one_edge_run(rig, berFn):
    gt, model, hook = rig(berFn=berFn)

    res = gt.EyeScan.probe(resetPolicy=ResetPolicy.Auto, probeWindow=WINDOW)

    assert res.status is ScanStatus.OK, res.message
    assert res.syncWarning == ''
    # Errors at +half are the transitions: the run at -half is not needed
    assert model.runs == 2


def test_an_edge_run_that_counts_no_samples_makes_the_probe_not_enabled(rig):
    gt, model, hook = rig()
    emptyAfterActivation(model)
    before = seedWords(model, gt)

    res = gt.EyeScan.probe(resetPolicy=ResetPolicy.Auto, probeWindow=WINDOW)

    assert res.status is ScanStatus.NOT_ENABLED, res.message
    assert 'eye edge' in res.message and 'count 64' in res.message
    assert model.getField(gt.ES_CONTROL) == 0
    assert seedWords(model, gt) == before


def test_a_static_lane_eye_is_closed_with_the_warning_and_its_data(rig):
    gt, model, hook = rig(berFn=static)
    before = seedWords(model, gt)

    res = gt.EyeScan.runEye(horzStep=16, vertStep=32, probeWindow=WINDOW)

    assert res.status is ScanStatus.CLOSED, res.message
    assert OUT_OF_STEP in res.message and LINK_DOWN in res.message
    assert any(OUT_OF_STEP in w and LINK_DOWN in w for w in res.meta['warnings'])
    assert res.bits.sum() > 0 and res.measured.all()
    assert res.centre is not None
    assert model.getField(gt.ES_CONTROL) == 0
    assert seedWords(model, gt) == before


def test_a_static_lane_margin_is_closed_with_the_warning_and_its_data(rig):
    gt, model, hook = rig(berFn=static)
    before = seedWords(model, gt)

    res = gt.EyeScan.runMargin(horzStep=16, vertStep=16, probeWindow=WINDOW)

    assert res.status is ScanStatus.CLOSED, res.message
    assert OUT_OF_STEP in res.message and LINK_DOWN in res.message
    assert any(OUT_OF_STEP in w and LINK_DOWN in w for w in res.meta['warnings'])
    assert res.eye.bits.sum() > 0
    assert res.horz is not None and res.vert is not None
    assert model.getField(gt.ES_CONTROL) == 0
    assert seedWords(model, gt) == before


# Grids that never land on both ends of the UI: a step that does not divide half, and a range below half
EYE_GRIDS = [dict(horzStep=3, vertStep=32), dict(horzStep=16, vertStep=32, horzRange=32)]
MARGIN_GRIDS = [dict(horzStep=3, vertStep=32), dict(horzStep=16, vertStep=16, horzRange=32)]


@pytest.mark.parametrize('step', [3, 5])
def test_a_static_lane_bathtub_is_closed_on_a_step_that_misses_the_ends(rig, step):
    gt, model, hook = rig(berFn=static)
    before = seedWords(model, gt)

    res = gt.EyeScan.runBathtub(step=step, floor=FLOOR, probeWindow=WINDOW)

    assert res.status is ScanStatus.CLOSED, res.message
    assert abs(int(res.horzCounts[-1])) < 64
    assert OUT_OF_STEP in res.message and LINK_DOWN in res.message
    warned = [w for w in res.meta['warnings'] if OUT_OF_STEP in w and LINK_DOWN in w]
    assert len(warned) == 1
    assert res.bits.sum() > 0 and res.errors.sum() == 0
    assert model.getField(gt.ES_CONTROL) == 0
    assert seedWords(model, gt) == before


@pytest.mark.parametrize('berFn', [gauss, None])
@pytest.mark.parametrize('step', [3, 5])
def test_a_healthy_bathtub_stays_ok_on_a_step_that_misses_the_ends(rig, step, berFn):
    gt, model, hook = rig(berFn=berFn)

    res = gt.EyeScan.runBathtub(step=step, floor=FLOOR, probeWindow=WINDOW)

    assert res.status is ScanStatus.OK, res.message
    assert OUT_OF_STEP not in res.message and LINK_DOWN not in res.message
    assert not any(OUT_OF_STEP in w or LINK_DOWN in w for w in res.meta['warnings'])


@pytest.mark.parametrize('grid', EYE_GRIDS)
def test_a_static_lane_eye_is_closed_on_a_grid_that_misses_the_ends(rig, grid):
    gt, model, hook = rig(berFn=static)
    before = seedWords(model, gt)

    res = gt.EyeScan.runEye(probeWindow=WINDOW, **grid)

    assert res.status is ScanStatus.CLOSED, res.message
    assert OUT_OF_STEP in res.message and LINK_DOWN in res.message
    assert any(OUT_OF_STEP in w and LINK_DOWN in w for w in res.meta['warnings'])
    assert res.measured.all() and res.bits.sum() > 0
    assert model.getField(gt.ES_CONTROL) == 0
    assert seedWords(model, gt) == before


@pytest.mark.parametrize('berFn', [gauss, None])
@pytest.mark.parametrize('grid', EYE_GRIDS)
def test_a_healthy_eye_stays_ok_on_a_grid_that_misses_the_ends(rig, grid, berFn):
    gt, model, hook = rig(berFn=berFn)

    res = gt.EyeScan.runEye(probeWindow=WINDOW, **grid)

    assert res.status is ScanStatus.OK, res.message
    assert OUT_OF_STEP not in res.message and LINK_DOWN not in res.message
    assert not any(OUT_OF_STEP in w or LINK_DOWN in w for w in res.meta['warnings'])


@pytest.mark.parametrize('grid', MARGIN_GRIDS)
def test_a_static_lane_margin_is_closed_on_a_grid_that_misses_the_ends(rig, grid):
    gt, model, hook = rig(berFn=static)
    before = seedWords(model, gt)

    res = gt.EyeScan.runMargin(probeWindow=WINDOW, **grid)

    assert res.status is ScanStatus.CLOSED, res.message
    assert OUT_OF_STEP in res.message and LINK_DOWN in res.message
    assert any(OUT_OF_STEP in w and LINK_DOWN in w for w in res.meta['warnings'])
    assert res.eye.bits.sum() > 0
    assert res.horz is not None and res.vert is not None
    assert model.getField(gt.ES_CONTROL) == 0
    assert seedWords(model, gt) == before


@pytest.mark.parametrize('berFn', [gauss, None])
@pytest.mark.parametrize('grid', MARGIN_GRIDS)
def test_a_healthy_margin_stays_ok_on_a_grid_that_misses_the_ends(rig, grid, berFn):
    gt, model, hook = rig(berFn=berFn)

    res = gt.EyeScan.runMargin(probeWindow=WINDOW, **grid)

    assert res.status is ScanStatus.OK, res.message
    assert OUT_OF_STEP not in res.message and LINK_DOWN not in res.message
    assert not any(OUT_OF_STEP in w or LINK_DOWN in w for w in res.meta['warnings'])


def test_a_scan_of_a_healthy_lane_runs_one_edge_run(rig):
    gt, model, hook = rig()

    res = gt.EyeScan.runBathtub(step=16, floor=FLOOR, probeWindow=WINDOW, lineRateGbps=6.25)

    assert res.status is ScanStatus.OK, res.message
    # Run 0 is the activation run at the eye centre; run 1 is the run at +half that finds the transitions
    assert model.runLog[0] == (0, 0, 0, 0)
    assert model.runLog[1] == (64, 0, 0, 0)
    assert model.runLog[2][0] == -64


def axisOf(counts, errors):
    """Axis, errors and bits of positions that each counted 1000 bits per UT sign."""
    axis = np.array(counts, dtype=np.int64)
    err = np.array([errors, errors], dtype=np.int64) // 2
    return axis, err, np.full((2, len(counts)), 1000, dtype=np.int64)


@pytest.mark.parametrize('counts, errors, half, silent', [
    ([-64, 0, 64], [0, 0, 0], 64, True),
    ([-64, 0, 64], [0, 0, 2], 64, False),
    ([-64, 0, 64], [2, 0, 0], 64, False),
    ([-32, 0, 32], [0, 0, 0], 64, False),
    ([-64, 0, 32], [0, 0, 0], 64, False),
    ([0], [0], 64, False),
    ([-64, 0, 64], [0, 0, 0], None, False),
])
def test_the_silent_ends_rule_needs_both_ends_measured_with_no_errors(counts, errors, half, silent):
    axis, err, bits = axisOf(counts, errors)

    assert EyeScanEngine._silentEnds(axis, err, bits, half) is silent


def test_the_silent_ends_rule_needs_bits_at_both_ends():
    axis, err, bits = axisOf([-64, 0, 64], [0, 0, 0])
    bits[:, -1] = 0

    assert EyeScanEngine._silentEnds(axis, err, bits, 64) is False


@pytest.mark.parametrize('endSamples', [2103, SAMPLE_MAX - 1])
def test_a_short_centre_run_is_reset_again_and_the_probe_is_closed(rig, endSamples):
    gt, model, hook = rig(berFn=None, endSamples=endSamples)

    res = gt.EyeScan.probe(resetPolicy=ResetPolicy.Auto, probeWindow=WINDOW)

    assert res.status is ScanStatus.CLOSED, res.message
    assert hook.pulses == SYNC_RESETS and res.resets == SYNC_RESETS
    assert OUT_OF_STEP in res.message and LINK_DOWN in res.message
    assert res.sampleCount == endSamples
    assert f'{endSamples} of {SAMPLE_MAX} samples' in res.syncWarning
    assert model.getField(gt.ES_CONTROL) == 0


def test_a_short_centre_run_under_never_closes_the_probe_at_once(rig):
    gt, model, hook = rig(berFn=None, endSamples=2103)
    warm(gt, model)

    res = gt.EyeScan.probe(resetPolicy=ResetPolicy.Never, probeWindow=WINDOW)

    assert res.status is ScanStatus.CLOSED, res.message
    assert hook.pulses == 0 and not res.resetCalled
    assert 0 < res.sampleCount < SAMPLE_MAX
    assert OUT_OF_STEP in res.message and LINK_DOWN in res.message


def test_a_full_centre_run_with_no_errors_stays_in_step(rig):
    gt, model, hook = rig(berFn=None, endSamples=SAMPLE_MAX)

    res = gt.EyeScan.probe(resetPolicy=ResetPolicy.Auto, probeWindow=WINDOW)

    assert res.status is ScanStatus.OK, res.message
    assert hook.pulses == 1


def test_a_short_run_bathtub_is_closed_with_the_warning_and_its_data(rig):
    gt, model, hook = rig(berFn=None, endSamples=2103)

    res = gt.EyeScan.runBathtub(step=16, floor=FLOOR, probeWindow=WINDOW)

    assert res.status is ScanStatus.CLOSED, res.message
    assert OUT_OF_STEP in res.message and LINK_DOWN in res.message
    assert any(OUT_OF_STEP in w and LINK_DOWN in w for w in res.meta['warnings'])
    assert len(res.horzCounts) > 0 and res.bits.sum() > 0
    assert hook.pulses == SYNC_RESETS


@pytest.mark.parametrize('falseCalls', [(), (1,)])
def test_empty_runs_during_a_bathtub_end_it_unlocked(rig, falseCalls):
    gt, model, hook = rig(falseCalls=falseCalls)
    emptyAfterActivation(model)
    before = seedWords(model, gt)

    res = gt.EyeScan.runBathtub(step=16, floor=FLOOR, probeWindow=WINDOW, lineRateGbps=6.25)

    assert res.status is ScanStatus.UNLOCKED, res.message
    assert res.linkDrops == 2
    assert model.getField(gt.ES_CONTROL) == 0
    assert seedWords(model, gt) == before


@pytest.mark.parametrize('falseCalls', [(), (1,)])
def test_empty_runs_during_a_margin_end_it_unlocked(rig, falseCalls):
    gt, model, hook = rig(falseCalls=falseCalls)
    emptyAfterActivation(model)
    before = seedWords(model, gt)

    res = gt.EyeScan.runMargin(horzStep=16, vertStep=16, probeWindow=WINDOW, lineRateGbps=6.25)

    assert res.status is ScanStatus.UNLOCKED, res.message
    assert res.linkDrops == 2
    assert model.getField(gt.ES_CONTROL) == 0
    assert seedWords(model, gt) == before


def test_an_empty_line_rate_run_ends_the_bathtub_unlocked(rig):
    gt, model, hook = rig()
    emptyAfterActivation(model)
    before = seedWords(model, gt)

    # No line rate is set, so one run measures it right after the activation
    res = gt.EyeScan.runBathtub(step=16, floor=FLOOR, probeWindow=WINDOW)

    assert res.status is ScanStatus.UNLOCKED, res.message
    assert len(res.horzCounts) == 0
    assert model.getField(gt.ES_CONTROL) == 0
    assert seedWords(model, gt) == before


def test_a_stuck_run_with_the_ready_signal_low_ends_the_bathtub_unlocked(rig):
    # ready() reads False after each of the two stuck runs
    gt, model, hook = rig(falseCalls=(2, 4))
    stickAfterActivation(model)

    res = gt.EyeScan.runBathtub(step=16, floor=FLOOR, probeWindow=WINDOW, maxTimePerRun=0.2, lineRateGbps=6.25)

    assert res.status is ScanStatus.UNLOCKED, res.message
    assert res.linkDrops == 2
    assert model.getField(gt.ES_CONTROL) == 0


def test_a_stuck_run_with_the_ready_signal_high_still_times_out(rig):
    gt, model, hook = rig()
    stickAfterActivation(model)

    res = gt.EyeScan.runBathtub(step=16, floor=FLOOR, probeWindow=WINDOW, maxTimePerRun=0.2, lineRateGbps=6.25)

    assert res.status is ScanStatus.TIMEOUT, res.message
    assert res.linkDrops == 0
    assert model.getField(gt.ES_CONTROL) == 0


def test_a_point_on_a_stuck_sampler_still_times_out(rig):
    gt, model, hook = rig(falseCalls=(1, 2, 3, 4))
    stickAfterActivation(model)

    with gt.EyeScan._scanning(None) as engine:
        res = engine.point(0, maxTimePerRun=0.2, probeWindow=WINDOW)

    assert res.status is ScanStatus.TIMEOUT, res.message
    assert model.getField(gt.ES_CONTROL) == 0


# Ready calls 1 and 2 bracket the first bathtub point, so call 3 is the drop seen before the second point
@pytest.mark.parametrize('scan', ['bathtub', 'eye', 'margin'])
def test_a_drop_that_leaves_the_sampler_out_of_step_ends_closed_with_the_warning(rig, scan):
    gt, model, hook = rig(falseCalls=(3,), desyncOnDrop=True)
    before = seedWords(model, gt)

    res = runScan(gt, scan)

    assert res.status is ScanStatus.CLOSED, res.message
    assert res.linkDrops == 1 and res.meta['linkDrops'] == 1
    assert 'after the link returned from a drop' in res.message
    assert OUT_OF_STEP in res.message and LINK_DOWN in res.message
    assert any(OUT_OF_STEP in w and LINK_DOWN in w for w in res.meta['warnings'])
    kept = res.eye if scan == 'margin' else res
    assert kept.bits.sum() > 0
    assert model.getField(gt.ES_CONTROL) == 0
    assert seedWords(model, gt) == before


@pytest.mark.parametrize('scan', ['bathtub', 'eye', 'margin'])
def test_a_drop_that_keeps_the_sampler_in_step_adds_no_warning(rig, scan):
    gt, model, hook = rig(falseCalls=(3,))

    res = runScan(gt, scan)

    assert res.status is ScanStatus.OK, res.message
    assert res.linkDrops == 1
    assert OUT_OF_STEP not in res.message and LINK_DOWN not in res.message
    assert not any(OUT_OF_STEP in w for w in res.meta['warnings'])


def runScan(gt, scan):
    if scan == 'bathtub':
        return gt.EyeScan.runBathtub(step=16, floor=FLOOR, probeWindow=WINDOW, lineRateGbps=6.25)
    if scan == 'eye':
        return gt.EyeScan.runEye(horzStep=16, vertStep=32, probeWindow=WINDOW, lineRateGbps=6.25)
    return gt.EyeScan.runMargin(horzStep=16, vertStep=32, probeWindow=WINDOW, lineRateGbps=6.25)
