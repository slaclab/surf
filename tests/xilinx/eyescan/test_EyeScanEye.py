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
# - Sweep: the 2D statistical eye of the GTHE3 eye scan (grid construction,
#   signed vertical offsets, centre-out row order, one sampler activation per
#   eye, typed CLOSED, ABORTED, UNLOCKED and NOT_ENABLED results) and its npz
#   result file, over an emulated GTHE3 DRP memory.
# - Stimulus: real Rogue transactions against Gthe3EyeModel with a seeded
#   separable eye (horizontal dual-Dirac with sigma 0.035 UI and edges at
#   +-0.30 UI, vertical Gaussian edge at 80 codes with sigma 8 codes), a
#   constant-BER closed eye, and scripted ready, abort and link-drop sources.
# - Checks: runEye returns an EyeResult whose arrays are shaped (nV, nH) with
#   int64 counts and writes one npz that loads without pickle; the default
#   grid is 65 by 63 points, every step and range edge case gives the stated
#   axes, invalid arguments are refused before any bus access, vertical
#   offsets are written as magnitude plus direction, rows run centre-out, the
#   shared DRP word keeps VS_RANGE and its neighbour bits, an open point is
#   one whose upper bound is at or below the floor, every end state restores
#   the registers, and counts and meta numbers survive the npz exactly.
# - Timing: countReads=1 and a zero settle keep the emulated runs short; the
#   model steps on status reads, so no test waits on real hardware time. Only
#   the default-grid fixture runs the full 4095 points.

import itertools
import json
import os
from datetime import datetime
from types import SimpleNamespace

import pytest

pr = pytest.importorskip('pyrogue', reason='Eye-scan tests require Rogue/PyRogue')

import numpy as np  # noqa: E402
rogue = pytest.importorskip('rogue', reason='Eye-scan tests require Rogue/PyRogue')

import surf.xilinx as xil  # noqa: E402
import surf.xilinx.eyescan as es  # noqa: E402

from tests.xilinx.eyescan.gthe3_eye_model import fieldOf, makeGtRoot  # noqa: E402
from tests.xilinx.eyescan.test_EyeScanBathtub import Hook, seedWords, warmRig  # noqa: E402

SIGMA = 0.035
EDGE = 0.30
HALF = 64
V_EDGE = 80.0
V_SIGMA = 8.0
FLOOR = 1e-6

ARRAY_KEYS = ('eye_horzAxis', 'eye_vertAxis', 'eye_errors', 'eye_bits', 'eye_prescale',
              'eye_ber', 'eye_berUpper', 'eye_isBound', 'eye_open', 'eye_measured')


def eye2d(horz, vert, ut):
    """Separable BER of the seeded eye: horizontal dual-Dirac plus a vertical Gaussian."""
    x = horz / (2.0 * HALF)
    h = 0.5 * (es.qfunc((EDGE - x) / SIGMA) + es.qfunc((x + EDGE) / SIGMA))
    v = es.qfunc((V_EDGE - abs(vert)) / V_SIGMA)
    return min(0.5, h + v)


def closed(horz, vert, ut):
    return 1e-3


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


class FullRun:
    """One default-grid eye of the seeded eye from a cold lane, with the model state it left."""

    def __init__(self, result, gt, model, hook, before, folder):
        self.result = result
        self.gt = gt
        self.model = model
        self.hook = hook
        self.before = before
        self.folder = folder


@pytest.fixture(scope='module')
def full(tmp_path_factory):
    folder = tmp_path_factory.mktemp('eye')
    root, gt, model = makeGtRoot(requireReset=True, eyeFn=eye2d, countReads=1)
    before = seedWords(model, gt)
    hook = Hook(model)
    gt.EyeScan.setRxReset(hook.pulse, hook.ready, settle=0.0, fallWait=0.05, timeout=0.5)
    # A defined rate keeps the run log to the probe and the grid points
    gt.EyeScan.LineRateGbps.set(6.25)
    try:
        result = gt.EyeScan.runEye(probeWindow=0.3, outDir=str(folder))
        yield FullRun(result, gt, model, hook, before, folder)
    finally:
        root.stop()


