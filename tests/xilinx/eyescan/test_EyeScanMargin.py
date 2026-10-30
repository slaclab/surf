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
# - Sweep: the eye-scan margin summary: the pure building blocks (4-connected
#   open component, open-area asymmetry, nearest-integer rounding toward zero,
#   BER text, result dataclasses) and the margin run of the GTHE3 eye scan (2D
#   eye, then a step-1 horizontal and vertical bathtub through the eye centre,
#   in one sampler activation) over an emulated GTHE3 DRP memory, with its npz
#   result files.
# - Stimulus: small hand-drawn open masks and closed-form values for the pure
#   section; real Rogue transactions against Gthe3EyeModel with seeded
#   separable eyes (horizontal dual-Dirac with sigma 0.035 UI and edges at
#   +-0.30 UI shifted by +4 counts, vertical Gaussian with edge 40 codes and
#   sigma 4 codes shifted by -6 codes), asymmetric variants, a constant-BER
#   closed eye and scripted abort sources for the emulated section.
# - Checks: a diagonal-only neighbour or an isolated open point is not part of
#   the component; asymmetry counts only points strictly off the centre lines
#   and gives None for an empty axis; exact halves round toward 0; a BER text
#   never states BER 0; the margin recovers the centre offset and both
#   openings at 1e-12 within stated tolerances from one RX reset, measures the
#   cross at the rounded centre with step 1, reports the open area as the
#   connected component, labels extrapolated, measured and clipped openings,
#   ends a closed eye and an abort during the cross in typed results with the
#   registers restored, and writes the margin and bathtub npz layouts.
# - Timing: the pure section is arithmetic; countReads=1 and a zero settle keep
#   the emulated runs short, and the model steps on status reads, so no test
#   waits on real hardware time. The full-range margin runs once per module.

import dataclasses
import json
import math

import pytest

pr = pytest.importorskip('pyrogue', reason='Eye-scan tests require Rogue/PyRogue')

import numpy as np  # noqa: E402
rogue = pytest.importorskip('rogue', reason='Eye-scan tests require Rogue/PyRogue')

import surf.xilinx.eyescan as es  # noqa: E402

from tests.xilinx.eyescan.gthe3_eye_model import makeGtRoot  # noqa: E402
from tests.xilinx.eyescan.test_EyeScanBathtub import Hook, seedWords, warmRig  # noqa: E402

# ----------------------------------------------------------------------------
# Pure pieces
# ----------------------------------------------------------------------------


def maskOf(*rows):
    """Boolean mask from drawn rows, '#' is open."""
    return np.array([[c == '#' for c in row] for row in rows])


def test_open_component_returns_an_l_shaped_region_whole():
    open_ = maskOf('#....',
                   '#....',
                   '###..')

    comp = es.openComponent(open_, 0, 0)

    assert comp.dtype == bool and comp.shape == open_.shape
    assert np.array_equal(comp, open_)


def test_open_component_keeps_diagonal_only_neighbours_separate():
    open_ = maskOf('#..',
                   '.#.',
                   '..#')

    comp = es.openComponent(open_, 0, 0)

    assert comp.sum() == 1 and comp[0, 0]


def test_open_component_excludes_an_isolated_open_point_away_from_the_seed():
    open_ = maskOf('##..#',
                   '.....')

    comp = es.openComponent(open_, 0, 0)

    assert comp.sum() == 2 and not comp[0, 4]


def test_open_component_never_includes_a_point_that_is_not_open():
    open_ = maskOf('#.##',
                   '####',
                   '.#..')

    comp = es.openComponent(open_, 1, 1)

    assert not (comp & ~open_).any()
    assert np.array_equal(comp, open_)


@pytest.mark.parametrize('seed', [(1, 0), (-1, 0), (0, -1), (3, 0), (0, 9)])
def test_open_component_of_a_seed_that_is_not_open_or_out_of_range_is_empty(seed):
    open_ = maskOf('#.#',
                   '.#.',
                   '#.#')

    comp = es.openComponent(open_, *seed)

    assert comp.shape == open_.shape and not comp.any()


def test_open_component_does_not_modify_its_input():
    open_ = maskOf('###', '#.#')
    before = open_.copy()

    es.openComponent(open_, 0, 0)

    assert np.array_equal(open_, before)


HORZ = np.array([-2, -1, 0, 1, 2])
VERT = np.array([-1, 0, 1])


def test_area_asymmetry_of_a_mirror_symmetric_component_is_zero():
    comp = np.ones((3, 5), dtype=bool)

    assert es.areaAsymmetry(comp, HORZ, VERT, 0.0, 0.0) == (0.0, 0.0)


def test_area_asymmetry_counts_six_points_right_against_two_left():
    comp = maskOf('.#.##',
                  '...##',
                  '.#.##')

    asymLR, asymTB = es.areaAsymmetry(comp, HORZ, VERT, 0.0, 0.0)

    assert int(comp[:, 3:].sum()) == 6 and int(comp[:, :2].sum()) == 2
    assert asymLR == pytest.approx(0.5)
    assert asymTB == pytest.approx(0.0)


