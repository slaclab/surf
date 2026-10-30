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
# - Sweep: the eye-scan result files of every result kind (eye, bathtub and
#   margin): the pinned npz key lists, the long-form CSV, the write order and
#   failure policy, never overwriting an existing file (a collision moves the
#   save to the next free serial), and the child save that maps the outcome to
#   ResultFile.
# - Stimulus: synthetic EyeResult, BathtubResult and MarginResult objects built
#   with numpy (no root needed) for the file format cases, and one real
#   emulated GTHE3 lane for the EyeScan.save cases.
# - Checks: the npz key set of each kind equals the pinned list and the meta
#   JSON has sorted keys; the CSV header equals the column list, rows are
#   ordered by kind, vertical code and horizontal count whatever the order of
#   the arrays, a zero-error point is nan with its upper bound and never BER 0,
#   floats round-trip, an empty result gives a header-only CSV and full-shape
#   npz arrays; a second save of the same result, or of a different result with
#   the same stem, writes every file under the next free serial (the stem with
#   the serial after the stamp) and leaves the first files byte-identical, an
#   existing CSV or requested PNG alone moves the whole save, and two Start
#   runs in the same second both keep their files; an interrupted npz or CSV write leaves neither the final file nor a .part file
#   and keeps what an earlier step wrote; a missing nested folder is created
#   and a folder below a regular file fails with nothing written; ResultFile is
#   the npz path only after a full success.
#   PNG files are written after the data files, only on request, each plot in
#   its own try, with matplotlib imported inside the plot functions only: in a
#   fresh interpreter with matplotlib blocked, surf imports, a save with PNGs
#   still writes the npz and CSV and reports the plotting failure, and a save
#   without PNGs never imports matplotlib; the figures mark the measurement
#   floor and the target BER, draw zero-error points as upper bounds (never as
#   a BER) and label the fitted tails extrapolated.
# - Timing: pure numpy and file operations; the one emulated lane runs a 3 by 3
#   eye with a zero settle, so no test waits on real hardware time. A figure
#   renders in well under a second.

import csv
import dataclasses
import json
import math
import subprocess
import sys

from datetime import datetime, timezone
from pathlib import Path

import pytest

pr = pytest.importorskip('pyrogue', reason='Eye-scan tests require Rogue/PyRogue')

import numpy as np  # noqa: E402
rogue = pytest.importorskip('rogue', reason='Eye-scan tests require Rogue/PyRogue')

import surf.xilinx.eyescan as es  # noqa: E402
from surf.xilinx.eyescan import _EyeScanEngine as engine  # noqa: E402
from surf.xilinx.eyescan import _EyeScanOutput as out  # noqa: E402

from tests.xilinx.eyescan.test_EyeScanBathtub import gauss, warmRig  # noqa: E402

NPZ_EYE = ['meta', 'eye_horzAxis', 'eye_vertAxis', 'eye_errors', 'eye_bits', 'eye_prescale', 'eye_ber',
           'eye_berUpper', 'eye_isBound', 'eye_open', 'eye_measured']
NPZ_HORZ = ['meta', 'horz_axis', 'horz_errors', 'horz_bits', 'horz_prescale', 'horz_ber', 'horz_berUpper',
            'horz_isBound']
NPZ_MARGIN = (NPZ_EYE
              + [f'horz_{s}' for s in ('axis', 'errors', 'bits', 'prescale', 'ber', 'berUpper', 'isBound')]
              + [f'vert_{s}' for s in ('axis', 'errors', 'bits', 'prescale', 'ber', 'berUpper', 'isBound')])
HEADER = ['kind', 'horz_count', 'horz_ui', 'vert_code', 'errors_ut0', 'errors_ut1', 'bits_ut0', 'bits_ut1',
          'prescale', 'ber', 'ber_upper', 'is_bound', 'open']
CONFIDENCE = 0.95
UI = 1.0 / 128.0
STAMP = '20260101_000000'


# ----------------------------------------------------------------------------
# Synthetic results
# ----------------------------------------------------------------------------


def bounds(errors, bits):
    """BER, upper bound and bound flag of per-sign counts shaped (2, ...)."""
    e = errors.sum(axis=0).astype(float)
    b = bits.sum(axis=0).astype(float)
    isBound = (e == 0) & (b > 0)
    ber = np.where(e > 0, e / np.where(b > 0, b, 1.0), np.nan)
    upper = np.where(b > 0, np.where(isBound, -math.log(1 - CONFIDENCE) / np.where(b > 0, b, 1.0),
                                     (e + 3.0) / np.where(b > 0, b, 1.0)), np.nan)
    return ber, upper, isBound


def makeEye(horz=(-8, 0, 8), vert=(-16, 0, 16), *, errorsFn=None, measuredFn=None, floor=1e-6, stamp=STAMP,
            message=''):
    horzAxis = np.array(horz, dtype=np.int64)
    vertAxis = np.array(vert, dtype=np.int64)
    shape = (vertAxis.size, horzAxis.size)
    errors = np.zeros((2,) + shape, dtype=np.int64)
    bits = np.full((2,) + shape, 10 ** 9, dtype=np.int64)
    measured = np.ones(shape, dtype=bool)
    for i, v in enumerate(vertAxis):
        for j, h in enumerate(horzAxis):
            if measuredFn is not None and not measuredFn(int(h), int(v)):
                measured[i, j] = False
                bits[:, i, j] = 0
            elif errorsFn is not None:
                errors[0, i, j], errors[1, i, j] = errorsFn(int(h), int(v))
    ber, upper, isBound = bounds(errors, bits)
    isOpen = measured & (upper <= floor)
    return es.EyeResult(
        horzAxis=horzAxis, vertAxis=vertAxis, errors=errors, bits=bits,
        prescale=np.where(measured, 3, 0).astype(np.int64), ber=ber, berUpper=upper, isBound=isBound & measured,
        open=isOpen, measured=measured, uiPerCount=UI, status=es.ScanStatus.OK, message=message,
        activation=None, linkDrops=0, centre=None,
        meta=dict(stamp=stamp, floor=floor, confidence=CONFIDENCE, uiPerCount=UI, family='GTHE3'))