def test_run_eye_returns_an_eye_result_and_writes_an_npz(tmp_path):
    root, gt, model = makeGtRoot(requireReset=True, eyeFn=eye2d, countReads=1)
    try:
        hook = Hook(model)
        gt.EyeScan.setRxReset(hook.pulse, hook.ready, settle=0.0, fallWait=0.05, timeout=0.5)

        res = gt.EyeScan.runEye(floor=1e-6, horzStep=8, vertStep=16, outDir=str(tmp_path))

        assert isinstance(res, es.EyeResult)
        assert res.status is es.ScanStatus.OK, res.message
        assert res.errors.shape == (2, 15, 17) and res.errors.dtype == np.int64
        assert res.bits.shape == (2, 15, 17) and res.bits.dtype == np.int64
        assert res.ber.shape == res.berUpper.shape == res.open.shape == res.measured.shape == (15, 17)
        assert hook.pulses == 1

        path = gt.EyeScan.ResultFile.get()
        assert path.endswith('.npz') and str(tmp_path) in path
        with np.load(path, allow_pickle=False) as data:
            for key in ARRAY_KEYS + ('meta',):
                assert key in data.files, key
            meta = json.loads(str(data['meta']))
            assert meta['kind'] == 'eye'
            assert np.array_equal(data['eye_errors'], res.errors)
            assert np.array_equal(data['eye_bits'], res.bits)
    finally:
        root.stop()


def test_default_grid_is_65_columns_by_63_rows_all_measured(full):
    res = full.result

    assert res.status is es.ScanStatus.OK, res.message
    assert np.array_equal(res.horzAxis, np.arange(-64, 65, 2))
    assert np.array_equal(res.vertAxis, np.arange(-124, 125, 4))
    assert res.errors.shape == (2, 63, 65) and res.bits.shape == (2, 63, 65)
    assert res.measured.shape == (63, 65) and bool(res.measured.all())
    assert res.measured.size == 4095
    meta = res.meta
    assert meta['floor'] == 1e-6 and meta['horzStep'] == 2 and meta['vertStep'] == 4
    assert meta['pointsTotal'] == 4095 and meta['pointsMeasured'] == 4095
    assert meta['rxOutDiv'] == 2 and meta['horzHalfRange'] == HALF and meta['vsCodeMax'] == 127
    assert res.uiPerCount == pytest.approx(1.0 / (2 * HALF))


def test_one_run_eye_is_one_sampler_activation(full):
    assert full.hook.pulses == 1
    assert full.model.resets == 1


def test_gaussian_eye_is_open_in_the_centre_and_closed_in_the_corners(full):
    res = full.result
    row = int(np.flatnonzero(res.vertAxis == 0)[0])
    col = int(np.flatnonzero(res.horzAxis == 0)[0])

    assert res.open[row, col]
    for r in (0, -1):
        for c in (0, -1):
            assert not res.open[r, c]
    assert not np.any(res.ber == 0)
    assert np.all(np.isnan(res.ber[res.isBound]))
    assert res.isBound.any()
    assert full.model.phaseViolations == 0


def test_open_is_measured_and_upper_bound_at_or_below_the_floor(full):
    res = full.result

    assert np.array_equal(res.open, res.measured & (res.berUpper <= res.meta['floor']))
    assert res.open.any() and not res.open.all()


def test_vertical_offsets_are_written_as_magnitude_and_direction(full):
    model = full.model
    runs = model.runLog[1:]

    assert model.negativeZero == 0
    assert {v for _, v, _, _ in runs} == set(full.result.vertAxis.tolist())
    for i, (horz, vert, ut, prescale) in enumerate(runs):
        if ut == 1:
            assert runs[i - 1] == (horz, vert, 0, prescale)


def test_rows_run_centre_out_and_columns_ascend(full):
    # Run 0 is the activation probe and run 1 is the run at +half that finds the data transitions
    assert full.model.runLog[1] == (64, 0, 0, 0)
    runs = full.model.runLog[2:]
    expected = [0] + [sign * 4 * k for k in range(1, 32) for sign in (-1, 1)]

    assert [v for v, _ in itertools.groupby(vert for _, vert, _, _ in runs)] == expected
    for vert, group in itertools.groupby(runs, key=lambda run: run[1]):
        horz = [run[0] for run in group]
        assert np.all(np.diff(horz) >= 0)
        assert sorted(set(horz)) == full.result.horzAxis.tolist()