def test_area_asymmetry_ignores_points_on_the_centre_lines():
    comp = maskOf('..#..',
                  '..###',
                  '..#..')

    asymLR, asymTB = es.areaAsymmetry(comp, HORZ, VERT, 0.0, 0.0)

    assert asymLR == pytest.approx(1.0)
    assert asymTB == pytest.approx(0.0)


def test_area_asymmetry_is_none_for_an_axis_without_points_off_the_centre_line():
    column = maskOf('..#..',
                    '..#..',
                    '..#..')
    single = maskOf('.....',
                    '..#..',
                    '.....')

    assert es.areaAsymmetry(column, HORZ, VERT, 0.0, 0.0) == (None, 0.0)
    assert es.areaAsymmetry(single, HORZ, VERT, 0.0, 0.0) == (None, None)


def test_area_asymmetry_is_measured_about_a_fractional_centre():
    comp = maskOf('.....',
                  '..###',
                  '.....')

    asymLR, asymTB = es.areaAsymmetry(comp, HORZ, VERT, 0.5, 0.0)

    assert asymLR == pytest.approx((2 - 1) / 3)
    assert asymTB is None


def test_area_asymmetry_is_signed_and_within_one_for_a_bottom_heavy_component():
    comp = maskOf('###..',
                  '.....',
                  '.....')

    asymLR, asymTB = es.areaAsymmetry(comp, HORZ, VERT, 0.0, 0.0)

    assert asymTB == pytest.approx(-1.0)
    assert -1.0 <= asymLR <= 1.0


@pytest.mark.parametrize('value, expected', [
    (2.5, 2), (-2.5, -2), (2.6, 3), (-2.6, -3), (0.5, 0), (-0.4, 0), (7.0, 7), (-0.5, 0), (3.5, 3),
])
def test_nearest_toward_zero_rounds_exact_halves_toward_zero(value, expected):
    out = es.nearestTowardZero(value)

    assert out == expected and isinstance(out, int)


def test_nearest_toward_zero_accepts_numpy_scalars():
    assert es.nearestTowardZero(np.float64(-4.5)) == -4
    assert es.nearestTowardZero(np.int64(9)) == 9


def test_format_ber_states_a_zero_error_point_as_an_upper_bound():
    assert es.formatBer(math.nan, 3.0e-10, True, 0.95) == 'BER < 3e-10 at 95%'
    assert es.formatBer(math.nan, 4.57e-9, True, 0.99) == 'BER < 4.6e-09 at 99%'


def test_format_ber_states_a_measured_value_and_a_missing_one():
    assert es.formatBer(4.1e-8, 4.6e-8, False, 0.95) == 'BER = 4.10e-08'
    assert es.formatBer(math.nan, math.nan, False, 0.95) == 'BER not measured'
    assert es.formatBer(math.nan, math.nan, True, 0.95) == 'BER not measured'


@pytest.mark.parametrize('ber, upper, bound', [
    (math.nan, 3e-10, True), (0.0, 3e-10, False), (0.0, 3e-10, True), (0.5, 0.5, False),
    (4.1e-8, 4.6e-8, False), (math.nan, math.nan, False), (1e-300, 1e-299, False),
])
def test_format_ber_never_states_ber_zero(ber, upper, bound):
    text = es.formatBer(ber, upper, bound, 0.95)

    assert 'BER = 0' not in text and 'BER=0' not in text


EYE_CENTRE_FIELDS = (
    'horz', 'vert', 'row', 'column', 'horzRun', 'vertRun', 'horzOpeningUI', 'vertOpeningCodes',
    'clippedH', 'clippedV', 'chordLeft', 'chordRight', 'chordBottom', 'chordTop', 'offsetUI', 'offsetCodes')
SWEEP_FIELDS = (
    'axis', 'positions', 'fixed', 'errors', 'bits', 'prescale', 'ber', 'berUpper', 'isBound', 'scale',
    'floor', 'lowFit', 'highFit', 'openingAtFloor', 'openingAtTarget', 'targetBer', 'extrapolated',
    'insufficientData', 'clipped', 'complete')
SUMMARY_FIELDS = (
    'status', 'eyeFloor', 'bathtubFloor', 'targetBer', 'confidence', 'centreHorzCounts', 'centreVertCodes',
    'offsetUI', 'offsetCodes', 'horzOpeningUI', 'horzOpeningSource', 'vertOpeningCodes', 'vertOpeningSource',
    'horzOpeningAtFloorUI', 'horzOpeningAtTargetUI', 'vertOpeningAtFloorCodes', 'vertOpeningAtTargetCodes',
    'openPoints', 'openAreaUiCodes', 'asymmetryLR', 'asymmetryTB', 'chordLeftCounts', 'chordRightCounts',
    'chordBottomCodes', 'chordTopCodes', 'clippedH', 'clippedV', 'extrapolatedH', 'extrapolatedV',
    'insufficientDataH', 'insufficientDataV', 'berAtCenter', 'berUpperAtCenter', 'isBoundAtCenter',
    'berAtCenterText', 'text')
MARGIN_FIELDS = ('eye', 'horz', 'vert', 'summary', 'status', 'message', 'activation', 'linkDrops', 'meta')


