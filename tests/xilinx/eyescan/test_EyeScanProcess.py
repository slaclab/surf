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
# - Sweep: the PyRogue Process front end of the eye scan (Start and Stop with
#   the Mode, knob and OutputDir variables): the scan each Mode runs, the
#   always-on save of a Start run with its PNG policy, the status, progress
#   and outcome messages, the throttled Progress and Message writes, invalid
#   parameters, a failing OutputDir and the responsiveness of the root while a
#   scan runs.
# - Stimulus: real Rogue transactions against Gthe3EyeModel with the seeded
#   separable eye of the margin tests (or the dual-Dirac bathtub eye), a
#   callable RX reset hook, a temporary OutputDir for every run, and a
#   subprocess ZMQ client for the responsiveness check.
# - Checks: Bathtub, Eye and Margin Start runs end OK with the matching result
#   type and the npz and CSV named by ResultFile, PNGs only when SavePng is
#   True; a Stop keeps the partial result as npz and CSV, writes no PNG and
#   leaves Progress below 1.0; a save failure keeps the scan status and the
#   result; invalid parameters end in ERROR before any GT write; knob changes
#   while Running do not alter the running scan; Stop with nothing running and
#   Start without a hook behave as specified; Message carries eye-row and
#   cross texts and Progress and Message are written about four times per
#   second at most with the final values always written; a client in another
#   process reads Progress within 0.5 s during a Margin scan.
#   Stop is bounded at the four places a scan can be, the RX reset handshake,
#   a deep-prescale run in COUNT, the middle of the eye raster and the middle of
#   the margin cross: each returns within 1.0 s with ABORTED, the npz and CSV
#   saved without a PNG, the scan words back at their pre-scan values and the
#   same restore sequence, ES_CONTROL cleared first. An abort between points
#   keeps exactly the points that completed, a synchronous run during a Start
#   run is refused before any write and stays refused until the Start run has
#   saved its result and written its final Message and Progress, and
#   Root.stop() during a scan restores the registers.
# - Timing: countReads=1 and a zero settle keep the emulated runs short; small
#   grids and a reduced floor keep each Start run to a few seconds.

import json
import os
import subprocess
import sys
import textwrap
import threading
import time

import pytest

pr = pytest.importorskip('pyrogue', reason='Eye-scan tests require Rogue/PyRogue')

import numpy as np  # noqa: E402
rogue = pytest.importorskip('rogue', reason='Eye-scan tests require Rogue/PyRogue')
interfaces = pytest.importorskip('pyrogue.interfaces', reason='Eye-scan tests require Rogue/PyRogue')

import surf.xilinx as xil  # noqa: E402
import surf.xilinx.eyescan as es  # noqa: E402
import surf.xilinx.eyescan._EyeScan as esDevice  # noqa: E402

from tests.xilinx.eyescan.gthe3_eye_model import Gthe3EyeModel, _newRoot, makeGtRoot  # noqa: E402
from tests.xilinx.eyescan.test_EyeScanBathtub import Hook, gauss, seedWords, waitFor  # noqa: E402
from tests.xilinx.eyescan.test_EyeScanMargin import shifted  # noqa: E402
from tests.xilinx.eyescan.test_EyeScanNoLink import static  # noqa: E402


@pytest.fixture
def rigs(tmp_path):
    roots = []

    def make(eyeFn=None, berFn=None, hook=True, **kw):
        root, gt, model = makeGtRoot(requireReset=True, countReads=1, eyeFn=eyeFn, berFn=berFn, **kw)
        roots.append(root)
        if hook:
            rxHook = Hook(model)
            gt.EyeScan.setRxReset(rxHook.pulse, rxHook.ready, settle=0.0, fallWait=0.05, timeout=0.5)
        gt.EyeScan.OutputDir.set(str(tmp_path))
        return gt.EyeScan, model

    yield make
    for root in roots:
        root.stop()


def finish(child, timeout=120):
    """Wait for the worker thread of the last Start to end."""
    child._thread.join(timeout)
    assert not child._thread.is_alive()


def setKnobs(child, **knobs):
    for name, value in knobs.items():
        if isinstance(value, str):
            child.variables[name].setDisp(value)
        else:
            child.variables[name].set(value)