def test_shared_word_keeps_vs_range_and_neighbour_bits_on_every_write(full):
    gt, model = full.gt, full.model
    word = fieldOf(gt.RX_EYESCAN_VS_UT_SIGN)[0]
    moved = 0
    for var in (gt.RX_EYESCAN_VS_CODE, gt.RX_EYESCAN_VS_NEG_DIR, gt.RX_EYESCAN_VS_UT_SIGN):
        _, lsb, width = fieldOf(var)
        moved |= ((1 << width) - 1) << lsb
    keep = 0xFFFF & ~moved
    seed = full.before[word]
    _, lsb, width = fieldOf(gt.RX_EYESCAN_VS_RANGE)
    seedRange = (seed >> lsb) & ((1 << width) - 1)

    writes = [value for addr, value in model.writes if addr == word]

    assert writes and seedRange == 1 and (seed >> 11) & 3 == 3
    assert all((value ^ seed) & keep == 0 for value in writes)
    assert full.result.meta['vsRange'] == seedRange
    assert seedWords(model, gt) == full.before
    assert model.getField(gt.ES_CONTROL) == 0


def test_npz_of_the_default_grid_round_trips_exactly(full):
    res = full.result
    path = full.gt.EyeScan.ResultFile.get()

    arrays, meta = es.loadResult(path)

    assert os.path.dirname(path) == str(full.folder)
    assert sorted(arrays) == sorted(ARRAY_KEYS)
    assert arrays['eye_errors'].dtype == np.int64 and np.array_equal(arrays['eye_errors'], res.errors)
    assert arrays['eye_bits'].dtype == np.int64 and np.array_equal(arrays['eye_bits'], res.bits)
    assert np.array_equal(arrays['eye_open'], res.open)
    assert np.array_equal(arrays['eye_measured'], res.measured)
    assert np.array_equal(arrays['eye_horzAxis'], res.horzAxis)
    assert np.array_equal(arrays['eye_vertAxis'], res.vertAxis)
    assert np.array_equal(arrays['eye_ber'], res.ber, equal_nan=True)
    assert np.array_equal(arrays['eye_berUpper'], res.berUpper, equal_nan=True)
    assert meta['kind'] == 'eye' and meta['status'] == 'OK' and meta['devicePath'] == 'Root.Gt'
    assert meta['engine']['pointsMeasured'] == 4095
    assert meta['activation']['status'] == 'OK'


@pytest.mark.parametrize('rangeMax, step, expected', [
    (127, 4, list(range(-124, 125, 4))),
    (64, 64, [-64, 0, 64]),
    (60, 8, list(range(-56, 57, 8))),
    (16, 16, [-16, 0, 16]),
    (1, 1, [-1, 0, 1]),
])
def test_grid_axis_is_symmetric_truncated_and_contains_zero(rangeMax, step, expected):
    axis = xil.eyescan._EyeScanEngine._gridAxis(rangeMax, step)

    assert axis.dtype == np.int64
    assert axis.tolist() == expected


def test_adjacent_steps_and_ranges_give_the_stated_axes(rigs):
    root, gt, model, hook = rigs(closed)

    res = gt.EyeScan.runEye(horzStep=64, vertStep=127)
    assert res.horzAxis.tolist() == [-64, 0, 64] and res.vertAxis.tolist() == [-127, 0, 127]
    assert res.errors.shape == (2, 3, 3)

    res = gt.EyeScan.runEye(horzStep=32, vertStep=8, horzRange=32, vertRange=60)
    assert res.horzAxis.tolist() == [-32, 0, 32]
    assert res.vertAxis.tolist() == list(range(-56, 57, 8))
    assert res.meta['horzRange'] == 32 and res.meta['vertRange'] == 60

    res = gt.EyeScan.runEye(horzStep=16, vertStep=16, horzRange=16, vertRange=16)
    assert res.horzAxis.tolist() == [-16, 0, 16] and res.vertAxis.tolist() == [-16, 0, 16]


