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
# - Sweep: the command-line runner shared by the application scripts
#   (addEyeScanArguments, prepareEyeScan, runEyeScan) and the PGP4 link
#   adapter (Pgp4EyeScanLink): the argument set and its defaults, the checks
#   made before the hardware is touched, Status, Probe and Bathtub runs, the
#   loopback write and restore, lanes behind separate memory trees, the
#   parallel scan of several lanes, the Ctrl-C stop and the exit code.
# - Stimulus: real Rogue transactions against makeLaneRoot (a Pgp4AxiL lane
#   and its Gthe3Channel behind LaneMemory, the RX reset hook on ResetRx and
#   PhyRxActive), a temporary output directory per test and a real SIGINT
#   sent to the test process during a deep-prescale run.
# - Checks: invalid arguments and lanes are refused before any write and a
#   refused run leaves no run folder; Status is read only; Probe and Bathtub
#   save their files and print the cross-lane table; the raw words line
#   covers the GT words and the PGP4 Ctrl word; a requested loopback is
#   written and the previous value restored; LineRateGbps is set only on
#   request; extraMeta reaches the saved metadata; a parallel run overlaps
#   its lanes, saves the same results as a sequential one, prints the lines of
#   each lane in lane order and keeps scanning when one lane raises; a Ctrl-C
#   aborts the running lane of a sequential run and skips the rest, aborts
#   every lane of a parallel run, returns 2 and restores the previous SIGINT
#   handler and sys.stdout.
# - Timing: countReads=1, a zero settle and a reduced floor and grid keep
#   each run to a few seconds.

import argparse
import os
import signal
import sys
import threading
import time

import numpy as np
import pytest

pr = pytest.importorskip('pyrogue', reason='Eye-scan tests require Rogue/PyRogue')
rogue = pytest.importorskip('rogue', reason='Eye-scan tests require Rogue/PyRogue')

import surf.protocols.pgp as pgp  # noqa: E402
import surf.xilinx.eyescan as es  # noqa: E402

from tests.xilinx.eyescan.gthe3_eye_model import makeLaneRoot  # noqa: E402
from tests.xilinx.eyescan.test_EyeScanBathtub import gauss  # noqa: E402

# Short Bathtub run of the Gaussian eye
BATHTUB = ['--mode', 'Bathtub', '--step', '8', '--berFloor', '1e-6', '--noPng', 'true']


@pytest.fixture
def lanes():
    roots = []

    def make(**kw):
        kw.setdefault('countReads', 1)
        kw.setdefault('berFn', gauss)
        root, gt, lane, model, mem = makeLaneRoot(**kw)
        roots.append(root)
        return gt, lane, model, mem

    yield make
    for root in roots:
        root.stop()


def parse(argv, **defaults):
    parser = argparse.ArgumentParser()
    parser.add_argument('--numLane', type=int, default=1)
    es.addEyeScanArguments(parser)
    parser.set_defaults(**defaults)
    return parser.parse_args(argv)


def target(gt, lane, number=0):
    return es.EyeScanLane(lane=number, gt=gt, link=pgp.Pgp4EyeScanLink(lane))


def run(argv, targets, tmp_path, **kw):
    args = parse(['--outDir', str(tmp_path), *argv])
    plan = es.prepareEyeScan(args, args.numLane)
    return es.runEyeScan(args, plan, targets, **kw), plan


def writes(model, mem):
    return len(model.writes) + len(mem.writes)

#################################################################


def test_the_argument_set_defaults_and_an_application_override():
    args = parse([])
    assert args.mode == 'Status'
    assert args.lanes is None
    assert args.lineRate == 0.0
    assert args.loopback is None
    assert parse([], lineRate=6.25, lanes='4-7').lineRate == 6.25
    with pytest.raises(SystemExit):
        parse(['--noPng', 'maybe'])


@pytest.mark.parametrize('text, numLane, expected', [
    (None, 3, [0, 1, 2]),
    ('5', 8, [5]),
    ('4-6', 8, [4, 5, 6]),
    ('6,4 , 5-5', 8, [4, 5, 6]),
])
def test_lane_lists(text, numLane, expected, tmp_path):
    args = parse(['--outDir', str(tmp_path)] + ([] if text is None else ['--lanes', text]))
    assert es.prepareEyeScan(args, numLane).lanes == expected