def small(child, mode, **knobs):
    """Knobs of a short run of ``mode`` on the seeded eye."""
    base = dict(Mode=mode, HorzStep=8, VertStep=16, EyeBerFloor=1e-6, BathtubBerFloor=1e-6)
    if mode == 'Margin':
        base.update(VertStep=8, HorzRange=32, VertRange=48)
    base.update(knobs)
    setKnobs(child, **base)


def files(folder, suffix):
    return sorted(name for name in os.listdir(folder) if name.endswith(suffix))


def test_bathtub_mode_runs_a_bathtub_and_saves_npz_csv_and_png(rigs, tmp_path):
    child, model = rigs(berFn=gauss)
    setKnobs(child, Mode='Bathtub', HorzStep=1, BathtubBerFloor=1e-6)

    child.Start()
    finish(child)

    result = child.lastResult
    assert child.Status.get() == 'OK'
    assert isinstance(result, es.BathtubResult) and result.horzCounts.size == 129
    assert child.Message.get().startswith('OK')
    npz = child.ResultFile.get()
    assert os.path.dirname(npz) == str(tmp_path) and os.path.exists(npz)
    assert files(tmp_path, '.csv') == [os.path.basename(npz)[:-4] + '.csv']
    assert files(tmp_path, '_bathtub.png') == [os.path.basename(npz)[:-4] + '_bathtub.png']
    assert os.path.basename(npz) in child.Message.get()
    assert child.Progress.value() == pytest.approx(1.0)
    meta = json.loads(str(np.load(npz)['meta']))
    assert meta['engine']['floor'] == 1e-6 and meta['engine']['step'] == 1


@pytest.mark.parametrize('savePng', [True, False])
def test_eye_mode_runs_an_eye_and_renders_the_png_only_when_asked(rigs, tmp_path, savePng):
    child, model = rigs(eyeFn=shifted)
    small(child, 'Eye', SavePng=savePng)

    child.Start()
    finish(child)

    assert child.Status.get() == 'OK', child.Message.get()
    assert isinstance(child.lastResult, es.EyeResult)
    assert child.lastResult.horzAxis.size == 17 and child.lastResult.vertAxis.size == 15
    assert os.path.exists(child.ResultFile.get()) and len(files(tmp_path, '.csv')) == 1
    assert len(files(tmp_path, '_eye.png')) == (1 if savePng else 0)
    assert files(tmp_path, '_bathtub.png') == []


def test_margin_is_the_default_mode_and_publishes_the_summary(rigs, tmp_path):
    child, model = rigs(eyeFn=shifted)
    small(child, 'Margin')
    setKnobs(child, Mode='Margin')

    child.Start()
    finish(child)

    result = child.lastResult
    assert child.Status.get() == 'OK', child.Message.get()
    assert isinstance(result, es.MarginResult)
    assert os.path.exists(child.ResultFile.get()) and len(files(tmp_path, '.csv')) == 1
    assert len(files(tmp_path, '_eye.png')) == 1 and len(files(tmp_path, '_bathtub.png')) == 1
    assert child.HorzOpeningUI.value() == pytest.approx(result.summary.horzOpeningUI)
    assert child.VertOpeningCodes.value() == pytest.approx(result.summary.vertOpeningCodes)
    assert child.BerAtCenter.value() == result.summary.berAtCenterText
    message = child.Message.get()
    assert result.summary.text in message and os.path.basename(child.ResultFile.get()) in message


def test_the_mode_default_is_margin(rigs):
    child, model = rigs(eyeFn=shifted)
    assert child.Mode.valueDisp() == 'Margin'


def test_stop_during_an_eye_keeps_the_partial_result_without_a_png(rigs, tmp_path):
    child, model = rigs(eyeFn=shifted)
    setKnobs(child, Mode='Eye', HorzStep=2, VertStep=4, EyeBerFloor=1e-6)
    child.Start()
    deadline = time.monotonic() + 60
    while child.Progress.value() < 0.02 and time.monotonic() < deadline:
        time.sleep(0.02)
    assert child.Progress.value() >= 0.02

    started = time.monotonic()
    child.Stop()
    stopped = time.monotonic() - started

    assert stopped < 1.0
    finish(child, 5)
    assert child.Status.get() == 'ABORTED'
    npz = child.ResultFile.get()
    assert os.path.exists(npz) and os.path.exists(npz[:-4] + '.csv')
    message = child.Message.get()
    assert message.startswith('Scan stopped') and npz in message
    assert [name for name in os.listdir(tmp_path) if name.endswith('.png')] == []
    assert 0.0 < child.Progress.value() < 1.0
    assert child.lastResult.status is es.ScanStatus.ABORTED