def makeSweep(axis, positions, fixed, *, floor=1e-9, errorsFn=None):
    positions = np.array(positions, dtype=np.int64)
    errors = np.zeros((2, positions.size), dtype=np.int64)
    bits = np.full((2, positions.size), 10 ** 11, dtype=np.int64)
    if errorsFn is not None:
        for k, p in enumerate(positions):
            errors[0, k], errors[1, k] = errorsFn(int(p))
    ber, upper, isBound = bounds(errors, bits)
    return es.SweepResult(
        axis=axis, positions=positions, fixed=fixed, errors=errors, bits=bits,
        prescale=np.full(positions.size, 5, dtype=np.int64), ber=ber, berUpper=upper, isBound=isBound,
        scale=UI if axis == 'horz' else 1.0, floor=floor, lowFit=None, highFit=None, openingAtFloor=None,
        openingAtTarget=None, targetBer=1e-12, extrapolated=False, insufficientData=True, clipped=False,
        complete=True)


def makeBathtub(counts=(-8, -4, 0, 4, 8), *, errorsFn=None, floor=1e-9, stamp=STAMP):
    sweep = makeSweep('horz', counts, 0, floor=floor, errorsFn=errorsFn)
    return es.BathtubResult(
        horzCounts=sweep.positions, errors=sweep.errors, bits=sweep.bits, prescale=sweep.prescale,
        ber=sweep.ber, berUpper=sweep.berUpper, isBound=sweep.isBound, uiPerCount=UI,
        status=es.ScanStatus.OK, message='', activation=None, linkDrops=0, leftFit=None, rightFit=None,
        openingAtFloorUI=None, openingAtTargetUI=None, targetBer=1e-12, extrapolated=False,
        insufficientData=True, utComparison=None,
        meta=dict(stamp=stamp, floor=floor, confidence=CONFIDENCE, targetBer=1e-12, uiPerCount=UI))


def edgeErrors(h, v):
    """Errors on the eye edge only, so the middle of the grid stays zero-error."""
    return (700_000, 300_000) if abs(h) == 8 or abs(v) == 16 else (0, 0)


def makeCentre():
    return es.EyeCentre(horz=0.0, vert=0.0, row=1, column=1, horzRun=(0, 2), vertRun=(0, 2),
                        horzOpeningUI=16 * UI, vertOpeningCodes=32.0, clippedH=False, clippedV=False,
                        chordLeft=8.0, chordRight=8.0, chordBottom=16.0, chordTop=16.0, offsetUI=0.0,
                        offsetCodes=0.0)


def makeMargin(stamp=STAMP):
    eye = dataclasses.replace(makeEye(errorsFn=edgeErrors, stamp=stamp), centre=makeCentre())
    horz = makeSweep('horz', range(-4, 5), 0, errorsFn=lambda p: (2_000_000_000, 0) if abs(p) == 4 else (0, 0))
    vert = makeSweep('vert', range(-6, 7), 0, errorsFn=lambda p: (0, 5_000_000_000) if abs(p) == 6 else (0, 0))
    summary = dataclasses.make_dataclass('Summary', [])()
    return es.MarginResult(eye=eye, horz=horz, vert=vert, summary=summary, status=es.ScanStatus.OK,
                           message='', activation=None, linkDrops=0, meta=dict(stamp=stamp))


def save(result, folder, **kw):
    return es.saveResult(result, folder, devicePath='Root.Gt', surfVersion='test', **kw)


def readCsv(path):
    with open(path, newline='') as handle:
        rows = list(csv.reader(handle))
    return rows[0], rows[1:]


def snapshot(folder):
    return {p.name: p.read_bytes() for p in sorted(folder.iterdir())}


# ----------------------------------------------------------------------------
# Pinned formats
# ----------------------------------------------------------------------------


def test_npz_keys_and_csv_columns_are_the_pinned_lists():
    assert list(out.CSV_COLUMNS) == HEADER
    assert list(out.NPZ_KEYS['eye']) == NPZ_EYE
    assert list(out.NPZ_KEYS['bathtub']) == NPZ_HORZ
    assert list(out.NPZ_KEYS['margin']) == NPZ_MARGIN


@pytest.mark.parametrize('kind, make', [('eye', makeEye), ('bathtub', makeBathtub), ('margin', makeMargin)])
def test_saved_npz_carries_exactly_the_pinned_keys_and_sorted_meta(tmp_path, kind, make):
    outcome = save(make(), tmp_path)

    assert outcome.errors == []
    with np.load(outcome.npzPath, allow_pickle=False) as data:
        assert sorted(data.files) == sorted(out.NPZ_KEYS[kind])
        text = str(data['meta'])
    meta = json.loads(text)
    assert meta['kind'] == kind
    assert text == json.dumps(meta, sort_keys=True, allow_nan=False)


def test_a_margin_without_its_sweeps_still_has_every_pinned_key(tmp_path):
    margin = dataclasses.replace(makeMargin(), horz=None, vert=None, status=es.ScanStatus.CLOSED)

    outcome = save(margin, tmp_path)

    arrays, _ = es.loadResult(outcome.npzPath)
    assert outcome.errors == []
    assert sorted(['meta'] + list(arrays)) == sorted(NPZ_MARGIN)
    assert arrays['horz_errors'].shape == (2, 0) and arrays['vert_axis'].shape == (0,)
    assert arrays['horz_errors'].dtype == np.int64