@pytest.mark.parametrize('argv, text', [
    (['--lanes', '8'], 'lane list'),
    (['--lanes', '3-1'], 'lane list'),
    (['--lanes', 'a'], 'lane list'),
    (['--mode', 'Probe', '--repeat', '0'], 'repeat'),
    (['--mode', 'Bathtub', '--berFloor', '1.0'], 'berFloor'),
    (['--mode', 'Bathtub', '--step', '0'], 'step'),
    (['--mode', 'Eye', '--horzRange', '-1'], 'horzRange'),
    (['--mode', 'Probe', '--loopback', '2'], 'loopback'),
    (['--mode', 'Bathtub', '--loopback', '8'], 'loopback'),
    (['--mode', 'Bathtub', '--prescale', '32'], 'prescale'),
    (['--mode', 'Bathtub', '--lineRate', '-1'], 'lineRate'),
    (['--mode', 'Bathtub', '--tag', 'a/b'], 'tag'),
    (['--mode', 'Probe', '--softCold', 'true', '--noResetHook', 'true'], 'softCold'),
])
def test_invalid_arguments_are_refused_before_any_folder_is_made(argv, text, tmp_path):
    args = parse(['--outDir', str(tmp_path), *argv])
    with pytest.raises(ValueError, match=text):
        es.prepareEyeScan(args, 8)
    assert os.listdir(tmp_path) == []


def test_status_mode_makes_no_folder_and_writes_nothing(lanes, tmp_path, capsys):
    gt, lane, model, mem = lanes()
    before = writes(model, mem)
    code, plan = run([], [target(gt, lane)], tmp_path)
    assert code == 0
    assert plan.folder is None
    assert os.listdir(tmp_path) == []
    assert writes(model, mem) == before
    out = capsys.readouterr().out
    line = next(text for text in out.splitlines() if text.startswith('Lane[0] '))
    for field in ('EyeScanEn=', 'PhyRxActive=True', 'LinkReady=', 'Hook=', 'LineRate=0'):
        assert field in line


def test_line_rate_is_written_only_on_request(lanes, tmp_path):
    gt, lane, model, mem = lanes()
    run([], [target(gt, lane)], tmp_path)
    assert gt.EyeScan.LineRateGbps.value() == 0.0
    run(['--lineRate', '6.25'], [target(gt, lane)], tmp_path)
    assert gt.EyeScan.LineRateGbps.value() == 6.25


def test_a_missing_lane_is_refused_and_the_run_folder_removed(lanes, tmp_path):
    gt, lane, model, mem = lanes()
    args = parse(['--outDir', str(tmp_path), '--lanes', '1', '--numLane', '2', *BATHTUB])
    plan = es.prepareEyeScan(args, args.numLane)
    assert os.path.isdir(plan.folder)
    before = writes(model, mem)
    with pytest.raises(ValueError, match='Invalid lane 1'):
        es.runEyeScan(args, plan, [target(gt, lane)])
    assert os.listdir(tmp_path) == []
    assert writes(model, mem) == before


def test_loopback_without_a_link_loopback_is_refused_before_any_write(lanes, tmp_path):
    gt, lane, model, mem = lanes()
    before = writes(model, mem)
    with pytest.raises(ValueError, match='no loopback control'):
        run([*BATHTUB, '--loopback', '2'], [es.EyeScanLane(0, gt)], tmp_path)
    assert os.listdir(tmp_path) == []
    assert writes(model, mem) == before


def test_probe_saves_its_npz_and_prints_the_table(lanes, tmp_path, capsys):
    gt, lane, model, mem = lanes()
    code, plan = run(['--mode', 'Probe', '--repeat', '2', '--tag', 'p1'], [target(gt, lane)], tmp_path)
    assert code == 0
    assert os.path.basename(plan.folder).endswith('_p1')
    names = os.listdir(plan.folder)
    assert len(names) == 1 and names[0].endswith('_probe_lane0_p1.npz')
    out = capsys.readouterr().out
    assert out.count('Lane[0] rep=') == 2
    assert 'Summary (' in out


def test_bathtub_saves_the_result_and_reports_the_link_evidence(lanes, tmp_path, capsys):
    gt, lane, model, mem = lanes()
    code, plan = run(BATHTUB, [target(gt, lane)], tmp_path, extraMeta={'boardType': 'Emulated'})
    assert code == 0
    npz = sorted(name for name in os.listdir(plan.folder) if name.endswith('.npz'))
    csv = [name for name in os.listdir(plan.folder) if name.endswith('.csv')]
    assert len(npz) == 1 and len(csv) == 1
    assert not [name for name in os.listdir(plan.folder) if name.endswith('.png')]
    _, meta = es.loadResult(os.path.join(plan.folder, npz[0]))
    extra = meta['application']
    assert extra['boardType'] == 'Emulated'
    assert set(extra['countersBefore']) == {'LinkReady', 'PhyRxInitCnt', 'LinkDownCnt'}
    assert set(extra['rawBefore']) == {'0x3C', '0x4F', '0x93', '0x97', 'Ctrl'}
    out = capsys.readouterr().out
    assert 'Lane[0] bathtub status=OK' in out
    assert 'Lane[0] raw words: 0x4F/0x93/0x97 unchanged, 0x3C unchanged except bits 9:8, Ctrl unchanged' in out
    row = out.splitlines()[-1].split()
    assert row[:3] == ['0', 'Bathtub', 'OK']