def test_a_failing_output_dir_keeps_the_status_and_the_result(rigs, tmp_path):
    child, model = rigs(eyeFn=shifted)
    blocker = tmp_path / 'blocker'
    blocker.write_text('not a folder')
    small(child, 'Eye')
    child.OutputDir.set(str(blocker / 'below'))

    child.Start()
    finish(child)

    assert child.Status.get() == 'OK'
    assert isinstance(child.lastResult, es.EyeResult)
    assert child.ResultFile.get() == ''
    assert 'Save failed:' in child.Message.get()


@pytest.mark.parametrize('knobs,text', [
    (dict(EyeBerFloor=0.0), 'floor'),
    (dict(EyeBerFloor=1.5), 'floor'),
    (dict(HorzStep=100), 'horzStep'),
])
def test_invalid_parameters_end_in_error_before_any_gt_write(rigs, tmp_path, knobs, text):
    child, model = rigs(eyeFn=shifted)
    small(child, 'Eye', **knobs)
    writes = len(model.writes)

    child.Start()
    finish(child)

    assert child.Status.get() == 'ERROR'
    assert child.Message.get().startswith('Error:') and text in child.Message.get()
    assert len(model.writes) == writes
    assert child.ResultFile.get() == '' and os.listdir(tmp_path) == []


def test_an_unexpected_exception_of_a_start_run_ends_error_with_its_type(rigs, tmp_path, monkeypatch):
    child, model = rigs(eyeFn=shifted)
    small(child, 'Eye')

    def failing(params, control):
        raise RuntimeError('injected failure')

    monkeypatch.setattr(child, '_runMode', failing)

    child.Start()
    finish(child)

    assert child.Status.get() == 'ERROR'
    assert child.Message.get() == 'Error: RuntimeError: injected failure'
    assert 'Stopped after error' not in child.Message.get()
    assert child.ResultFile.get() == '' and os.listdir(tmp_path) == []


def test_an_analysis_failure_of_a_start_run_ends_error_with_the_counts_saved(rigs, tmp_path, monkeypatch):
    child, model = rigs(eyeFn=shifted)
    small(child, 'Eye')

    def failing(*args, **kwargs):
        raise RuntimeError('injected analysis failure')

    monkeypatch.setattr('surf.xilinx.eyescan._EyeScanEngine.openRegion', failing)

    child.Start()
    finish(child)

    assert child.Status.get() == 'ERROR'
    assert 'RuntimeError' in child.Message.get() and 'Stopped after error' not in child.Message.get()
    npz = child.ResultFile.get()
    assert os.path.dirname(npz) == str(tmp_path) and os.path.exists(npz)
    assert files(tmp_path, '.csv') == [os.path.basename(npz)[:-4] + '.csv']
    arrays, meta = es.loadResult(npz)
    assert arrays['eye_bits'].sum() > 0 and arrays['eye_errors'].sum() > 0
    assert child.lastResult.status is es.ScanStatus.ERROR


def test_a_step_equal_to_the_range_gives_three_columns(rigs):
    child, model = rigs(eyeFn=shifted)
    small(child, 'Eye', HorzStep=64, VertStep=127)

    child.Start()
    finish(child)

    assert child.Status.get() == 'OK', child.Message.get()
    assert child.lastResult.horzAxis.tolist() == [-64, 0, 64]


def test_a_knob_changed_while_running_does_not_change_the_running_scan(rigs):
    child, model = rigs(eyeFn=shifted)
    small(child, 'Eye', HorzStep=8)
    child.Start()
    deadline = time.monotonic() + 30
    while child.Status.value() != 'Running' and time.monotonic() < deadline:
        time.sleep(0.01)
    assert child.Status.value() == 'Running'

    child.HorzStep.set(16)
    finish(child)

    assert child.lastResult.meta['horzStep'] == 8
    assert child.HorzStep.value() == 16