# ----------------------------------------------------------------------------
# CSV content
# ----------------------------------------------------------------------------


def test_csv_header_and_one_row_per_measured_eye_point(tmp_path):
    eye = makeEye(errorsFn=edgeErrors, measuredFn=lambda h, v: not (h == 8 and v == 16))

    outcome = save(eye, tmp_path)

    header, rows = readCsv(outcome.csvPath)
    assert header == HEADER
    assert outcome.csvPath == outcome.npzPath[:-4] + '.csv'
    assert len(rows) == int(eye.measured.sum()) == 8
    assert {row[0] for row in rows} == {'eye'}
    assert all(len(row) == 13 for row in rows)


def test_csv_margin_has_eye_rows_then_one_horz_row_per_row_position_and_one_vert_row_per_column_position(tmp_path):
    margin = makeMargin()
    margin.horz.fixed, margin.vert.fixed = 16, -8

    outcome = save(margin, tmp_path)

    _, rows = readCsv(outcome.csvPath)
    byKind = {k: [r for r in rows if r[0] == k] for k in ('eye', 'horz', 'vert')}
    assert [len(byKind[k]) for k in ('eye', 'horz', 'vert')] == [9, 9, 13]
    assert [r[0] for r in rows] == ['eye'] * 9 + ['horz'] * 9 + ['vert'] * 13
    assert {r[3] for r in byKind['horz']} == {'16'}
    assert {r[1] for r in byKind['vert']} == {'-8'}
    assert [int(r[1]) for r in byKind['horz']] == list(range(-4, 5))
    assert [int(r[3]) for r in byKind['vert']] == list(range(-6, 7))


def test_csv_bathtub_rows_are_horz_rows_with_vertical_code_zero(tmp_path):
    outcome = save(makeBathtub(), tmp_path)

    _, rows = readCsv(outcome.csvPath)
    assert [r[0] for r in rows] == ['horz'] * 5
    assert {r[3] for r in rows} == {'0'}
    assert [int(r[1]) for r in rows] == [-8, -4, 0, 4, 8]
    assert [float(r[2]) for r in rows] == [h * UI for h in (-8, -4, 0, 4, 8)]


def test_csv_rows_are_ordered_whatever_the_order_of_the_arrays(tmp_path):
    eye = makeEye(horz=(8, -8, 0), vert=(16, -16, 0), errorsFn=edgeErrors)
    margin = dataclasses.replace(makeMargin(), eye=eye)
    margin.horz.positions = margin.horz.positions[::-1].copy()
    margin.vert.positions = margin.vert.positions[::-1].copy()
    for name in ('errors', 'bits'):
        setattr(margin.horz, name, getattr(margin.horz, name)[:, ::-1].copy())
        setattr(margin.vert, name, getattr(margin.vert, name)[:, ::-1].copy())
    for name in ('prescale', 'ber', 'berUpper', 'isBound'):
        setattr(margin.horz, name, getattr(margin.horz, name)[::-1].copy())
        setattr(margin.vert, name, getattr(margin.vert, name)[::-1].copy())

    outcome = save(margin, tmp_path)

    _, rows = readCsv(outcome.csvPath)
    order = {'eye': 0, 'horz': 1, 'vert': 2}
    keys = [(order[r[0]], int(r[3]), int(r[1])) for r in rows]
    assert keys == sorted(keys)
    assert [r[0] for r in rows[:9]] == ['eye'] * 9
    assert [(int(r[3]), int(r[1])) for r in rows[:3]] == [(-16, -8), (-16, 0), (-16, 8)]


def test_csv_zero_error_points_are_nan_with_an_upper_bound_and_never_ber_zero(tmp_path):
    eye = makeEye(errorsFn=edgeErrors)

    outcome = save(eye, tmp_path)

    header, rows = readCsv(outcome.csvPath)
    col = {name: header.index(name) for name in header}
    centre = [r for r in rows if r[col['horz_count']] == '0' and r[col['vert_code']] == '0'][0]
    assert centre[col['ber']] == 'nan' and math.isfinite(float(centre[col['ber_upper']]))
    assert centre[col['is_bound']] == '1'
    for row in rows:
        assert float(row[col['ber']]) != 0.0
        assert row[col['is_bound']] in ('0', '1') and row[col['open']] in ('0', '1')
    edge = [r for r in rows if r[col['horz_count']] == '8'][0]
    assert edge[col['is_bound']] == '0' and 0.0 < float(edge[col['ber']]) < 1.0


def test_csv_floats_round_trip_and_open_follows_the_eye_mask(tmp_path):
    eye = makeEye(errorsFn=edgeErrors)
    flat = eye.berUpper.reshape(-1)

    outcome = save(eye, tmp_path)

    header, rows = readCsv(outcome.csvPath)
    col = {name: header.index(name) for name in header}
    got = [float(r[col['ber_upper']]) for r in rows]
    assert got == [float(v) for v in flat]
    assert [r[col['open']] for r in rows] == ['1' if v else '0' for v in eye.open.reshape(-1)]
    assert [float(r[col['horz_ui']]) for r in rows[:3]] == [h * UI for h in (-8, 0, 8)]
    assert [int(r[col['errors_ut1']]) for r in rows[:3]] == [300_000, 300_000, 300_000]


def test_csv_sweep_open_column_is_the_upper_bound_against_the_sweep_floor(tmp_path):
    margin = makeMargin()

    outcome = save(margin, tmp_path)

    header, rows = readCsv(outcome.csvPath)
    col = {name: header.index(name) for name in header}
    horz = [r for r in rows if r[0] == 'horz']
    expected = ['1' if v <= margin.horz.floor else '0' for v in margin.horz.berUpper]
    assert [r[col['open']] for r in horz] == expected and '1' in expected and '0' in expected