@pytest.mark.parametrize('kwargs', [
    {'horzStep': 0}, {'vertStep': -1}, {'horzStep': 65}, {'vertStep': 17, 'vertRange': 16},
    {'horzRange': 0}, {'vertRange': 0}, {'horzRange': 65}, {'vertRange': 128},
    {'horzStep': 2.5}, {'vertStep': True}, {'horzRange': True}, {'vertRange': 1.5},
    {'floor': 1}, {'floor': 0.0}, {'confidence': 1.0}, {'equalizer': 'xyz'}, {'fixedPrescale': 32},
    {'maxTimePerRun': 0.0}, {'horzStep': 8, 'horzRange': 4},
])
def test_invalid_arguments_are_refused_before_any_write(rigs, kwargs):
    root, gt, model, hook = rigs(closed)
    writes = len(model.writes)

    with pytest.raises(ValueError):
        gt.EyeScan.runEye(**kwargs)

    assert len(model.writes) == writes


def test_a_vertical_code_beyond_the_range_is_refused_before_any_write(rigs):
    root, gt, model, hook = rigs(closed)
    engine = es.EyeScanEngine(es.EyeScanPort(gt, es.GTHE3), gt.EyeScan._hook)
    writes = len(model.writes)

    for vert in (128, -128):
        with pytest.raises(ValueError):
            engine.measurePoint(0, vert=vert, width=32)

    assert len(model.writes) == writes


def test_a_boundary_upper_bound_is_open_and_one_just_above_is_not():
    confidence = 0.95
    bits = np.zeros((2, 1, 3), dtype=np.int64)
    bits[0, 0] = (10_000_000, 20_000_000, 40_000_000)
    errors = np.zeros_like(bits)
    exact = float(es.poissonUpperBound(np.array([0]), np.array([40_000_000]), confidence)[0])
    engine = es.EyeScanEngine(SimpleNamespace(family=es.GTHE3))
    axes = np.array([-1, 0, 1], dtype=np.int64)

    def assemble(floor):
        params = dict(floor=floor, confidence=confidence, equalizer='dfe', resetPolicy='Auto', horzStep=1,
                      vertStep=1, horzRange=1, vertRange=1, fixedPrescale=None, lineRateGbps=0.0,
                      lineRateSource='undefined', warnings=[])
        return engine._assembleEye(axes, np.array([0], dtype=np.int64), errors, bits,
                                   np.zeros((1, 3), dtype=np.int64), params, None, 0, es.ScanStatus.OK,
                                   '', 0.0, datetime.now().astimezone(), None, None)

    atFloor = assemble(exact)
    assert atFloor.berUpper[0, 2] == exact
    assert atFloor.open.tolist() == [[False, False, True]]
    below = assemble(np.nextafter(exact, 0.0))
    assert below.open.tolist() == [[False, False, False]]
    assert below.status is es.ScanStatus.CLOSED
    above = assemble(np.nextafter(exact, 1.0))
    assert above.open.tolist() == [[False, False, True]]


def test_closed_eye_is_a_typed_result_with_full_arrays(rigs):
    root, gt, model, hook = rigs(closed)

    res = gt.EyeScan.runEye(horzStep=16, vertStep=32)

    assert res.status is es.ScanStatus.CLOSED
    assert res.errors.shape == (2, 7, 9) and res.measured.all() and not res.open.any()
    assert gt.EyeScan.Status.get() == 'CLOSED'


@pytest.mark.parametrize('when', ['immediately', 'after the activation'])
def test_abort_before_the_first_point_returns_empty_counts_and_restores(rigs, when):
    root, gt, model, hook = rigs(eye2d)
    before = seedWords(model, gt)
    if when == 'immediately':
        control = es.ScanControl()
        control.abort()
    else:
        control = es.ScanControl(isAborted=lambda: model.runs >= 1)

    res = gt.EyeScan.runEye(horzStep=16, vertStep=32, control=control)

    assert res.status is es.ScanStatus.ABORTED
    assert res.errors.shape == (2, 7, 9) and not res.errors.any() and not res.bits.any()
    assert not res.measured.any() and not res.open.any() and not res.isBound.any()
    assert np.all(np.isnan(res.ber)) and np.all(np.isnan(res.berUpper))
    assert model.getField(gt.ES_CONTROL) == 0
    assert seedWords(model, gt) == before