def test_stop_with_nothing_running_returns_at_once_and_changes_nothing(rigs):
    child, model = rigs(eyeFn=shifted)
    child.ResultFile.set('/keep/result.npz')

    started = time.monotonic()
    child.Stop()

    assert time.monotonic() - started < 0.5
    assert child.Status.get() == 'Idle'
    assert child.ResultFile.get() == '/keep/result.npz'


def test_start_without_a_hook_ends_not_enabled_in_bounded_time(rigs):
    child, model = rigs(eyeFn=shifted, hook=False)
    small(child, 'Margin')

    child.Start()
    finish(child, 30)

    assert child.Status.get() == 'NOT_ENABLED'
    assert child.Message.get().startswith('Error: NOT_ENABLED')


def test_an_empty_output_dir_saves_into_the_working_directory(rigs, tmp_path, monkeypatch):
    child, model = rigs(eyeFn=shifted)
    small(child, 'Eye')
    child.OutputDir.set('')
    monkeypatch.chdir(tmp_path)

    child.Start()
    finish(child)

    assert os.path.realpath(os.path.dirname(child.ResultFile.get())) == os.path.realpath(tmp_path)
    assert len(files(tmp_path, '.npz')) == 1


def test_the_saved_file_stem_has_only_safe_characters(rigs, tmp_path):
    child, model = rigs(eyeFn=shifted)
    small(child, 'Eye')

    child.Start()
    finish(child)

    name = os.path.basename(child.ResultFile.get())[:-4]
    assert name and all(c.isascii() and (c.isalnum() or c == '_') for c in name)


def test_messages_and_progress_advance_without_a_write_storm(rigs, monkeypatch):
    child, model = rigs(eyeFn=shifted)
    small(child, 'Margin')
    stamps = {'Message': [], 'Progress': []}
    for name in stamps:
        variable = child.variables[name]
        original = variable.set

        def counted(value, *args, _log=stamps[name], _orig=original, **kwargs):
            _log.append(time.monotonic())
            return _orig(value, *args, **kwargs)

        monkeypatch.setattr(variable, 'set', counted)
    seen = set()

    started = time.monotonic()
    child.Start()
    while child._thread.is_alive():
        seen.add(child.Message.value())
        time.sleep(0.01)
    duration = time.monotonic() - started

    assert any('Eye row' in text for text in seen), sorted(seen)
    assert any('cross' in text for text in seen), sorted(seen)
    for name, log in stamps.items():
        assert 3 <= len(log) <= 4.5 * duration + 6, (name, len(log), duration)
    assert child.Progress.value() == pytest.approx(1.0)
    assert child.Message.get() == child.Message.value() and 'saved' in child.Message.get()


def test_throttle_writes_about_four_times_per_second_and_flush_writes_the_last_value():
    from surf.xilinx.eyescan._EyeScan import _Throttle

    written = []
    throttle = _Throttle(written.append)
    end = time.monotonic() + 1.2
    value = 0
    while time.monotonic() < end:
        value += 1
        throttle(value)
        time.sleep(0.005)

    assert 3 <= len(written) <= 7
    assert written[0] == 1
    throttle.flush()
    assert written[-1] == value
    count = len(written)
    throttle.flush()
    assert len(written) == count