def test_csv_cells_are_numbers_or_the_fixed_kind_words_only(tmp_path):
    outcome = es.saveResult(makeMargin(), tmp_path, devicePath='=cmd|calc!A1', surfVersion='=1+1')

    _, rows = readCsv(outcome.csvPath)
    for row in rows:
        assert row[0] in ('eye', 'horz', 'vert')
        for cell in row[1:]:
            float(cell)


# ----------------------------------------------------------------------------
# Empty results
# ----------------------------------------------------------------------------


def test_an_eye_without_measured_points_saves_full_shape_arrays_and_a_header_only_csv(tmp_path):
    eye = makeEye(measuredFn=lambda h, v: False)

    outcome = save(eye, tmp_path)

    arrays, _ = es.loadResult(outcome.npzPath)
    header, rows = readCsv(outcome.csvPath)
    assert outcome.errors == [] and header == HEADER and rows == []
    assert arrays['eye_errors'].shape == (2, 3, 3) and not arrays['eye_errors'].any()
    assert arrays['eye_bits'].shape == (2, 3, 3) and not arrays['eye_measured'].any()
    assert sorted(['meta'] + list(arrays)) == sorted(NPZ_EYE)


def test_a_bathtub_without_points_saves_empty_count_arrays_and_a_header_only_csv(tmp_path):
    outcome = save(makeBathtub(counts=()), tmp_path)

    arrays, _ = es.loadResult(outcome.npzPath)
    header, rows = readCsv(outcome.csvPath)
    assert outcome.errors == [] and header == HEADER and rows == []
    assert arrays['horz_errors'].shape == (2, 0) and arrays['horz_axis'].shape == (0,)


# ----------------------------------------------------------------------------
# Never overwrite
# ----------------------------------------------------------------------------


def stem(serial=None, kind='eye'):
    return f'eyescan_{STAMP}_{serial}_Root_Gt_{kind}' if serial else f'eyescan_{STAMP}_Root_Gt_{kind}'


def test_the_stem_takes_the_serial_right_after_the_stamp_from_the_second_save():
    assert out.resultStem('Root.Gt', 'eye', STAMP) == stem()
    assert out.resultStem('Root.Gt', 'eye', STAMP, serial=None) == stem()
    assert out.resultStem('Root.Gt', 'eye', STAMP, serial=1) == stem()
    assert out.resultStem('Root.Gt', 'eye', STAMP, serial=2) == stem(2)
    assert out.resultStem('Root.Gt', 'margin', STAMP, serial=13) == stem(13, 'margin')
    for bad in (0, -1):
        with pytest.raises(ValueError):
            out.resultStem('Root.Gt', 'eye', STAMP, serial=bad)


def test_saving_the_same_result_twice_writes_the_second_under_the_next_serial(tmp_path, mpl):
    result = makeMargin()
    first = save(result, tmp_path)
    before = snapshot(tmp_path)

    second = save(result, tmp_path)

    assert first.errors == [] and second.errors == [] and second.pngErrors == []
    assert Path(first.npzPath).name == f"{stem(kind='margin')}.npz"
    assert Path(second.npzPath).name == f"{stem(2, 'margin')}.npz"
    assert Path(second.csvPath).name == f"{stem(2, 'margin')}.csv"
    assert [Path(p).name for p in second.pngPaths] == [f"{stem(2, 'margin')}_bathtub.png",
                                                       f"{stem(2, 'margin')}_eye.png"]
    after = snapshot(tmp_path)
    assert {name: after[name] for name in before} == before
    assert len(after) == 2 * len(before)


def test_a_different_result_with_the_same_stem_cannot_replace_the_first_files(tmp_path):
    first = save(makeEye(message='first'), tmp_path, png=False)
    before = snapshot(tmp_path)

    second = save(makeEye(errorsFn=edgeErrors, message='second'), tmp_path, png=False)
    third = save(makeEye(message='third'), tmp_path, png=False)

    assert [Path(o.npzPath).name for o in (first, second, third)] == [f'{stem(n)}.npz' for n in (None, 2, 3)]
    assert [Path(o.csvPath).name for o in (first, second, third)] == [f'{stem(n)}.csv' for n in (None, 2, 3)]
    after = snapshot(tmp_path)
    assert {name: after[name] for name in before} == before
    assert sorted(after) == sorted(f'{stem(n)}.{ext}' for n in (None, 2, 3) for ext in ('npz', 'csv'))
    assert after[f'{stem(2)}.npz'] != after[f'{stem()}.npz']
    assert es.loadResult(second.npzPath)[1]['message'] == 'second'
    assert es.loadResult(first.npzPath)[1]['message'] == 'first'


def test_an_existing_csv_alone_moves_the_whole_save_to_the_next_serial(tmp_path):
    result = makeEye()
    (tmp_path / f'{stem()}.csv').write_text('keep\n')

    outcome = save(result, tmp_path, png=False)

    assert outcome.errors == []
    assert Path(outcome.npzPath).name == f'{stem(2)}.npz' and Path(outcome.csvPath).name == f'{stem(2)}.csv'
    assert snapshot(tmp_path)[f'{stem()}.csv'] == b'keep\n'
    assert names(tmp_path) == sorted([f'{stem()}.csv', f'{stem(2)}.csv', f'{stem(2)}.npz'])


def test_a_serial_with_any_file_taken_is_skipped(tmp_path):
    (tmp_path / f'{stem()}.npz').write_bytes(b'one')
    (tmp_path / f'{stem(2)}.csv').write_bytes(b'two')

    outcome = save(makeEye(), tmp_path, png=False)

    assert outcome.errors == [] and Path(outcome.npzPath).name == f'{stem(3)}.npz'
    snap = snapshot(tmp_path)
    assert snap[f'{stem()}.npz'] == b'one' and snap[f'{stem(2)}.csv'] == b'two'