@pytest.mark.parametrize('name, fields', [
    ('EyeCentre', EYE_CENTRE_FIELDS),
    ('SweepResult', SWEEP_FIELDS),
    ('MarginSummary', SUMMARY_FIELDS),
    ('MarginResult', MARGIN_FIELDS),
])
def test_margin_dataclasses_carry_the_documented_fields(name, fields):
    cls = getattr(es, name)

    assert dataclasses.is_dataclass(cls)
    assert tuple(f.name for f in dataclasses.fields(cls)) == fields


def test_eye_result_built_without_a_centre_has_centre_none():
    zeros = np.zeros((1, 1))
    res = es.EyeResult(
        horzAxis=np.zeros(1, dtype=np.int64), vertAxis=np.zeros(1, dtype=np.int64),
        errors=np.zeros((2, 1, 1), dtype=np.int64), bits=np.zeros((2, 1, 1), dtype=np.int64),
        prescale=zeros, ber=zeros, berUpper=zeros, isBound=zeros.astype(bool), open=zeros.astype(bool),
        measured=zeros.astype(bool), uiPerCount=0.01, status=es.ScanStatus.OK, message='',
        activation=None, linkDrops=0, meta={})

    assert res.centre is None


# ----------------------------------------------------------------------------
# Emulated margin runs
# ----------------------------------------------------------------------------

HALF = 64
COUNTS_PER_UI = 2 * HALF
SIGMA = 0.035
EDGE = 0.30
V_SIGMA = 4.0
V_EDGE = 40.0
SHIFT_H = 4
SHIFT_V = -6
TARGET = 1e-12

EYE_KEYS = ('eye_horzAxis', 'eye_vertAxis', 'eye_errors', 'eye_bits', 'eye_prescale',
            'eye_ber', 'eye_berUpper', 'eye_isBound', 'eye_open', 'eye_measured')
SWEEP_SUFFIXES = ('axis', 'errors', 'bits', 'prescale', 'ber', 'berUpper', 'isBound')


def separable(horz, vert, *, shiftH=0, shiftV=0, edge=EDGE, vEdge=V_EDGE, sigma=SIGMA, vSigma=V_SIGMA):
    """BER of a separable eye: a dual-Dirac horizontal tail pair plus a Gaussian vertical tail pair."""
    x = (horz - shiftH) / COUNTS_PER_UI
    h = 0.5 * (es.qfunc((edge - x) / sigma) + es.qfunc((x + edge) / sigma))
    v = 0.5 * es.qfunc((vEdge - abs(vert - shiftV)) / vSigma)
    return min(0.5, h + v)


def shifted(horz, vert, ut):
    return separable(horz, vert, shiftH=SHIFT_H, shiftV=SHIFT_V)


def symmetric(horz, vert, ut):
    return separable(horz, vert)


def wideRight(horz, vert, ut):
    """The vertical edge is 10 codes larger for horizontal offsets above the centre."""
    return separable(horz, vert, vEdge=V_EDGE + (10.0 if horz > 0 else 0.0))


def wideTop(horz, vert, ut):
    """The horizontal edges are wider for vertical offsets above the centre."""
    return separable(horz, vert, edge=EDGE + (0.10 if vert > 0 else 0.0))


def sharp(horz, vert, ut):
    """Edges so steep that a step-1 tail holds fewer points than the fit needs."""
    return separable(horz, vert, sigma=0.002, vSigma=0.3)


def closed(horz, vert, ut):
    return 1e-3


def floored(horz, vert, ut):
    """The shifted eye with a BER floor of 1e-8: open at 1e-6, no position at or below 1e-9."""
    return max(1e-8, shifted(horz, vert, ut))


@pytest.fixture
def rigs():
    roots = []

    def make(eyeFn, **kw):
        rig = warmRig(None, eyeFn=eyeFn, **kw)
        roots.append(rig[0])
        return rig
    yield make
    for root in roots:
        root.stop()


class MarginRun:
    """One full-range margin of the shifted eye from a cold lane, with the state it left."""

    def __init__(self, result, gt, model, hook, before, folder, marks):
        self.result = result
        self.gt = gt
        self.model = model
        self.hook = hook
        self.before = before
        self.folder = folder
        self.marks = marks


@pytest.fixture(scope='module')
def run(tmp_path_factory):
    folder = tmp_path_factory.mktemp('margin')
    root, gt, model = makeGtRoot(requireReset=True, eyeFn=shifted, countReads=1)
    before = seedWords(model, gt)
    hook = Hook(model)
    gt.EyeScan.setRxReset(hook.pulse, hook.ready, settle=0.0, fallWait=0.05, timeout=0.5)
    marks = []
    control = es.ScanControl(onProgress=lambda done, total: marks.append((done, total, len(model.runLog))))
    try:
        result = gt.EyeScan.runMargin(horzStep=8, vertStep=8, vertRange=64, probeWindow=0.3,
                                      control=control, outDir=str(folder))
        yield MarginRun(result, gt, model, hook, before, folder, marks)
    finally:
        root.stop()


EYE_POINTS = 17 * 17
CROSS_POINTS = 129