def test_abort_mid_raster_leaves_a_central_band_of_complete_rows(rigs):
    root, gt, model, hook = rigs(eye2d)
    before = seedWords(model, gt)
    count = 2 * 17 + 5
    calls = []

    def abortAtCount(done, total):
        calls.append(done)
        if len(calls) == count:
            control.abort()

    control = es.ScanControl(onProgress=abortAtCount)

    res = gt.EyeScan.runEye(horzStep=8, vertStep=16, control=control)

    assert res.status is es.ScanStatus.ABORTED
    assert int(res.measured.sum()) == count and res.meta['pointsMeasured'] == count
    order = np.argsort(np.abs(res.vertAxis), kind='stable')
    rows = res.measured.sum(axis=1)
    assert [int(rows[r]) for r in order[:3]] == [17, 17, 5]
    assert int(rows.sum()) == count and not rows[order[3:]].any()
    assert res.vertAxis[order[:3]].tolist() == [0, -16, 16]
    assert res.measured[order[2], :5].all() and not res.measured[order[2], 5:].any()
    assert model.getField(gt.ES_CONTROL) == 0
    assert seedWords(model, gt) == before
    assert gt.EyeScan.Status.get() == 'ABORTED'


@pytest.mark.parametrize('falseCall', [11, 12])
def test_first_link_drop_discards_and_remeasures_the_position(rigs, falseCall):
    root, gt, model, hook = rigs(eye2d, falseCalls={falseCall})
    before = seedWords(model, gt)

    res = gt.EyeScan.runEye(horzStep=16, vertStep=32)

    assert res.status is es.ScanStatus.OK, res.message
    assert res.linkDrops == 1 and res.meta['linkDrops'] == 1
    assert res.measured.all() and res.errors.shape == (2, 7, 9)
    assert seedWords(model, gt) == before


def test_second_link_drop_ends_unlocked_keeping_the_completed_points(rigs):
    root, gt, model, hook = rigs(eye2d, falseCalls={11, 21})
    before = seedWords(model, gt)

    res = gt.EyeScan.runEye(horzStep=16, vertStep=32)

    assert res.status is es.ScanStatus.UNLOCKED
    assert res.linkDrops == 2
    assert 0 < int(res.measured.sum()) < res.measured.size
    assert res.errors.shape == (2, 7, 9)
    assert model.getField(gt.ES_CONTROL) == 0
    assert seedWords(model, gt) == before
    assert gt.EyeScan.Status.get() == 'UNLOCKED'


def test_without_a_hook_the_eye_is_refused_as_not_enabled_with_full_arrays(rigs):
    root, gt, model, hook = rigs(eye2d, withHook=False)
    before = seedWords(model, gt)

    res = gt.EyeScan.runEye(horzStep=16, vertStep=32)

    assert res.status is es.ScanStatus.NOT_ENABLED
    assert 'setRxReset' in res.message
    assert res.errors.shape == (2, 7, 9) and not res.measured.any()
    assert seedWords(model, gt) == before


def test_an_unsupported_width_ends_in_a_typed_result_without_writes(rigs):
    root, gt, model, hook = rigs(eye2d)
    model.setField(gt.RX_DATA_WIDTH, 0)
    writes = len(model.writes)

    res = gt.EyeScan.runEye()

    assert res.status is es.ScanStatus.ERROR
    assert res.horzAxis.size == 0 and res.vertAxis.size == 0 and res.errors.shape == (2, 0, 0)
    assert len(model.writes) == writes


def test_save_names_the_file_by_stamp_device_and_kind_and_sets_result_file(rigs, tmp_path, monkeypatch):
    root, gt, model, hook = rigs(eye2d)
    res = gt.EyeScan.runEye(horzStep=16, vertStep=32)
    assert gt.EyeScan.ResultFile.get() == ''
    monkeypatch.chdir(tmp_path)
    gt.EyeScan.OutputDir.set('nested/out')

    outcome = gt.EyeScan.save()

    expected = os.path.join(str(tmp_path), 'nested', 'out',
                            f"eyescan_{res.meta['stamp']}_Root_Gt_eye.npz")
    assert outcome.errors == [] and outcome.npzPath == expected
    assert gt.EyeScan.ResultFile.get() == expected and os.path.isfile(expected)
    assert not [name for name in os.listdir(os.path.dirname(expected)) if name.endswith('.part')]

    first = open(expected, 'rb').read()

    again = gt.EyeScan.save()

    second = os.path.join(os.path.dirname(expected), f"eyescan_{res.meta['stamp']}_2_Root_Gt_eye.npz")
    assert again.errors == [] and again.npzPath == second
    assert gt.EyeScan.ResultFile.get() == second and os.path.isfile(second)
    assert open(expected, 'rb').read() == first