def test_a_requested_loopback_is_written_and_restored(lanes, tmp_path):
    gt, lane, model, mem = lanes()
    lane.Ctrl.Loopback.set(0)
    seen = []
    measure = es._EyeScanRunner.measureLane

    def spy(gt, args, control, **kw):
        seen.append(int(lane.Ctrl.Loopback.get()))
        return measure(gt, args, control, **kw)

    es._EyeScanRunner.measureLane = spy
    try:
        code, plan = run([*BATHTUB, '--loopback', '2'], [target(gt, lane)], tmp_path)
    finally:
        es._EyeScanRunner.measureLane = measure
    assert code == 0
    assert seen == [2]
    assert int(lane.Ctrl.Loopback.get()) == 0


def test_lanes_behind_separate_memory_trees_run_in_one_call(lanes, tmp_path, capsys):
    gt0, lane0, _, _ = lanes()
    gt1, lane1, _, _ = lanes(seed=2)
    code, plan = run(['--numLane', '2', *BATHTUB], [target(gt0, lane0, 0), target(gt1, lane1, 1)], tmp_path)
    assert code == 0
    assert len([name for name in os.listdir(plan.folder) if name.endswith('.npz')]) == 2
    out = capsys.readouterr().out
    assert 'Lane[0] bathtub status=OK' in out and 'Lane[1] bathtub status=OK' in out


def test_connect_rx_reset_registers_the_pgp4_hook(lanes):
    gt, lane, model, mem = lanes()
    gt.EyeScan.clearRxReset()
    assert gt.EyeScan.RxResetHook.get() == 'none'
    pgp.Pgp4EyeScanLink.connectRxReset(gt, lane, settle=0.0)
    assert 'ResetRx' in gt.EyeScan.RxResetHook.get()


@pytest.mark.skipif(threading.current_thread() is not threading.main_thread(), reason='SIGINT needs the main thread')
def test_ctrl_c_aborts_the_running_lane_of_a_sequential_run_skips_the_rest_and_returns_2(lanes, tmp_path, capsys):
    # Every run of the first lane stays in COUNT until RUN is cleared
    gt0, lane0, model0, _ = lanes(slowFrom=0, slowReads=10**9)
    gt1, lane1, _, _ = lanes()
    # The first surf version lookup runs git, which can outlast the timer before the handler is installed
    es.surfVersion()
    handler = signal.getsignal(signal.SIGINT)
    timer = threading.Timer(1.0, os.kill, (os.getpid(), signal.SIGINT))
    timer.start()
    try:
        code, plan = run(['--numLane', '2', '--parallel', 'false', *BATHTUB],
                         [target(gt0, lane0, 0), target(gt1, lane1, 1)], tmp_path)
    finally:
        timer.cancel()
    assert code == 2
    assert signal.getsignal(signal.SIGINT) is handler
    out = capsys.readouterr().out
    assert 'Stop requested: restoring the registers' in out
    assert 'Lane[1] bathtub' not in out
    rows = [line.split() for line in out.splitlines() if line.startswith('0 ')]
    assert rows and rows[-1][:3] == ['0', 'Bathtub', 'ABORTED']


def npzArrays(folder):
    out = {}
    for name in sorted(os.listdir(folder)):
        if name.endswith('.npz'):
            arrays, meta = es.loadResult(os.path.join(folder, name))
            out[meta['application']['lane']] = arrays
    return out