def crossRuns(run):
    """Run-log entries of the horizontal and the vertical sweep (the probe and the eye are cut off)."""
    # One progress call per measured point: the nth call is the end of point n
    marks = {index + 1: count for index, (_, _, count) in enumerate(run.marks)}
    horzEnd = marks[EYE_POINTS + CROSS_POINTS]
    return (run.model.runLog[marks[EYE_POINTS]:horzEnd],
            run.model.runLog[horzEnd:marks[EYE_POINTS + 2 * CROSS_POINTS]])


def test_margin_recovers_the_centre_offset_and_both_openings_at_the_target_ber(run):
    res = run.result
    summary = res.summary
    horzTruth = 2.0 * (EDGE - SIGMA * es.qinv(2.0 * TARGET))
    vertTruth = 2.0 * (V_EDGE - V_SIGMA * es.qinv(2.0 * TARGET))

    assert isinstance(res, es.MarginResult)
    assert res.status is es.ScanStatus.OK, res.message
    assert summary.status is es.ScanStatus.OK
    assert abs(summary.centreHorzCounts - SHIFT_H) <= 8 and abs(summary.centreVertCodes - SHIFT_V) <= 8
    assert summary.offsetUI == pytest.approx(summary.centreHorzCounts / COUNTS_PER_UI)
    assert summary.offsetCodes == summary.centreVertCodes
    assert summary.horzOpeningAtTargetUI == pytest.approx(horzTruth, abs=0.01)
    assert summary.vertOpeningAtTargetCodes == pytest.approx(vertTruth, abs=2.0)
    assert summary.horzOpeningUI == summary.horzOpeningAtTargetUI
    assert summary.vertOpeningCodes == summary.vertOpeningAtTargetCodes
    assert summary.horzOpeningSource == summary.vertOpeningSource == 'extrapolated'
    assert summary.extrapolatedH and summary.extrapolatedV
    assert not summary.insufficientDataH and not summary.insufficientDataV
    assert not summary.clippedH and not summary.clippedV
    assert res.horz.lowFit.ok and res.horz.highFit.ok and res.vert.lowFit.ok and res.vert.highFit.ok
    assert res.horz.complete and res.vert.complete
    assert 'extrapolated' in summary.text and summary.text.startswith('OK')
    assert run.gt.EyeScan.Status.get() == 'OK'


def test_margin_is_one_sampler_activation_and_restores_the_registers(run):
    assert run.hook.pulses == 1
    assert run.model.resets == 1
    assert seedWords(run.model, run.gt) == run.before
    assert run.model.getField(run.gt.ES_CONTROL) == 0
    assert run.result.linkDrops == 0 and run.result.activation.status is es.ScanStatus.OK


def test_margin_cross_is_step_one_through_the_rounded_centre(run):
    centre = run.result.eye.centre
    rowVert = es.nearestTowardZero(centre.vert)
    colHorz = es.nearestTowardZero(centre.horz)
    horzRuns, vertRuns = crossRuns(run)

    assert run.result.meta['rowVert'] == rowVert and run.result.meta['columnHorz'] == colHorz
    assert run.result.meta['crossStep'] == 1
    assert {v for _, v, _, _ in horzRuns} == {rowVert}
    assert {h for h, _, _, _ in horzRuns} == set(range(-64, 65))
    assert {h for h, _, _, _ in vertRuns} == {colHorz}
    assert {v for _, v, _, _ in vertRuns} == set(range(-64, 65))
    assert run.result.horz.positions.tolist() == list(range(-64, 65)) and run.result.horz.fixed == rowVert
    assert run.result.vert.positions.tolist() == list(range(-64, 65)) and run.result.vert.fixed == colHorz
    assert run.model.negativeZero == 0


def test_margin_eye_centre_follows_the_open_run_midpoints(run):
    eye = run.result.eye
    centre = eye.centre
    row0 = int(np.flatnonzero(eye.vertAxis == 0)[0])
    cols = np.flatnonzero(eye.open[row0])
    first, last = centre.horzRun

    assert (first, last) == (int(cols[0]), int(cols[-1]))
    assert centre.horz == (eye.horzAxis[first] + eye.horzAxis[last]) / 2.0
    assert eye.horzAxis[centre.column] == min(eye.horzAxis, key=lambda c: (abs(c - centre.horz), abs(c)))
    rows = np.flatnonzero(eye.open[:, centre.column])
    assert centre.vertRun == (int(rows[0]), int(rows[-1]))
    assert centre.vert == (eye.vertAxis[centre.vertRun[0]] + eye.vertAxis[centre.vertRun[1]]) / 2.0
    assert eye.open[centre.row, centre.column]
    assert centre.offsetUI == pytest.approx(centre.horz * eye.uiPerCount) and centre.offsetCodes == centre.vert
    assert centre.horzOpeningUI == pytest.approx((eye.horzAxis[last] - eye.horzAxis[first]) * eye.uiPerCount)
    assert min(centre.chordLeft, centre.chordRight, centre.chordBottom, centre.chordTop) >= 0.0


def bfsCount(open_, row, col):
    """Independent breadth-first count of the 4-connected open component."""
    seen = {(row, col)}
    queue = [(row, col)]
    while queue:
        r, c = queue.pop(0)
        for nr, nc in ((r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)):
            if 0 <= nr < open_.shape[0] and 0 <= nc < open_.shape[1] and open_[nr, nc] and (nr, nc) not in seen:
                seen.add((nr, nc))
                queue.append((nr, nc))
    return len(seen)