def test_a_dangling_symlink_counts_as_taken(tmp_path):
    (tmp_path / f'{stem()}.npz').symlink_to(tmp_path / 'nowhere')

    outcome = save(makeEye(), tmp_path, png=False)

    assert outcome.errors == [] and Path(outcome.npzPath).name == f'{stem(2)}.npz'
    assert not (tmp_path / 'nowhere').exists()


# ----------------------------------------------------------------------------
# Atomic writes and failure policy
# ----------------------------------------------------------------------------


def test_an_exception_during_the_npz_write_leaves_no_npz_and_no_part_file(tmp_path, monkeypatch):
    def boom(handle, *args, **kw):
        handle.write(b'partial')
        raise OSError('disk full')

    monkeypatch.setattr(np, 'savez', boom)

    outcome = save(makeEye(), tmp_path, png=False)

    names = sorted(p.name for p in tmp_path.iterdir())
    assert outcome.npzPath == '' and any('npz' in e and 'disk full' in e for e in outcome.errors)
    assert not any(n.endswith('.npz') or n.endswith('.part') for n in names)
    assert outcome.csvPath != '' and names == [f'eyescan_{STAMP}_Root_Gt_eye.csv']


def test_an_exception_after_the_csv_header_leaves_no_csv_and_a_loadable_npz(tmp_path, monkeypatch):
    real = csv.writer

    class Failing:
        def __init__(self, handle, *args, **kw):
            self.inner = real(handle, *args, **kw)
            self.calls = 0

        def writerow(self, row):
            self.calls += 1
            if self.calls > 1:
                raise OSError('disk full')
            return self.inner.writerow(row)

    monkeypatch.setattr(csv, 'writer', Failing)

    outcome = save(makeEye(), tmp_path, png=False)

    names = sorted(p.name for p in tmp_path.iterdir())
    assert names == [f'eyescan_{STAMP}_Root_Gt_eye.npz']
    assert outcome.csvPath == '' and any('csv' in e and 'disk full' in e for e in outcome.errors)
    arrays, meta = es.loadResult(outcome.npzPath)
    assert meta['kind'] == 'eye' and arrays['eye_errors'].shape == (2, 3, 3)


def test_the_part_name_is_opened_exclusively_so_a_foreign_part_file_survives(tmp_path):
    part = tmp_path / f'eyescan_{STAMP}_Root_Gt_eye.npz.part'
    part.write_bytes(b'foreign')

    outcome = save(makeEye(), tmp_path)

    assert outcome.npzPath == '' and any('npz' in e for e in outcome.errors)
    assert part.read_bytes() == b'foreign'


def test_atomic_write_removes_its_part_file_and_reraises(tmp_path):
    final = str(tmp_path / 'x.bin')

    def writer(handle):
        handle.write(b'abc')
        raise RuntimeError('stop')

    with pytest.raises(RuntimeError, match='stop'):
        out._atomicWrite(final, writer, True)

    assert list(tmp_path.iterdir()) == []


def test_atomic_write_text_mode_uses_the_final_name_only_when_complete(tmp_path):
    final = str(tmp_path / 'x.txt')
    seen = []

    def writer(handle):
        handle.write('a\r\nb')
        seen.append(sorted(p.name for p in tmp_path.iterdir()))

    out._atomicWrite(final, writer, False)

    assert seen == [['x.txt.part']]
    assert (tmp_path / 'x.txt').read_bytes() == b'a\r\nb'
    assert sorted(p.name for p in tmp_path.iterdir()) == ['x.txt']


# ----------------------------------------------------------------------------
# Directory
# ----------------------------------------------------------------------------


def test_a_missing_nested_folder_is_created(tmp_path):
    target = tmp_path / 'a' / 'b'

    outcome = save(makeEye(), target, png=False)

    assert outcome.errors == [] and sorted(p.name for p in target.iterdir()) == [
        f'eyescan_{STAMP}_Root_Gt_eye.csv', f'eyescan_{STAMP}_Root_Gt_eye.npz']


def test_a_folder_below_a_regular_file_fails_at_the_directory_step_and_writes_nothing(tmp_path):
    blocker = tmp_path / 'file'
    blocker.write_text('x')

    outcome = save(makeEye(), blocker / 'sub')

    assert outcome.npzPath == '' and outcome.csvPath == ''
    assert len(outcome.errors) == 1 and outcome.errors[0].startswith('outDir:')
    assert sorted(p.name for p in tmp_path.iterdir()) == ['file']
    assert blocker.read_text() == 'x'


# ----------------------------------------------------------------------------
# Child save and ResultFile
# ----------------------------------------------------------------------------


def eyeFn(horz, vert, ut):
    return 1e-12 if abs(vert) < 40 and abs(horz) < 32 else 1e-2


@pytest.fixture
def rig():
    root, gt, model, hook = warmRig(None, eyeFn=eyeFn)
    try:
        yield gt
    finally:
        root.stop()


def test_child_save_sets_result_file_to_the_npz_after_a_full_success(rig, tmp_path):
    rig.EyeScan.runEye(horzStep=16, vertStep=32)
    assert rig.EyeScan.ResultFile.get() == ''

    outcome = rig.EyeScan.save(outDir=str(tmp_path), png=False)

    assert outcome.errors == [] and outcome.csvPath.endswith('.csv')
    assert rig.EyeScan.ResultFile.get() == outcome.npzPath and outcome.npzPath.endswith('_eye.npz')
    assert sorted(p.suffix for p in tmp_path.iterdir()) == ['.csv', '.npz']