def test_a_client_in_another_process_reads_progress_within_half_a_second(tmp_path):
    model = Gthe3EyeModel(requireReset=True, countReads=1, eyeFn=shifted)
    root = _newRoot()
    gt = xil.Gthe3Channel(name='Gt', memBase=model)
    root.add(gt)
    model.seedHardwareLike(gt)
    model.seedNeighbours(gt)
    server = interfaces.ZmqServer(root=root, addr='127.0.0.1', port=0)
    root.addInterface(server)
    root.start()
    scripts = tmp_path / 'client'
    scripts.mkdir()
    script = scripts / 'read_progress.py'
    script.write_text(textwrap.dedent('''
        import json
        import sys
        import time

        import pyrogue.interfaces

        client = pyrogue.interfaces.VirtualClient('127.0.0.1', int(sys.argv[1]))
        node = client.root.Gt.EyeScan.Progress
        times = []
        for _ in range(5):
            start = time.monotonic()
            node.get()
            times.append(time.monotonic() - start)
            time.sleep(0.2)
        client.stop()
        print(json.dumps(times))
    '''))
    try:
        hook = Hook(model)
        child = gt.EyeScan
        child.setRxReset(hook.pulse, hook.ready, settle=0.0, fallWait=0.05, timeout=0.5)
        outDir = tmp_path / 'out'
        child.OutputDir.set(str(outDir))
        setKnobs(child, Mode='Margin', HorzStep=4, VertStep=4, EyeBerFloor=1e-6, BathtubBerFloor=1e-6)
        child.Start()
        deadline = time.monotonic() + 30
        while child.Status.value() != 'Running' and time.monotonic() < deadline:
            time.sleep(0.01)

        done = subprocess.run([sys.executable, '-I', str(script), str(server.port())], capture_output=True,
                              text=True, timeout=120, check=False)
        stillRunning = child.Running.value()
        child.Stop()

        assert done.returncode == 0, done.stderr
        # Rogue prints its version banner around the JSON line
        times = json.loads([line for line in done.stdout.splitlines() if line.startswith('[')][-1])
        assert stillRunning is True
        assert len(times) == 5 and max(times) < 0.5, times
    finally:
        root.stop()


class StuckHook:
    """RX reset hook whose ready never returns True, so the handshake waits for its whole timeout."""

    def __init__(self, model):
        self.model = model

    def pulse(self):
        self.model.pmaReset()

    def ready(self):
        return False


def begin(child, model, mode, **knobs):
    """Knobs of a scan that runs long enough to be stopped; returns the scan words before it."""
    gt = child.parent
    before = seedWords(model, gt)
    setKnobs(child, Mode=mode, **knobs)
    return before


# Writes of one restore: ES_CONTROL, the six scalar roles and the 15 mask words
RESTORE_WRITES = 1 + 6 + 15


def restoreTail(model):
    return model.writes[-RESTORE_WRITES:]


def assertSameRestore(tail, baseline):
    """Same words in the same order, each ending at the same value.

    A write of a shared word carries the live value of the fields not yet
    restored, so only the order of the words and the final value of each are
    fixed.
    """
    assert [addr for addr, _ in tail] == [addr for addr, _ in baseline]
    assert dict(tail) == dict(baseline)


def stopAndTime(child):
    started = time.monotonic()
    child.Stop()
    return time.monotonic() - started


def assertStoppedClean(child, model, before, tmp_path):
    gt = child.parent
    finish(child, 5)
    assert child.Status.get() == 'ABORTED'
    npz = child.ResultFile.get()
    assert os.path.exists(npz) and os.path.exists(npz[:-4] + '.csv')
    assert [name for name in os.listdir(tmp_path) if name.endswith('.png')] == []
    assert child.lastResult.status is es.ScanStatus.ABORTED
    assert model.getField(gt.ES_CONTROL) == 0
    assert seedWords(model, gt) == before
    tail = restoreTail(model)
    # The first write of the restore clears RUN in the ES_CONTROL word
    assert tail[0][0] == model._pos.ctl[0] and not tail[0][1] >> model._pos.ctl[1] & 1
    return tail


@pytest.fixture
def baselineTail(rigs, tmp_path):
    """The restore writes of a scan that ran to its end."""
    child, model = rigs(eyeFn=shifted)
    baseline = tmp_path / 'baseline'
    baseline.mkdir()
    child.OutputDir.set(str(baseline))
    small(child, 'Eye')
    child.Start()
    finish(child)
    assert child.Status.get() == 'OK', child.Message.get()
    return restoreTail(model)


def test_stop_during_the_reset_handshake_saves_an_empty_result_within_a_second(rigs, tmp_path, baselineTail):
    child, model = rigs(eyeFn=shifted, hook=False)
    stuck = StuckHook(model)
    child.setRxReset(stuck.pulse, stuck.ready, settle=0.0, fallWait=0.05, timeout=6.0)
    before = begin(child, model, 'Eye', HorzStep=8, VertStep=16)
    child.Start()
    assert waitFor(lambda: model.resets >= 1, 30)
    time.sleep(0.3)

    elapsed = stopAndTime(child)

    assert elapsed < 1.0
    tail = assertStoppedClean(child, model, before, tmp_path)
    result = child.lastResult
    assert int(result.measured.sum()) == 0 and result.meta['pointsMeasured'] == 0
    assert result.errors.shape == (2, 15, 17) and not result.errors.any()
    assertSameRestore(tail, baselineTail)