def test_a_parallel_run_overlaps_its_lanes_and_prints_them_in_lane_order(lanes, tmp_path, capsys):
    made = [lanes(seed=seed) for seed in (1, 2, 3)]
    spans = {}
    measure = es._EyeScanRunner.measureLane

    def spy(gt, args, control, **kw):
        assert kw == {'progressBar': False}
        start = time.monotonic()
        try:
            return measure(gt, args, control, **kw)
        finally:
            spans[gt] = (start, time.monotonic())

    es._EyeScanRunner.measureLane = spy
    try:
        code, plan = run(['--numLane', '3', *BATHTUB], [target(gt, lane, n) for n, (gt, lane, _, _) in enumerate(made)], tmp_path)
    finally:
        es._EyeScanRunner.measureLane = measure
    assert code == 0
    assert not isinstance(sys.stdout, es._EyeScanRunner._LaneOutput)
    # Every lane started before any lane ended
    assert max(start for start, _ in spans.values()) < min(end for _, end in spans.values())
    out = capsys.readouterr().out
    first = [out.index(f'Lane[{n}] ') for n in range(3)]
    last = [out.rindex(f'Lane[{n}] ') for n in range(3)]
    assert last[0] < first[1] and last[1] < first[2]
    assert out.index('Lane[2] ') < out.index('Summary (')
    rows = [line.split() for line in out.splitlines() if line[:2] in ('0 ', '1 ', '2 ')]
    assert [row[:3] for row in rows] == [[str(n), 'Bathtub', 'OK'] for n in range(3)]


def test_a_parallel_run_saves_the_results_of_a_sequential_run(lanes, tmp_path):
    folders = {}
    for parallel in ('true', 'false'):
        made = [lanes(seed=seed) for seed in (1, 2)]
        out = tmp_path / parallel
        code, plan = run(['--numLane', '2', '--parallel', parallel, *BATHTUB],
                         [target(gt, lane, n) for n, (gt, lane, _, _) in enumerate(made)], out)
        assert code == 0
        folders[parallel] = npzArrays(plan.folder)
    assert sorted(folders['true']) == sorted(folders['false']) == [0, 1]
    for lane in (0, 1):
        par, seq = folders['true'][lane], folders['false'][lane]
        assert sorted(par) == sorted(seq)
        for key in par:
            assert np.array_equal(par[key], seq[key], equal_nan=par[key].dtype.kind == 'f'), (lane, key)


def test_a_lane_that_raises_ends_error_and_the_other_lanes_finish(lanes, tmp_path, capsys):
    gt0, lane0, _, _ = lanes()
    gt1, lane1, _, _ = lanes(seed=2)
    measure = es._EyeScanRunner.measureLane

    def spy(gt, args, control, **kw):
        if gt is gt0:
            raise RuntimeError('emulated lane failure')
        return measure(gt, args, control, **kw)

    es._EyeScanRunner.measureLane = spy
    try:
        code, plan = run(['--numLane', '2', *BATHTUB], [target(gt0, lane0, 0), target(gt1, lane1, 1)], tmp_path)
    finally:
        es._EyeScanRunner.measureLane = measure
    assert code == 2
    out = capsys.readouterr().out
    assert 'Lane[0] ERROR RuntimeError: emulated lane failure' in out
    assert 'Lane[1] bathtub status=OK' in out
    rows = [line.split() for line in out.splitlines() if line[:2] in ('0 ', '1 ')]
    assert [row[:3] for row in rows] == [['0', 'Bathtub', 'ERROR'], ['1', 'Bathtub', 'OK']]


@pytest.mark.skipif(threading.current_thread() is not threading.main_thread(), reason='SIGINT needs the main thread')
def test_ctrl_c_aborts_every_lane_of_a_parallel_run_and_returns_2(lanes, tmp_path, capsys):
    # Every run of both lanes stays in COUNT until RUN is cleared
    made = [lanes(slowFrom=0, slowReads=10**9, seed=seed) for seed in (1, 2)]
    # The first surf version lookup runs git, which can outlast the timer before the handler is installed
    es.surfVersion()
    handler = signal.getsignal(signal.SIGINT)
    stdout = sys.stdout
    timer = threading.Timer(1.0, os.kill, (os.getpid(), signal.SIGINT))
    timer.start()
    try:
        code, plan = run(['--numLane', '2', *BATHTUB], [target(gt, lane, n) for n, (gt, lane, _, _) in enumerate(made)], tmp_path)
    finally:
        timer.cancel()
    assert code == 2
    assert signal.getsignal(signal.SIGINT) is handler
    assert sys.stdout is stdout
    out = capsys.readouterr().out
    assert out.count('Stop requested: restoring the registers') == 1
    rows = [line.split() for line in out.splitlines() if line[:2] in ('0 ', '1 ')]
    assert [row[:3] for row in rows] == [['0', 'Bathtub', 'ABORTED'], ['1', 'Bathtub', 'ABORTED']]
    # Both partial results are saved
    assert sorted(npzArrays(plan.folder)) == [0, 1]