def test_child_save_clears_result_file_after_a_directory_failure_and_keeps_the_result(rig, tmp_path):
    res = rig.EyeScan.runEye(horzStep=16, vertStep=32)
    blocker = tmp_path / 'file'
    blocker.write_text('x')

    outcome = rig.EyeScan.save(outDir=str(blocker / 'sub'))

    assert outcome.errors and rig.EyeScan.ResultFile.get() == ''
    assert rig.EyeScan.lastResult is res


def test_child_save_clears_result_file_after_a_csv_failure(rig, tmp_path, monkeypatch):
    rig.EyeScan.runEye(horzStep=16, vertStep=32)
    monkeypatch.setattr(out, '_writeCsv', lambda result, path: (_ for _ in ()).throw(OSError('disk full')))

    outcome = rig.EyeScan.save(outDir=str(tmp_path))

    assert outcome.npzPath != '' and outcome.csvPath == '' and outcome.errors
    assert rig.EyeScan.ResultFile.get() == ''


# ----------------------------------------------------------------------------
# PNG files
# ----------------------------------------------------------------------------

PNG_SIGNATURE = b'\x89PNG\r\n\x1a\n'
SURF_DIR = str(Path(__file__).resolve().parents[3])


@pytest.fixture
def mpl():
    return pytest.importorskip('matplotlib', reason='PNG tests require matplotlib')


def names(folder):
    return sorted(p.name for p in folder.iterdir())


def tailFits(sweep):
    """Passing fits of both tails whose lines reach the target BER well inside the sweep."""
    unit = sweep.scale
    left = es.TailFit(side='left', ok=True, reason='', sigma=2 * unit, mu=-3 * unit, slope=0.5 / unit,
                      intercept=1.5, r2=0.99, nPoints=6, decades=6.0)
    right = es.TailFit(side='right', ok=True, reason='', sigma=2 * unit, mu=3 * unit, slope=-0.5 / unit,
                       intercept=1.5, r2=0.99, nPoints=6, decades=6.0)
    return dataclasses.replace(sweep, lowFit=left, highFit=right, extrapolated=True, insufficientData=False)


def fitted(margin):
    return dataclasses.replace(margin, horz=tailFits(margin.horz), vert=tailFits(margin.vert))


def test_a_margin_save_writes_npz_csv_then_both_pngs(tmp_path, mpl):
    outcome = save(makeMargin(), tmp_path)

    stem = f'eyescan_{STAMP}_Root_Gt_margin'
    assert outcome.errors == [] and outcome.pngErrors == []
    assert names(tmp_path) == [f'{stem}.csv', f'{stem}.npz', f'{stem}_bathtub.png', f'{stem}_eye.png']
    assert outcome.pngPaths == [str(tmp_path / f'{stem}_bathtub.png'), str(tmp_path / f'{stem}_eye.png')]
    for path in outcome.pngPaths:
        assert Path(path).read_bytes().startswith(PNG_SIGNATURE)


def test_an_eye_save_writes_only_the_eye_png_and_a_bathtub_save_only_the_bathtub_png(tmp_path, mpl):
    eye = save(makeEye(), tmp_path / 'eye')
    bathtub = save(makeBathtub(), tmp_path / 'bathtub')

    assert names(tmp_path / 'eye') == [f'eyescan_{STAMP}_Root_Gt_eye.csv', f'eyescan_{STAMP}_Root_Gt_eye.npz',
                                       f'eyescan_{STAMP}_Root_Gt_eye_eye.png']
    assert names(tmp_path / 'bathtub') == [f'eyescan_{STAMP}_Root_Gt_bathtub.csv',
                                           f'eyescan_{STAMP}_Root_Gt_bathtub.npz',
                                           f'eyescan_{STAMP}_Root_Gt_bathtub_bathtub.png']
    assert [Path(p).read_bytes()[:8] for p in eye.pngPaths + bathtub.pngPaths] == [PNG_SIGNATURE] * 2


def test_png_false_writes_no_png(tmp_path):
    outcome = save(makeMargin(), tmp_path, png=False)

    assert outcome.errors == [] and outcome.pngPaths == [] and outcome.pngErrors == []
    assert not [n for n in names(tmp_path) if n.endswith('.png')]


def test_an_existing_png_alone_moves_the_save_to_the_next_serial_only_when_pngs_are_requested(tmp_path, mpl):
    png = tmp_path / f'{stem()}_eye.png'
    png.write_bytes(b'keep')

    moved = save(makeEye(), tmp_path)
    kept = save(makeEye(), tmp_path, png=False)

    assert moved.errors == [] and Path(moved.npzPath).name == f'{stem(2)}.npz'
    assert [Path(p).name for p in moved.pngPaths] == [f'{stem(2)}_eye.png']
    assert kept.errors == [] and Path(kept.npzPath).name == f'{stem()}.npz'
    assert png.read_bytes() == b'keep'


def test_a_forced_eye_plot_failure_keeps_the_data_files_and_the_independent_bathtub_png(tmp_path, monkeypatch, mpl):
    seen = {}

    def boom(result, path, *, devicePath):
        folder = Path(path).parent
        seen['npz'] = {p.name: p.read_bytes() for p in folder.glob('*.npz')}
        raise RuntimeError('plot exploded')

    monkeypatch.setattr(out, '_plotEye', boom)

    outcome = save(makeMargin(), tmp_path)

    stem = f'eyescan_{STAMP}_Root_Gt_margin'
    assert outcome.errors == [] and len(outcome.pngErrors) == 1
    assert outcome.pngErrors[0].startswith('png:') and 'eye plot' in outcome.pngErrors[0]
    assert 'plot exploded' in outcome.pngErrors[0]
    assert names(tmp_path) == [f'{stem}.csv', f'{stem}.npz', f'{stem}_bathtub.png']
    assert (tmp_path / f'{stem}.npz').read_bytes() == seen['npz'][f'{stem}.npz']
    assert es.loadResult(outcome.npzPath)[1]['kind'] == 'margin'
    assert outcome.pngPaths == [str(tmp_path / f'{stem}_bathtub.png')]