def test_stop_during_a_deep_prescale_run_returns_within_a_second(rigs, tmp_path, baselineTail):
    child, model = rigs(eyeFn=shifted, slowFrom=10, slowReads=10 ** 9)
    before = begin(child, model, 'Bathtub', HorzStep=8, BathtubBerFloor=1e-12)
    child.Start()
    assert waitFor(lambda: model.state == 'COUNT' and model.runLog[-1][3] >= 10, 60)
    time.sleep(0.3)
    assert model.state == 'COUNT'

    elapsed = stopAndTime(child)

    assert elapsed < 1.0
    tail = assertStoppedClean(child, model, before, tmp_path)
    assertSameRestore(tail, baselineTail)


def test_stop_in_the_middle_of_the_eye_raster_returns_within_a_second(rigs, tmp_path, baselineTail):
    child, model = rigs(eyeFn=shifted)
    before = begin(child, model, 'Eye', HorzStep=2, VertStep=4)
    child.Start()
    assert waitFor(lambda: child.Progress.value() > 0.2, 120)

    elapsed = stopAndTime(child)

    assert elapsed < 1.0
    tail = assertStoppedClean(child, model, before, tmp_path)
    assertSameRestore(tail, baselineTail)
    assert 0 < int(child.lastResult.measured.sum()) < child.lastResult.measured.size


def test_stop_in_the_middle_of_the_margin_cross_keeps_the_eye_summary(rigs, tmp_path, baselineTail):
    child, model = rigs(eyeFn=shifted)
    before = begin(child, model, 'Margin', HorzStep=16, VertStep=32, EyeBerFloor=1e-6, BathtubBerFloor=1e-9)
    child.Start()
    assert waitFor(lambda: 'cross' in str(child.Message.value()), 120)
    time.sleep(0.3)

    elapsed = stopAndTime(child)

    assert elapsed < 1.0
    tail = assertStoppedClean(child, model, before, tmp_path)
    assertSameRestore(tail, baselineTail)
    result = child.lastResult
    assert result.eye.centre is not None and result.summary.centreHorzCounts is not None
    assert result.horz is not None and not (result.horz.complete and result.vert is not None and result.vert.complete)


def test_an_abort_after_n_points_keeps_exactly_n_points_and_discards_the_interrupted_one(rigs):
    child, model = rigs(eyeFn=shifted)
    child.LineRateGbps.set(6.25)
    kept = 20
    # Run 0 is the activation probe and run 1 is the run at +half that finds the data transitions;
    # every point is two runs (one per UT_SIGN) at this floor
    control = es.ScanControl(isAborted=lambda: len(model.runLog) >= 2 + 2 * kept + 1)

    res = child.runEye(horzStep=8, vertStep=16, floor=1e-3, probeWindow=0.3, control=control)

    assert res.status is es.ScanStatus.ABORTED
    assert int(res.measured.sum()) == kept and res.meta['pointsMeasured'] == kept
    order = np.argsort(np.abs(res.vertAxis), kind='stable')
    flat = [(int(r), int(c)) for r in order for c in range(res.horzAxis.size)]
    assert {(int(r), int(c)) for r, c in zip(*np.nonzero(res.measured))} == set(flat[:kept])
    nextRow, nextCol = flat[kept]
    assert not res.errors[:, nextRow, nextCol].any() and not res.bits[:, nextRow, nextCol].any()
    assert child.Status.get() == 'ABORTED'


def test_a_synchronous_run_during_a_start_run_is_refused_before_any_write(rigs, tmp_path):
    child, model = rigs(eyeFn=shifted, hook=False)
    stuck = StuckHook(model)
    child.setRxReset(stuck.pulse, stuck.ready, settle=0.0, fallWait=0.05, timeout=6.0)
    setKnobs(child, Mode='Eye')
    child.Start()
    assert waitFor(lambda: model.resets >= 1, 30)
    time.sleep(0.2)
    writes = len(model.writes)

    with pytest.raises(es.EyeScanError, match='in progress'):
        child.runEye(horzStep=64)

    assert len(model.writes) == writes
    child.Stop()
    finish(child, 5)