def test_margin_open_area_is_the_connected_component_from_the_centre(run):
    eye = run.result.eye
    summary = run.result.summary

    count = bfsCount(eye.open, eye.centre.row, eye.centre.column)

    assert summary.openPoints == count and count > 1
    assert summary.openAreaUiCodes == pytest.approx(count * 8 * 8 * eye.uiPerCount)
    assert summary.chordLeftCounts == eye.centre.chordLeft and summary.chordTopCodes == eye.centre.chordTop


def test_margin_centre_point_is_zero_error_and_is_never_stated_as_ber_zero(run):
    res = run.result
    summary = res.summary

    assert summary.isBoundAtCenter is True and summary.berAtCenter is None
    assert summary.berUpperAtCenter is not None and summary.berUpperAtCenter <= 1e-9
    assert summary.berAtCenterText.startswith('BER < ') and summary.berAtCenterText.endswith('at 95%')
    assert summary.berAtCenterText in summary.text
    for text in (summary.text, summary.berAtCenterText):
        assert 'BER = 0' not in text and 'BER=0' not in text
    for sweep in (res.horz, res.vert):
        assert not np.any(sweep.ber == 0)
        assert np.all(np.isnan(sweep.ber[sweep.isBound]))


def test_margin_npz_holds_the_eye_and_both_sweeps_with_the_meta_blocks(run):
    path = run.gt.EyeScan.ResultFile.get()
    res = run.result

    arrays, meta = es.loadResult(path)

    expected = set(EYE_KEYS) | {f'{p}_{s}' for p in ('horz', 'vert') for s in SWEEP_SUFFIXES}
    assert sorted(arrays) == sorted(expected)
    stem = path.rsplit('/', 1)[1][:-4]
    assert sorted(run.folder.iterdir()) == [
        run.folder / (stem + ext) for ext in ('.csv', '.npz', '_bathtub.png', '_eye.png')]
    assert path.endswith('_margin.npz')
    assert np.array_equal(arrays['horz_axis'], res.horz.positions)
    assert np.array_equal(arrays['vert_errors'], res.vert.errors) and arrays['vert_errors'].dtype == np.int64
    assert np.array_equal(arrays['horz_bits'], res.horz.bits)
    assert np.array_equal(arrays['vert_ber'], res.vert.ber, equal_nan=True)
    assert np.array_equal(arrays['eye_open'], res.eye.open)
    assert meta['kind'] == 'margin' and meta['status'] == 'OK'
    assert meta['summary']['horzOpeningSource'] == 'extrapolated'
    assert meta['summary']['vertOpeningAtTargetCodes'] == res.summary.vertOpeningAtTargetCodes
    assert meta['summary']['berAtCenterText'] == res.summary.berAtCenterText
    for axis in ('horz', 'vert'):
        for side in ('left', 'right'):
            assert meta['fits'][axis][side]['ok'] is True
    assert meta['centre']['row'] == res.eye.centre.row and meta['centre']['horzRun'] == list(res.eye.centre.horzRun)
    assert meta['engine']['bathtubFloor'] == 1e-9 and meta['engine']['targetBer'] == TARGET
    assert 'RX reset' in meta['engine']['note']
    json.dumps(meta, allow_nan=False)


def test_margin_progress_runs_over_all_three_stages(run):
    dones = [done for done, _, _ in run.marks]
    totals = {total for _, total, _ in run.marks}

    assert len(dones) == EYE_POINTS + 2 * CROSS_POINTS
    assert dones == sorted(set(dones)) and totals == {dones[-1]}


def margin(rigs, eyeFn, **kw):
    root, gt, model, hook = rigs(eyeFn)
    before = seedWords(model, gt)
    kw.setdefault('horzStep', 8)
    kw.setdefault('vertStep', 8)
    kw.setdefault('horzRange', 32)
    kw.setdefault('vertRange', 48)
    kw.setdefault('bathtubFloor', 1e-6)
    return gt, model, hook, before, kw


def test_symmetric_eye_has_no_asymmetry_and_equal_chords(rigs):
    gt, model, hook, before, kw = margin(rigs, symmetric, horzStep=4, vertStep=4)

    res = gt.EyeScan.runMargin(**kw)

    summary = res.summary
    assert res.status is es.ScanStatus.OK, res.message
    assert summary.openPoints > 60
    assert abs(summary.asymmetryLR) < 0.05 and abs(summary.asymmetryTB) < 0.05
    assert abs(summary.chordLeftCounts - summary.chordRightCounts) <= 4
    assert abs(summary.chordBottomCodes - summary.chordTopCodes) <= 4
    assert hook.pulses == 1 and model.resets == 1


def test_a_wider_vertical_edge_above_the_centre_column_gives_positive_left_right_asymmetry(rigs):
    gt, model, hook, before, kw = margin(rigs, wideRight)

    res = gt.EyeScan.runMargin(**kw)

    assert res.status is es.ScanStatus.OK, res.message
    assert res.summary.asymmetryLR > 0.05
    assert -1.0 <= res.summary.asymmetryLR <= 1.0