def test_a_failing_plot_leaves_no_part_file(tmp_path, monkeypatch, mpl):
    from matplotlib.figure import Figure

    def boom(self, *args, **kw):
        raise OSError('write failed')

    monkeypatch.setattr(Figure, 'savefig', boom)

    outcome = save(makeMargin(), tmp_path)

    assert len(outcome.pngErrors) == 2 and outcome.errors == []
    assert names(tmp_path) == [f'eyescan_{STAMP}_Root_Gt_margin.csv', f'eyescan_{STAMP}_Root_Gt_margin.npz']


def test_an_eye_whose_data_never_crosses_the_floor_still_renders(tmp_path, mpl):
    allClosed = makeEye(errorsFn=lambda h, v: (700_000, 300_000))
    allOpen = makeEye()

    closedOutcome = save(allClosed, tmp_path / 'closed')
    openOutcome = save(allOpen, tmp_path / 'open')

    assert closedOutcome.pngErrors == [] and openOutcome.pngErrors == []
    assert [len(o.pngPaths) for o in (closedOutcome, openOutcome)] == [1, 1]


@pytest.mark.parametrize('eye', [
    makeEye(measuredFn=lambda h, v: False),
    makeEye(horz=(-8, -4, 0, 4, 8), vert=(0,)),
    makeEye(horz=(0,), vert=(0,)),
], ids=['no points', 'one row', 'one point'])
def test_degenerate_eyes_still_render(tmp_path, eye, mpl):
    outcome = save(eye, tmp_path)

    assert outcome.pngErrors == [] and len(outcome.pngPaths) == 1


def test_a_bathtub_without_points_and_a_margin_without_sweeps_still_render(tmp_path, mpl):
    empty = save(makeBathtub(counts=()), tmp_path / 'empty')
    closedMargin = save(dataclasses.replace(makeMargin(), horz=None, vert=None, status=es.ScanStatus.CLOSED),
                        tmp_path / 'closed')

    assert empty.pngErrors == [] and len(empty.pngPaths) == 1
    assert closedMargin.pngErrors == [] and len(closedMargin.pngPaths) == 2


def legendLabels(ax):
    return [t.get_text() for t in ax.get_legend().get_texts()]


def test_the_margin_bathtub_figure_has_one_axes_per_swept_axis_with_floor_target_and_bound_markers(mpl):
    fig = out._bathtubFigure(fitted(makeMargin()), 'Root.Gt')

    horzAx, vertAx = fig.axes
    for ax in (horzAx, vertAx):
        labels = legendLabels(ax)
        assert any(t.startswith('measurement floor') for t in labels)
        assert any(t.startswith('target BER') for t in labels)
        assert any('upper bound' in t for t in labels)
        assert any('extrapolated' in t for t in labels)
        assert ax.get_yscale() == 'log'
    assert 'UI' in horzAx.get_xlabel() and 'code' in vertAx.get_xlabel()


def test_a_bathtub_figure_never_draws_a_zero_error_point_as_a_measured_ber(mpl):
    result = makeBathtub(errorsFn=lambda p: (5_000_000, 0) if abs(p) == 8 else (0, 0))
    fig = out._bathtubFigure(result, 'Root.Gt')

    ax, = fig.axes
    measured = [line for line in ax.lines if line.get_label() == 'measured BER']
    bounds_ = [line for line in ax.lines if 'upper bound' in line.get_label()]
    assert len(measured) == 1 and len(bounds_) == 1
    assert len(measured[0].get_ydata()) == 2 and np.all(np.asarray(measured[0].get_ydata()) > 0)
    assert bounds_[0].get_marker() == 'v'
    assert np.array_equal(np.asarray(bounds_[0].get_ydata()), result.berUpper[result.isBound])
    for line in ax.lines:
        y = np.asarray(line.get_ydata(), dtype=float)
        assert not np.any(y == 0)


def test_a_failed_fit_is_not_drawn_and_the_figure_has_no_extrapolated_label(mpl):
    fig = out._bathtubFigure(makeBathtub(), 'Root.Gt')

    ax, = fig.axes
    assert not any('extrapolated' in t for t in legendLabels(ax))


def test_the_eye_figure_marks_the_floor_and_the_confidence_and_the_margin_adds_the_centre_and_cross(mpl):
    eye = out._eyeFigure(makeEye(errorsFn=edgeErrors), 'Root.Gt')
    margin = out._eyeFigure(makeMargin(), 'Root.Gt')

    texts = [t.get_text() for t in eye.axes[0].texts]
    assert 'measurement floor BER 1e-06 at 95%' in texts
    assert 'Root.Gt' in eye.axes[0].get_title() and 'GTHE3' in eye.axes[0].get_title()
    assert 'UI' in eye.axes[0].get_xlabel() and 'code' in eye.axes[0].get_ylabel()
    assert len(eye.axes) == 2 and 'log10' in eye.axes[1].get_ylabel() and '95%' in eye.axes[1].get_ylabel()
    ax = margin.axes[0]
    assert any(line.get_label() == 'eye centre' for line in ax.lines)
    assert sum(1 for line in ax.lines if line.get_label() == 'cross') >= 2
    assert not any(line.get_label() == 'eye centre' for line in eye.axes[0].lines)


# ----------------------------------------------------------------------------
# Without matplotlib
# ----------------------------------------------------------------------------