def test_start_during_a_synchronous_run_never_sets_error_and_keeps_the_running_scan(rigs, tmp_path):
    child, model = rigs(eyeFn=shifted)
    small(child, 'Margin')
    outcome = {}
    sync = threading.Thread(target=lambda: outcome.update(result=child.runMargin(
        horzStep=8, vertStep=8, horzRange=32, vertRange=48, floor=1e-6, bathtubFloor=1e-6, outDir=str(tmp_path))))
    sync.start()
    assert waitFor(lambda: child.Status.value() == 'Running', 30)
    seen = []

    child.Start()
    while sync.is_alive() or child._thread.is_alive():
        seen.append(child.Status.value())
        time.sleep(0.01)
    sync.join()

    result = outcome['result']
    assert result.status is es.ScanStatus.OK
    assert 'ERROR' not in seen
    assert 'another eye-scan run is in progress' in child.Message.value()
    assert child.Status.value() == result.status.value
    assert child.lastResult is result
    npz = child.ResultFile.value()
    assert os.path.dirname(npz) == str(tmp_path) and os.path.exists(npz)
    assert files(tmp_path, '.npz') == [os.path.basename(npz)]


def test_two_starts_at_once_run_one_scan_and_keep_its_result(rigs, tmp_path):
    child, model = rigs(eyeFn=shifted, hook=False)
    hook = Hook(model)
    child.setRxReset(hook.pulse, hook.ready, settle=0.0, fallWait=0.05, timeout=0.5)
    small(child, 'Margin')
    child._runEn = True
    barrier = threading.Barrier(2)

    def worker():
        barrier.wait()
        child._run()

    threads = [threading.Thread(target=worker) for _ in range(2)]
    for thread in threads:
        thread.start()
    assert waitFor(lambda: sum(thread.is_alive() for thread in threads) == 1, 30)
    seen = []

    while any(thread.is_alive() for thread in threads):
        seen.append((child.Running.value(), child.Status.value()))
        time.sleep(0.01)

    assert seen and all(running for running, _ in seen)
    assert 'ERROR' not in {status for _, status in seen}
    assert hook.pulses == 1
    assert child.Status.value() == 'OK', child.Message.value()
    npz = child.ResultFile.value()
    assert os.path.exists(npz) and files(tmp_path, '.npz') == [os.path.basename(npz)]
    assert ' | saved ' in child.Message.value() and os.path.basename(npz) in child.Message.value()
    assert child.Running.value() is False


def test_a_start_that_finds_the_run_gate_held_says_it_was_refused(rigs):
    child, model = rigs(eyeFn=shifted)
    child.Message.set('before')
    status, resultFile = child.Status.value(), child.ResultFile.value()
    pulses = model.resets
    assert child._runGate.acquire(blocking=False)
    try:
        child._run()
    finally:
        child._runGate.release()

    assert 'Start refused' in child.Message.value()
    assert child.Status.value() == status and child.ResultFile.value() == resultFile
    assert model.resets == pulses and model.runs == 0


class LockProbe:
    """Scan lock proxy that records the published state at every release."""

    def __init__(self, child):
        self.child = child
        self.lock = child._scanLock
        self.released = []

    def acquire(self, *args, **kwargs):
        return self.lock.acquire(*args, **kwargs)

    def release(self):
        child = self.child
        self.released.append((child.lastResult, child.Status.value(), child.ResultFile.value()))
        self.lock.release()


def test_a_start_run_keeps_the_scan_lock_until_its_result_is_saved(rigs, tmp_path, monkeypatch):
    child, model = rigs(berFn=gauss)
    setKnobs(child, Mode='Bathtub', HorzStep=64, BathtubBerFloor=1e-6, SavePng=False)
    entered, release = threading.Event(), threading.Event()
    original = esDevice.saveResult

    def gated(*args, **kwargs):
        entered.set()
        release.wait(10)
        return original(*args, **kwargs)

    monkeypatch.setattr(esDevice, 'saveResult', gated)
    child.Start()
    try:
        assert entered.wait(30)
        # The step-64 result is published but not yet saved: a synchronous scan is still refused
        assert child.Status.value() == 'OK' and child.lastResult.meta['step'] == 64
        with pytest.raises(es.EyeScanError, match='in progress'):
            child.runBathtub(step=32, floor=1e-6, probeWindow=0.3)
    finally:
        release.set()
    finish(child)

    assert child.lastResult.meta['step'] == 64
    npz = child.ResultFile.value()
    _, meta = es.loadResult(npz)
    assert meta['engine']['step'] == 64
    assert files(tmp_path, '.npz') == [os.path.basename(npz)]
    assert ' | saved ' in child.Message.value() and os.path.basename(npz) in child.Message.value()