def test_wider_horizontal_edges_above_the_centre_row_give_positive_top_bottom_asymmetry(rigs):
    gt, model, hook, before, kw = margin(rigs, wideTop, horzStep=4)

    res = gt.EyeScan.runMargin(**kw)

    assert res.status is es.ScanStatus.OK, res.message
    assert res.summary.asymmetryTB > 0.05
    assert -1.0 <= res.summary.asymmetryTB <= 1.0


def test_a_clipped_vertical_run_is_a_lower_bound_never_an_extrapolated_opening(rigs):
    gt, model, hook, before, kw = margin(rigs, symmetric, vertStep=4, vertRange=12, bathtubFloor=1e-9)

    res = gt.EyeScan.runMargin(**kw)

    summary = res.summary
    assert res.status is es.ScanStatus.OK, res.message
    assert res.vert.clipped and summary.clippedV
    assert summary.insufficientDataV and not summary.extrapolatedV
    assert summary.vertOpeningSource == 'measured'
    assert summary.vertOpeningCodes == summary.vertOpeningAtFloorCodes == 24.0
    assert summary.vertOpeningAtTargetCodes is None
    assert '>=' in summary.text and 'lower bound' in summary.text


def test_failed_fits_give_insufficient_data_and_the_measured_opening(rigs):
    gt, model, hook, before, kw = margin(rigs, sharp, horzRange=64, vertRange=64)

    res = gt.EyeScan.runMargin(**kw)

    summary = res.summary
    assert res.status is es.ScanStatus.OK, res.message
    assert not res.horz.lowFit.ok and not res.horz.highFit.ok and not res.vert.lowFit.ok and not res.vert.highFit.ok
    assert not summary.clippedH and not summary.clippedV
    for opening, atFloor, atTarget, source, insufficient, extrapolated in (
            (summary.horzOpeningUI, summary.horzOpeningAtFloorUI, summary.horzOpeningAtTargetUI,
             summary.horzOpeningSource, summary.insufficientDataH, summary.extrapolatedH),
            (summary.vertOpeningCodes, summary.vertOpeningAtFloorCodes, summary.vertOpeningAtTargetCodes,
             summary.vertOpeningSource, summary.insufficientDataV, summary.extrapolatedV)):
        assert source == 'measured' and insufficient and not extrapolated
        assert atTarget is None and opening == atFloor and opening > 0
    assert 'extrapolated' not in summary.text and 'insufficient data' in summary.text


def test_a_completed_cross_with_no_position_at_the_bathtub_floor_is_closed(rigs):
    gt, model, hook, before, kw = margin(rigs, floored, bathtubFloor=1e-9)

    res = gt.EyeScan.runMargin(**kw)

    summary = res.summary
    assert res.status is es.ScanStatus.OK, res.message
    assert res.horz.complete and res.vert.complete
    assert res.horz.openingAtFloor is None and res.vert.openingAtFloor is None
    assert summary.horzOpeningSource == 'closed' and summary.vertOpeningSource == 'closed'
    assert summary.horzOpeningUI is None and summary.vertOpeningCodes is None
    assert not summary.insufficientDataH and not summary.insufficientDataV
    assert not summary.extrapolatedH and not summary.extrapolatedV
    assert 'horizontal opening none (no position meets BER 1e-09)' in summary.text
    assert 'vertical opening none (no position meets BER 1e-09)' in summary.text
    assert 'insufficient data' not in summary.text


def test_the_closed_label_reaches_the_npz_meta_and_leaves_the_csv_columns_unchanged(rigs, tmp_path):
    gt, model, hook, before, kw = margin(rigs, floored, bathtubFloor=1e-9)
    res = gt.EyeScan.runMargin(**kw)

    outcome = gt.EyeScan.save(res, str(tmp_path), png=False)

    assert outcome.errors == []
    arrays, meta = es.loadResult(outcome.npzPath)
    assert meta['summary']['horzOpeningSource'] == 'closed' and meta['summary']['vertOpeningSource'] == 'closed'
    assert 'none (no position meets BER 1e-09)' in meta['summary']['text']
    assert set(arrays) | {'meta'} == set(es.NPZ_KEYS['margin'])
    with open(outcome.csvPath) as handle:
        assert handle.readline().rstrip('\n') == ','.join(es.CSV_COLUMNS)


def test_an_analysis_failure_of_a_margin_returns_error_with_the_eye_counts(rigs, monkeypatch, tmp_path):
    gt, model, hook, before, kw = margin(rigs, shifted)

    def failing(*args, **kwargs):
        raise RuntimeError('injected analysis failure')

    monkeypatch.setattr('surf.xilinx.eyescan._EyeScanEngine.openRegion', failing)

    res = gt.EyeScan.runMargin(**kw)

    assert res.status is es.ScanStatus.ERROR and res.summary.status is es.ScanStatus.ERROR
    assert 'RuntimeError' in res.message and 'RuntimeError' in res.summary.text
    assert res.eye.status is es.ScanStatus.ERROR and res.eye.centre is None
    assert res.eye.bits.sum() > 0 and res.eye.errors.sum() > 0 and res.eye.measured.any()
    assert np.isnan(res.eye.ber).all() and not res.eye.open.any()
    assert res.summary.horzOpeningSource is None and res.summary.horzOpeningUI is None
    outcome = gt.EyeScan.save(res, str(tmp_path), png=False)
    assert outcome.errors == []
    assert sorted(path.suffix for path in tmp_path.iterdir()) == ['.csv', '.npz']
    arrays, meta = es.loadResult(outcome.npzPath)
    assert set(arrays) | {'meta'} == set(es.NPZ_KEYS['margin'])
    assert arrays['eye_bits'].sum() == res.eye.bits.sum()