BLOCKED = """
import json, os, sys, tempfile
sys.path.insert(0, {surf!r})
sys.path.insert(0, os.path.join({surf!r}, 'python'))
sys.modules['matplotlib'] = None
import surf
import surf.xilinx.eyescan as es
from tests.xilinx.eyescan.test_EyeScanOutput import makeMargin
folder = tempfile.mkdtemp()
outcome = es.saveResult(makeMargin(), folder, devicePath='Root.Gt', surfVersion='test', png={png})
print(json.dumps(dict(names=sorted(os.listdir(folder)), pngPaths=outcome.pngPaths, pngErrors=outcome.pngErrors,
                      errors=outcome.errors, mpl={mpl})))
"""


def lastJson(text):
    """The JSON line the child printed (Rogue may print a banner around it)."""
    return json.loads([line for line in text.splitlines() if line.startswith('{')][-1])


def freshRun(png):
    code = BLOCKED.format(surf=SURF_DIR, png=png, mpl="'matplotlib' in sys.modules")
    done = subprocess.run([sys.executable, '-I', '-c', code], capture_output=True, text=True, cwd=SURF_DIR)
    assert done.returncode == 0, done.stderr
    return lastJson(done.stdout)


def test_surf_imports_and_saves_the_data_files_with_matplotlib_blocked():
    got = freshRun(True)

    stem = f'eyescan_{STAMP}_Root_Gt_margin'
    assert got['errors'] == [] and got['names'] == [f'{stem}.csv', f'{stem}.npz']
    assert got['pngPaths'] == [] and len(got['pngErrors']) == 2
    assert all(text.startswith('png:') for text in got['pngErrors'])


def test_a_save_without_pngs_leaves_matplotlib_absent_from_a_clean_interpreter():
    code = BLOCKED.format(surf=SURF_DIR, png=False, mpl="'matplotlib' in sys.modules").replace(
        "sys.modules['matplotlib'] = None\n", '')
    done = subprocess.run([sys.executable, '-I', '-c', code], capture_output=True, text=True, cwd=SURF_DIR)

    assert done.returncode == 0, done.stderr
    assert lastJson(done.stdout)['mpl'] is False


def test_no_surf_module_imports_matplotlib_at_module_level():
    root = Path(SURF_DIR) / 'python' / 'surf'
    offenders = []
    for path in root.rglob('*.py'):
        for number, line in enumerate(path.read_text().splitlines(), 1):
            if line.startswith(('import matplotlib', 'from matplotlib')):
                offenders.append(f'{path}:{number}')

    assert offenders == []
    assert 'pyplot' not in (root / 'xilinx' / 'eyescan' / '_EyeScanOutput.py').read_text()


# ----------------------------------------------------------------------------
# Child save with PNGs
# ----------------------------------------------------------------------------


def test_child_save_without_pngs_writes_no_png(rig, tmp_path):
    rig.EyeScan.runEye(horzStep=16, vertStep=32)

    outcome = rig.EyeScan.save(outDir=str(tmp_path), png=False)

    assert outcome.errors == [] and outcome.pngPaths == []
    assert sorted(p.suffix for p in tmp_path.iterdir()) == ['.csv', '.npz']


def test_child_save_writes_the_eye_png_by_default(rig, tmp_path, mpl):
    rig.EyeScan.runEye(horzStep=16, vertStep=32)

    outcome = rig.EyeScan.save(outDir=str(tmp_path))

    assert outcome.errors == [] and outcome.pngErrors == [] and len(outcome.pngPaths) == 1
    assert sorted(p.suffix for p in tmp_path.iterdir()) == ['.csv', '.npz', '.png']


def test_a_png_only_failure_keeps_result_file_on_the_npz(rig, tmp_path, monkeypatch):
    rig.EyeScan.runEye(horzStep=16, vertStep=32)

    def boom(result, path, *, devicePath):
        raise RuntimeError('plot exploded')

    monkeypatch.setattr(out, '_plotEye', boom)

    outcome = rig.EyeScan.save(outDir=str(tmp_path))

    assert outcome.errors == [] and len(outcome.pngErrors) == 1
    assert rig.EyeScan.ResultFile.get() == outcome.npzPath != ''


# ----------------------------------------------------------------------------
# Two Start runs in the same second
# ----------------------------------------------------------------------------


class FixedClock:
    """Stands in for ``datetime`` in the engine: every scan starts at the same instant."""

    @classmethod
    def now(cls, tz=None):
        return datetime(2026, 1, 1, 12, 0, 0, tzinfo=timezone.utc)


def test_two_start_runs_in_the_same_second_both_keep_their_files(tmp_path, monkeypatch):
    root, gt, model, hook = warmRig(gauss)
    child = gt.EyeScan
    monkeypatch.setattr(engine, 'datetime', FixedClock)
    try:
        child.OutputDir.set(str(tmp_path))
        child.Mode.setDisp('Bathtub')
        child.HorzStep.set(64)
        child.BathtubBerFloor.set(1e-6)
        child.SavePng.set(False)
        ended = []
        for _ in range(2):
            child.Start()
            child._thread.join(120)
            assert not child._thread.is_alive()
            assert child.Status.get() == 'OK', child.Message.get()
            ended.append((child.ResultFile.get(), child.Message.get(), child.lastResult.meta['stamp']))
    finally:
        root.stop()

    (npz1, message1, stamp1), (npz2, message2, stamp2) = ended
    assert stamp1 == stamp2
    assert npz1 and npz2 and npz1 != npz2
    assert Path(npz1).name == f'eyescan_{stamp1}_Root_Gt_bathtub.npz'
    assert Path(npz2).name == f'eyescan_{stamp1}_2_Root_Gt_bathtub.npz'
    assert npz1 in message1 and npz2 in message2
    assert names(tmp_path) == sorted(f'eyescan_{stamp1}{serial}_Root_Gt_bathtub.{ext}'
                                     for serial in ('', '_2') for ext in ('csv', 'npz'))