def test_a_start_run_keeps_the_scan_lock_until_its_message_is_published(rigs, tmp_path, monkeypatch):
    child, model = rigs(berFn=gauss)
    setKnobs(child, Mode='Bathtub', HorzStep=64, BathtubBerFloor=1e-6, SavePng=False)
    entered, release = threading.Event(), threading.Event()
    original = child._runProcess

    def gated():
        run = original()
        entered.set()
        release.wait(10)
        return run

    monkeypatch.setattr(child, '_runProcess', gated)
    child.Start()
    try:
        assert entered.wait(30)
        # The step-64 result is published and saved but its Message is not written yet: a synchronous scan of
        # a lane that has gone static is still refused, so it cannot become the newer result
        saved = child.ResultFile.value()
        assert child.Status.value() == 'OK' and os.path.exists(saved)
        model.berFn = static
        with pytest.raises(es.EyeScanError, match='in progress'):
            child.runBathtub(step=32, floor=1e-6, probeWindow=0.3)
    finally:
        release.set()
    finish(child)

    assert child.Status.value() == 'OK' and child.lastResult.meta['step'] == 64
    assert child.ResultFile.value() == saved
    assert child.Message.value().startswith('OK:') and os.path.basename(saved) in child.Message.value()
    assert files(tmp_path, '.npz') == [os.path.basename(saved)]


def test_a_scan_publishes_its_result_before_releasing_the_lock(rigs, tmp_path):
    child, model = rigs(berFn=gauss)
    probe = LockProbe(child)
    child._scanLock = probe

    result = child.runBathtub(step=16, floor=1e-6, outDir=str(tmp_path))

    assert len(probe.released) == 1
    published, status, resultFile = probe.released[0]
    assert published is result
    assert status == result.status.value
    assert os.path.dirname(resultFile) == str(tmp_path) and os.path.exists(resultFile)


def test_root_stop_during_a_scan_joins_the_worker_with_the_registers_restored(tmp_path):
    root, gt, model = makeGtRoot(requireReset=True, countReads=1, eyeFn=shifted)
    try:
        hook = Hook(model)
        gt.EyeScan.setRxReset(hook.pulse, hook.ready, settle=0.0, fallWait=0.05, timeout=0.5)
        gt.EyeScan.OutputDir.set(str(tmp_path))
        before = begin(gt.EyeScan, model, 'Eye', HorzStep=2, VertStep=4)
        gt.EyeScan.Start()
        assert waitFor(lambda: gt.EyeScan.Progress.value() > 0.05, 120)

        started = time.monotonic()
        root.stop()
        elapsed = time.monotonic() - started

        assert elapsed < 5.0
        assert not gt.EyeScan._thread.is_alive()
        assert model.getField(gt.ES_CONTROL) == 0
        assert seedWords(model, gt) == before
    finally:
        root.stop()


def test_stop_never_runs_the_version_lookup_after_the_scan_started(rigs, tmp_path, monkeypatch):
    import surf.xilinx.eyescan._EyeScanOutput as output

    lookups = []

    def slowDescribe():
        lookups.append(time.monotonic())
        time.sleep(0.5)
        return 'v-test'

    monkeypatch.setattr(output, '_version', None)
    monkeypatch.setattr(output, '_gitDescribe', slowDescribe)
    child, model = rigs(eyeFn=shifted)
    setKnobs(child, Mode='Eye', HorzStep=2, VertStep=4)
    child.Start()
    assert waitFor(lambda: child.Progress.value() > 0.02, 120)
    requested = time.monotonic()

    elapsed = stopAndTime(child)

    assert elapsed < 1.0
    assert len(lookups) == 1 and lookups[0] < requested