def test_save_without_a_result_is_refused(rigs):
    root, gt, model, hook = rigs(eye2d)

    with pytest.raises(es.EyeScanError):
        gt.EyeScan.save()


def test_a_save_failure_is_reported_not_raised(rigs, tmp_path):
    root, gt, model, hook = rigs(eye2d)
    blocker = tmp_path / 'file'
    blocker.write_text('x')

    res = gt.EyeScan.runEye(horzStep=16, vertStep=32, outDir=str(blocker / 'sub'))

    assert res.status is es.ScanStatus.OK
    assert gt.EyeScan.ResultFile.get() == ''
    assert gt.EyeScan.lastResult is res


@pytest.mark.parametrize('devicePath, expected', [
    ('Root.Gt', 'eyescan_20260101_000000_Root_Gt_eye'),
    ('Root.Lane[2].Gt', 'eyescan_20260101_000000_Root_Lane_2_Gt_eye'),
    ('../../etc/x', 'eyescan_20260101_000000_etc_x_eye'),
    ('', 'eyescan_20260101_000000_device_eye'),
])
def test_result_stem_has_only_safe_characters(devicePath, expected):
    assert es.resultStem(devicePath, 'eye', '20260101_000000') == expected
    assert es.resultStem(devicePath, 'eye', datetime(2026, 1, 1)) == expected


def test_counts_and_meta_numbers_survive_the_npz_exactly(tmp_path):
    big = 2 ** 62 + 1
    errors = np.full((2, 1, 2), big, dtype=np.int64)
    bits = np.full((2, 1, 2), big + 2, dtype=np.int64)
    shape = (1, 2)
    result = es.EyeResult(
        horzAxis=np.array([0, 1], dtype=np.int64), vertAxis=np.array([0], dtype=np.int64),
        errors=errors, bits=bits, prescale=np.zeros(shape, dtype=np.int64),
        ber=np.full(shape, np.nan), berUpper=np.full(shape, np.inf), isBound=np.zeros(shape, dtype=bool),
        open=np.zeros(shape, dtype=bool), measured=np.ones(shape, dtype=bool), uiPerCount=0.5,
        status=es.ScanStatus.OK, message='', activation=None, linkDrops=0,
        meta=dict(stamp='20260101_000000', count=np.int64(big), width=np.int32(32), ratio=np.float64(0.1),
                  missing=float('nan'), unbounded=float('inf'), flag=np.bool_(True)))

    outcome = es.saveResult(result, tmp_path, devicePath='Root.Gt', extraMeta={'lane': np.int64(3)},
                            surfVersion='test')
    arrays, meta = es.loadResult(outcome.npzPath)

    assert outcome.errors == []
    assert arrays['eye_errors'].dtype == np.int64 and np.array_equal(arrays['eye_errors'], errors)
    assert np.array_equal(arrays['eye_bits'], bits)
    engine = meta['engine']
    assert type(engine['count']) is int and engine['count'] == big
    assert type(engine['width']) is int and engine['width'] == 32
    assert type(engine['ratio']) is float and engine['ratio'] == 0.1
    assert engine['missing'] is None and engine['unbounded'] is None and engine['flag'] is True
    assert type(meta['application']['lane']) is int and meta['application']['lane'] == 3
    assert meta['surfVersion'] == 'test'


def test_meta_json_is_sorted_strict_and_keeps_integers():
    text = es.metaJson({'b': np.int64(5), 'a': [np.float64(0.25), float('nan')], 'c': np.array([1, 2])})

    assert text == '{"a": [0.25, null], "b": 5, "c": [1, 2]}'


def test_surf_version_is_a_non_empty_string_resolved_once():
    first = es.surfVersion()

    assert isinstance(first, str) and first
    assert es.surfVersion() is first