def test_an_analysis_failure_after_the_cross_keeps_the_eye_and_the_cross_counts(rigs, monkeypatch, tmp_path):
    gt, model, hook, before, kw = margin(rigs, shifted)

    def failing(*args, **kwargs):
        raise RuntimeError('injected analysis failure')

    monkeypatch.setattr('surf.xilinx.eyescan._EyeScanEngine.fitTail', failing)

    res = gt.EyeScan.runMargin(**kw)

    assert res.status is es.ScanStatus.ERROR and 'RuntimeError' in res.message
    assert res.eye.centre is not None and res.eye.bits.sum() > 0
    assert res.horz is not None and res.vert is not None
    assert res.horz.bits.sum() > 0 and res.vert.bits.sum() > 0
    assert not res.horz.complete and not res.vert.complete
    assert res.summary.centreHorzCounts is None and res.summary.status is es.ScanStatus.ERROR
    outcome = gt.EyeScan.save(res, str(tmp_path), png=False)
    assert outcome.errors == [] and outcome.csvPath != ''


def test_closed_eye_stops_before_the_cross_and_has_no_openings(rigs):
    root, gt, model, hook = rigs(closed)

    res = gt.EyeScan.runMargin(horzStep=16, vertStep=32)

    summary = res.summary
    assert res.status is es.ScanStatus.CLOSED and summary.status is es.ScanStatus.CLOSED
    assert res.horz is None and res.vert is None and res.eye.centre is None
    assert summary.horzOpeningUI is None and summary.vertOpeningCodes is None
    assert summary.horzOpeningSource is None and summary.vertOpeningSource is None
    assert summary.insufficientDataH and summary.insufficientDataV
    assert not summary.extrapolatedH and not summary.extrapolatedV
    assert summary.openPoints is None and summary.asymmetryLR is None and summary.berAtCenterText == 'BER not measured'
    assert summary.text.startswith('CLOSED')
    grid = {(int(h), int(v)) for h in res.eye.horzAxis for v in res.eye.vertAxis}
    assert {(h, v) for h, v, _, _ in model.runLog} == grid
    assert hook.pulses == 1 and gt.EyeScan.Status.get() == 'CLOSED'


@pytest.mark.parametrize('stage, atDone', [('horizontal', 81 + 10), ('vertical', 81 + 65 + 10)])
def test_abort_during_the_cross_keeps_the_eye_and_marks_the_sweep_incomplete(rigs, stage, atDone):
    gt, model, hook, before, kw = margin(rigs, symmetric, vertRange=32)
    calls = []

    def abortAtPoint(done, total):
        calls.append(done)
        if len(calls) == atDone:
            control.abort()

    control = es.ScanControl(onProgress=abortAtPoint)

    res = gt.EyeScan.runMargin(control=control, **kw)

    summary = res.summary
    assert res.status is es.ScanStatus.ABORTED and summary.status is es.ScanStatus.ABORTED
    assert res.eye.centre is not None and res.eye.status is es.ScanStatus.OK
    assert summary.openPoints > 1 and summary.asymmetryLR is not None and summary.asymmetryTB is not None
    assert summary.centreHorzCounts is not None and summary.openAreaUiCodes > 0
    if stage == 'horizontal':
        assert res.horz.complete is False and res.vert is None
        assert summary.horzOpeningUI is None and summary.vertOpeningCodes is None
    else:
        assert res.horz.complete is True and res.vert.complete is False
        assert summary.vertOpeningCodes is None and summary.vertOpeningSource is None
        assert res.vert.openingAtFloor is None and res.vert.lowFit is None
        assert summary.horzOpeningUI is not None
    assert summary.insufficientDataV and not summary.extrapolatedV
    assert model.getField(gt.ES_CONTROL) == 0
    assert seedWords(model, gt) == before
    assert gt.EyeScan.Status.get() == 'ABORTED'


def test_abort_during_the_eye_gives_no_centre_and_no_cross(rigs):
    gt, model, hook, before, kw = margin(rigs, symmetric, vertRange=32)
    calls = []

    def abortAtPoint(done, total):
        calls.append(done)
        if len(calls) == 40:
            control.abort()

    control = es.ScanControl(onProgress=abortAtPoint)

    res = gt.EyeScan.runMargin(control=control, **kw)

    summary = res.summary
    assert res.status is es.ScanStatus.ABORTED and res.eye.status is es.ScanStatus.ABORTED
    assert res.eye.centre is None and res.horz is None and res.vert is None
    assert summary.centreHorzCounts is None and summary.openPoints is None and summary.asymmetryLR is None
    assert summary.horzOpeningUI is None and summary.vertOpeningCodes is None
    assert summary.insufficientDataH and summary.insufficientDataV
    assert summary.text.startswith('ABORTED')
    assert seedWords(model, gt) == before


def test_a_centre_point_with_errors_is_stated_as_a_measured_ber(rigs):
    gt, model, hook, before, kw = margin(rigs, lambda horz, vert, ut: 1e-5, floor=1e-3, bathtubFloor=1e-3,
                                         horzStep=16, vertStep=32, horzRange=64, vertRange=96)

    res = gt.EyeScan.runMargin(**kw)

    summary = res.summary
    assert res.status is es.ScanStatus.OK, res.message
    assert summary.isBoundAtCenter is False
    assert summary.berAtCenter == pytest.approx(1e-5, rel=0.3)
    assert summary.berAtCenterText == f'BER = {summary.berAtCenter:.2e}'
    assert 'BER < ' not in summary.berAtCenterText and summary.berAtCenterText in summary.text


@pytest.mark.parametrize('kwargs', [
    {'bathtubFloor': 0.0}, {'bathtubFloor': 1}, {'targetBer': 0.0}, {'targetBer': 1.0},
    {'floor': 1}, {'confidence': 1.0}, {'equalizer': 'xyz'}, {'fixedPrescale': 32}, {'maxTimePerRun': 0.0},
    {'horzStep': 0}, {'vertStep': 17, 'vertRange': 16}, {'horzRange': 65}, {'vertRange': 128}, {'horzStep': 8, 'horzRange': 4},
])
def test_invalid_margin_arguments_are_refused_before_any_write(rigs, kwargs):
    root, gt, model, hook = rigs(closed)
    writes = len(model.writes)

    with pytest.raises(ValueError):
        gt.EyeScan.runMargin(**kwargs)

    assert len(model.writes) == writes


def test_a_synchronous_margin_without_an_output_folder_writes_nothing(rigs, tmp_path):
    gt, model, hook, before, kw = margin(rigs, symmetric, horzRange=16, vertRange=16)
    gt.EyeScan.OutputDir.set(str(tmp_path))

    res = gt.EyeScan.runMargin(**kw)

    assert res.status is es.ScanStatus.OK, res.message
    assert list(tmp_path.iterdir()) == []
    assert gt.EyeScan.ResultFile.get() == ''
    assert gt.EyeScan.lastResult is res


def test_bathtub_with_an_output_folder_writes_the_horizontal_arrays(rigs, tmp_path):
    root, gt, model, hook = rigs(shifted)

    res = gt.EyeScan.runBathtub(step=8, floor=1e-6, outDir=str(tmp_path))

    path = gt.EyeScan.ResultFile.get()
    arrays, meta = es.loadResult(path)
    assert path.endswith('_bathtub.npz')
    stem = path.rsplit('/', 1)[1][:-4]
    assert sorted(tmp_path.iterdir()) == [tmp_path / (stem + ext) for ext in ('.csv', '.npz', '_bathtub.png')]
    assert sorted(arrays) == sorted(f'horz_{s}' for s in SWEEP_SUFFIXES)
    assert np.array_equal(arrays['horz_axis'], res.horzCounts)
    assert np.array_equal(arrays['horz_errors'], res.errors) and arrays['horz_errors'].dtype == np.int64
    assert np.array_equal(arrays['horz_ber'], res.ber, equal_nan=True)
    assert meta['kind'] == 'bathtub' and meta['status'] == res.status.value
    assert meta['fits']['horz']['left']['side'] == 'left' and meta['fits']['horz']['right']['side'] == 'right'
    assert meta['bathtub']['targetBer'] == res.targetBer
    assert meta['bathtub']['extrapolated'] is res.extrapolated
    assert {'vsRange', 'timestamp', 'stamp'} <= set(meta['engine'])
    assert res.meta['stamp'] in path


def test_a_synchronous_bathtub_without_an_output_folder_writes_nothing(rigs, tmp_path):
    root, gt, model, hook = rigs(shifted)
    gt.EyeScan.OutputDir.set(str(tmp_path))

    res = gt.EyeScan.runBathtub(step=16, floor=1e-6)

    assert res.status in (es.ScanStatus.OK, es.ScanStatus.CLOSED)
    assert list(tmp_path.iterdir()) == [] and gt.EyeScan.ResultFile.get() == ''
    assert res.meta['vsRange'] is not None and res.meta['stamp'] and res.meta['timestamp']


def test_a_closed_eye_has_no_centre_and_its_file_says_so(rigs, tmp_path):
    root, gt, model, hook = rigs(closed)

    res = gt.EyeScan.runEye(horzStep=16, vertStep=32, outDir=str(tmp_path))

    _, meta = es.loadResult(gt.EyeScan.ResultFile.get())
    assert res.centre is None and meta['centre'] is None and meta['kind'] == 'eye'


def test_eye_centre_is_stored_on_a_completed_eye_and_in_its_file(rigs, tmp_path):
    root, gt, model, hook = rigs(shifted)

    res = gt.EyeScan.runEye(horzStep=8, vertStep=8, vertRange=48, outDir=str(tmp_path))

    _, meta = es.loadResult(gt.EyeScan.ResultFile.get())
    assert res.status is es.ScanStatus.OK and isinstance(res.centre, es.EyeCentre)
    assert meta['centre']['horz'] == res.centre.horz and meta['centre']['vertRun'] == list(res.centre.vertRun)
