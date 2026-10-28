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
# - Sweep: Gthe3Channel with the EyeScan child over an emulated GTHE3 DRP
#   memory: package exports, start-up, read-only state decode, width refusal
#   and reset-hook registration.
# - Stimulus: Real Rogue transactions against a rim.Slave holding 16-bit DRP
#   words seeded like a cold KCU1500 lane (RX_DATA_WIDTH raw 6, RX_INT_DATAWIDTH
#   raw 1, RXOUT_DIV raw 1), with a transaction counter on the bus.
# - Checks: root.start() issues zero bus transactions; readState() decodes
#   W=32, range 64 and the status name using reads only; an unsupported width
#   pair is reported with both raw values instead of a guessed width; hook
#   registration validates its arguments and never touches the bus; only
#   Gthe3Channel and Gtye4Channel carry an EyeScan child; the child adds no
#   bus transaction at start, ReadAll or polling; neither the saved config YAML nor the state
#   YAML contains an EyeScan entry and the GT config keys equal the pre-change
#   writable variable names; the scan knobs and summary scalars exist with
#   their defaults, enums and groups, none of them reaches a saved YAML, and a
#   synchronous run publishes its status, openings and centre BER text.
# - Timing: Synchronous memory transactions with a bounded Rogue timeout.

import inspect
import json
import math
import pathlib
import threading
import time

import pytest

pr = pytest.importorskip('pyrogue', reason='Eye-scan tests require Rogue/PyRogue')

import numpy as np  # noqa: E402
rogue = pytest.importorskip('rogue', reason='Eye-scan tests require Rogue/PyRogue')
yaml = pytest.importorskip('yaml', reason='Eye-scan tests require PyYAML')

import surf.xilinx as xil  # noqa: E402
import surf.xilinx.eyescan as es  # noqa: E402
from surf.xilinx.eyescan import EyeScanError, EyeScanPort, GTHE3  # noqa: E402
from surf.xilinx.eyescan._EyeScanEngine import PROBE_WINDOW  # noqa: E402

from tests.xilinx.eyescan.gthe3_eye_model import Gthe3EyeModel, makeGtRoot  # noqa: E402
from tests.xilinx.eyescan.test_EyeScanBathtub import Hook, gauss  # noqa: E402
from tests.xilinx.eyescan.test_EyeScanEye import eye2d  # noqa: E402
from tests.xilinx.eyescan.test_EyeScanMargin import shifted  # noqa: E402

GOLDEN = pathlib.Path(__file__).with_name('gthe3_variables.json')


def buildRoot(eyeScan, initRead=False, pollEn=False):
    """Root with one Gthe3Channel over a seeded model; returns (root, gt, model)."""
    model = Gthe3EyeModel()
    root = pr.Root(pollEn=pollEn, initRead=initRead, initWrite=False, timeout=1.0)
    gt = xil.Gthe3Channel(name='Gt', memBase=model, eyeScan=eyeScan)
    root.add(gt)
    model.seedHardwareLike(gt)
    return root, gt, model


def keysOf(tree, found=None):
    """Every dictionary key at any depth of a parsed YAML document."""
    found = set() if found is None else found
    if isinstance(tree, dict):
        for key, value in tree.items():
            found.add(key)
            keysOf(value, found)
    return found


@pytest.fixture
def lane():
    model = Gthe3EyeModel()
    root = pr.Root(pollEn=False, initRead=False, initWrite=False, timeout=1.0)
    gt = xil.Gthe3Channel(name='Gt', memBase=model)
    root.add(gt)
    log = []
    root.add(pr.LocalVariable(name='Rst', value=False, mode='RW', localSet=lambda value: log.append(value)))
    root.add(pr.LocalVariable(name='RstRo', value=False, mode='RO'))
    root.add(pr.LocalVariable(name='Rdy', value=True, mode='RO'))
    model.seedHardwareLike(gt)
    root.start()
    try:
        yield root, gt, model, log
    finally:
        root.stop()


def test_exports():
    names = ('EyeScan', 'EyeScanFamily', 'GTHE3', 'getFamily', 'EyeScanPort', 'EyeScanEngine',
             'ScanStatus', 'ResetPolicy', 'EyeScanError', 'EyeScanNotActive', 'EyeScanAborted',
             'EyeScanTimeout', 'EyeScanUnlocked')
    assert [n for n in names if not hasattr(es, n)] == []
    assert not hasattr(es, 'np')
    # The eye scan lives in its own subpackage; surf.xilinx keeps only the GT drivers and the subpackage
    assert [n for n in names if hasattr(xil, n)] == []
    assert xil.eyescan is es


def test_set_rx_reset_defaults_follow_the_measured_relock_timing():
    # Relock never exceeded 0.553 s over 40 timed resets, so the ready timeout is
    # 10 x 0.553 rounded up to 0.5 s. The fall was never observed (it ends
    # inside one poll), so the 0.5 s fall wait, the 0.5 s settle and the 0.05 s
    # hold stay as first chosen and the probe window covers a 6 ms time to END.
    params = inspect.signature(es.EyeScan.setRxReset).parameters
    assert params['timeout'].default == 6.0
    assert params['fallWait'].default == 0.5
    assert params['settle'].default == 0.5
    assert params['hold'].default == 0.05
    assert PROBE_WINDOW == 2.0


def test_gthe3_hardware_verified_flag_matches_the_hardware_record():
    # KCU1500 lanes 4-7: the repeat battery passed the repeatability checks within
    # one RX reset and the summed prescale 6 vs 8 check, while the first one-reset
    # battery under the same tolerances failed (lane 6 same-reset decade spread
    # 1.21 counts and one non-monotone tail, lane 4 4 comparable counts); see
    # docs/plans/eyescan/README.md.
    assert GTHE3.hwVerified is True


def test_only_the_gth_and_gty_drivers_have_an_eyescan_child():
    for cls in (xil.Gthe3Channel, xil.Gtye4Channel):
        assert hasattr(cls(name='A'), 'EyeScan')
        assert not hasattr(cls(name='B', eyeScan=False), 'EyeScan')
    for cls in (xil.Gtxe2Channel, xil.Gtpe2Channel):
        assert not hasattr(cls(name='C'), 'EyeScan')


def test_start_issues_no_bus_transactions(lane):
    root, gt, model, log = lane
    assert model.transactions == 0


def test_read_state_decodes_without_writes(lane):
    root, gt, model, log = lane
    model.setField(gt.es_control_status, 0x5)
    model.setField(gt.es_error_count, 123)
    model.setField(gt.es_sample_count, 456)

    state = gt.EyeScan.readState()

    assert state.family == 'GTHE3'
    assert state.bitsPerSample == 32
    assert state.widthError is None
    assert state.rxOutDiv == 2
    assert state.horzHalfRange == 64
    assert state.controlStatus == 0x5
    assert state.controlStatusName == 'END'
    assert state.errorCount == 123
    assert state.sampleCount == 456
    assert state.eyeScanEn == 0 and state.errDetEn == 0
    assert state.rxResetHook == 'none'
    assert model.reads > 0
    assert model.writes == []


@pytest.mark.parametrize('field,raw', [('RX_INT_DATAWIDTH', 2), ('RX_DATA_WIDTH', 1)])
def test_unsupported_width_is_refused(lane, field, raw):
    root, gt, model, log = lane
    model.setField(getattr(gt, field), raw)
    dataRaw = model.getField(gt.RX_DATA_WIDTH)
    intRaw = model.getField(gt.RX_INT_DATAWIDTH)

    state = gt.EyeScan.readState()

    assert state.bitsPerSample is None
    assert f'RX_DATA_WIDTH raw {dataRaw}' in state.widthError
    assert f'RX_INT_DATAWIDTH raw {intRaw}' in state.widthError
    with pytest.raises(EyeScanError) as err:
        EyeScanPort(gt, GTHE3).bitsPerSample()
    assert str(err.value) == state.widthError
    assert model.writes == []


def test_set_rx_reset_registers_without_bus_access(lane):
    root, gt, model, log = lane
    text = f'{root.Rst.path} / {root.Rdy.path}'

    gt.EyeScan.setRxReset(root.Rst, root.Rdy)
    assert gt.EyeScan.RxResetHook.get() == text
    gt.EyeScan.clearRxReset()
    assert gt.EyeScan.RxResetHook.get() == 'none'
    gt.EyeScan.setRxReset(lambda: None, lambda: True)
    assert gt.EyeScan.RxResetHook.get() == 'callable / callable'
    assert model.transactions == 0

    gt.EyeScan.setRxReset(root.Rst, root.Rdy)
    assert gt.EyeScan.readState().rxResetHook == text


def test_set_rx_reset_validates_arguments(lane):
    root, gt, model, log = lane
    with pytest.raises(TypeError):
        gt.EyeScan.setRxReset(5, root.Rdy)
    with pytest.raises(TypeError):
        gt.EyeScan.setRxReset(root.Rst, 5)
    with pytest.raises(ValueError):
        gt.EyeScan.setRxReset(root.RstRo, root.Rdy)
    assert gt.EyeScan.RxResetHook.get() == 'none'
    assert model.transactions == 0


def test_reset_variable_is_pulsed_and_deasserted(lane):
    root, gt, model, log = lane
    gt.EyeScan.setRxReset(root.Rst, root.Rdy, hold=0.0)
    hook = gt.EyeScan._hook
    log.clear()

    hook.pulse()

    assert log == [True, False]
    assert hook.ready() is True


def test_child_groups_keep_it_out_of_saved_data(lane):
    root, gt, model, log = lane
    child = gt.EyeScan
    assert child.inGroup('NoConfig') and child.inGroup('NoState')
    for name in ('Family', 'Status', 'RxResetHook'):
        assert child.variables[name].inGroup('NoConfig'), name


@pytest.mark.parametrize('initRead', [False, True])
def test_start_and_read_all_cost_the_same_with_or_without_the_child(initRead):
    counts = {}
    for eyeScan in (True, False):
        root, gt, model = buildRoot(eyeScan, initRead=initRead)
        with root:
            atStart = model.transactions
            root.ReadAll()
            counts[eyeScan] = (atStart, model.transactions - atStart)
    assert counts[True] == counts[False]
    if initRead:
        assert counts[True][0] > 0
    else:
        assert counts[True][0] == 0
    assert counts[True][1] > 0


def test_polling_adds_no_bus_traffic_for_the_child():
    pollWindow = 2.6
    seen = {}
    for eyeScan in (True, False):
        root, gt, model = buildRoot(eyeScan, pollEn=True)
        # One RO status register is polled so the window has real traffic to compare
        gt.es_control_status.setPollInterval(0.5)
        with root:
            assert model.transactions == 0
            time.sleep(pollWindow)
            seen[eyeScan] = (model.transactions, set(model.readAddrs), model.writes[:])
    assert seen[True][1] == seen[False][1] == {0x153}
    assert seen[True][0] > 0 and seen[False][0] > 0
    assert seen[True][2] == seen[False][2] == []


def test_idle_polling_issues_no_transactions():
    for eyeScan in (True, False):
        root, gt, model = buildRoot(eyeScan, pollEn=True)
        with root:
            time.sleep(2.6)
            assert model.transactions == 0


def test_saved_config_and_state_yaml_exclude_the_child():
    golden = json.loads(GOLDEN.read_text())
    # Commands are never written to the config YAML, every other writable
    # variable of the pre-change driver is
    expected = {row['name'] for row in golden if row['mode'] in ('RW', 'WO') and row['class'] != 'BaseCommand'}
    configKeys = {}
    for eyeScan in (True, False):
        root, gt, model = buildRoot(eyeScan)
        with root:
            config = yaml.safe_load(root.getYaml(readFirst=False, modes=['RW', 'WO'], excGroups='NoConfig'))
            state = yaml.safe_load(root.getYaml(readFirst=False, modes=['RW', 'RO', 'WO'], excGroups='NoState'))
            assert model.transactions == 0
        assert 'EyeScan' not in keysOf(config)
        assert 'EyeScan' not in keysOf(state)
        configKeys[eyeScan] = set(config['Root']['Gt'])
    assert configKeys[True] == configKeys[False] == expected
    assert not configKeys[True] & {'ES_HORZ_OFFSET', 'RX_EYESCAN_VS_CODE', 'RX_EYESCAN_VS_RANGE',
                                   'RX_EYESCAN_VS_NEG_DIR', 'RX_EYESCAN_VS_UT_SIGN'}


NEW_NAMES = ('Mode', 'EyeBerFloor', 'BathtubBerFloor', 'TargetBer', 'HorzStep', 'VertStep', 'Equalizer',
             'Confidence', 'SavePng', 'HorzRange', 'VertRange', 'MaxTimePerRun', 'HorzOpeningUI',
             'VertOpeningCodes', 'BerAtCenter', 'HwVerified', 'LineRateGbps')


def test_every_new_variable_is_a_noconfig_local_variable(lane):
    root, gt, model, log = lane
    for name in NEW_NAMES:
        var = gt.EyeScan.variables[name]
        assert isinstance(var, pr.LocalVariable), name
        assert var.inGroup('NoConfig'), name


def test_only_the_range_and_time_knobs_are_hidden(lane):
    root, gt, model, log = lane
    hidden = {name for name in NEW_NAMES if gt.EyeScan.variables[name].hidden}
    assert hidden == {'HorzRange', 'VertRange', 'MaxTimePerRun'}


def test_knob_defaults_and_modes(lane):
    root, gt, model, log = lane
    child = gt.EyeScan
    assert child.Mode.valueDisp() == 'Margin' and child.Mode.value() == 2
    assert child.Equalizer.valueDisp() == 'dfe'
    assert (child.EyeBerFloor.value(), child.BathtubBerFloor.value(), child.TargetBer.value()) == (1e-6, 1e-9, 1e-12)
    assert (child.HorzStep.value(), child.VertStep.value()) == (2, 4)
    assert child.Confidence.value() == 0.95
    assert child.OutputDir.value() == '.'
    assert child.SavePng.value() is True
    assert (child.HorzRange.value(), child.VertRange.value(), child.MaxTimePerRun.value()) == (0, 0, 30.0)
    for name in ('Mode', 'EyeBerFloor', 'BathtubBerFloor', 'TargetBer', 'HorzStep', 'VertStep', 'Equalizer',
                 'Confidence', 'SavePng', 'HorzRange', 'VertRange', 'MaxTimePerRun'):
        assert child.variables[name].mode == 'RW', name
    for name in ('HorzOpeningUI', 'VertOpeningCodes', 'BerAtCenter', 'HwVerified'):
        assert child.variables[name].mode == 'RO', name
    assert math.isnan(child.HorzOpeningUI.value()) and math.isnan(child.VertOpeningCodes.value())
    assert child.BerAtCenter.value() == ''


def test_mode_accepts_the_three_names_and_refuses_anything_else(lane):
    root, gt, model, log = lane
    mode = gt.EyeScan.Mode
    mode.setDisp('Eye')
    assert mode.value() == 1
    for text in ('Bathtub', 'Margin'):
        mode.setDisp(text)
        assert mode.valueDisp() == text
    mode.setDisp('Eye')
    with pytest.raises(Exception):
        mode.setDisp('Bogus')
    assert mode.valueDisp() == 'Eye'


def test_equalizer_enum_has_dfe_and_lpm_only(lane):
    root, gt, model, log = lane
    gt.EyeScan.Equalizer.setDisp('lpm')
    assert gt.EyeScan.Equalizer.valueDisp() == 'lpm'
    with pytest.raises(Exception):
        gt.EyeScan.Equalizer.setDisp('ctle')
    assert gt.EyeScan.Equalizer.valueDisp() == 'lpm'


def test_hw_verified_follows_the_family_descriptor(lane):
    root, gt, model, log = lane
    assert gt.EyeScan.HwVerified.get() is True
    other = pr.Root(pollEn=False, initRead=False, initWrite=False, timeout=1.0)
    child = es.EyeScan(name='EyeScan', family='GTXE2')
    other.add(child)
    with other:
        assert child.HwVerified.get() is False
    unknown = pr.Root(pollEn=False, initRead=False, initWrite=False, timeout=1.0)
    child = es.EyeScan(name='EyeScan', family='NOPE')
    unknown.add(child)
    with unknown:
        assert child.HwVerified.get() is False


def test_new_variables_never_reach_a_saved_yaml():
    for eyeScan in (True, False):
        root, gt, model = buildRoot(eyeScan)
        with root:
            config = yaml.safe_load(root.getYaml(readFirst=False, modes=['RW', 'WO'], excGroups='NoConfig'))
            state = yaml.safe_load(root.getYaml(readFirst=False, modes=['RW', 'RO', 'WO'], excGroups='NoState'))
            everything = yaml.safe_load(root.getYaml(readFirst=False, modes=['RW', 'RO', 'WO']))
        assert not keysOf(config) & set(NEW_NAMES)
        assert not keysOf(state) & set(NEW_NAMES)
        assert (set(NEW_NAMES) <= keysOf(everything)) is eyeScan


def hookedRoot(**kw):
    root, gt, model = makeGtRoot(requireReset=True, countReads=1, **kw)
    hook = Hook(model)
    gt.EyeScan.setRxReset(hook.pulse, hook.ready, settle=0.0, fallWait=0.05, timeout=0.5)
    return root, gt, model, hook


def test_a_synchronous_eye_publishes_its_openings_and_the_centre_ber_text():
    root, gt, model, hook = hookedRoot(eyeFn=eye2d)
    try:
        child = gt.EyeScan
        child.ResultFile.set('/stale/result.npz')

        res = child.runEye(floor=1e-6, horzStep=8, vertStep=16)

        centre = res.centre
        at = (centre.row, centre.column)
        assert child.Status.get() == res.status.value == 'OK'
        assert child.HorzOpeningUI.value() == pytest.approx(centre.horzOpeningUI)
        assert child.VertOpeningCodes.value() == pytest.approx(centre.vertOpeningCodes)
        assert child.BerAtCenter.value() == es.formatBer(res.ber[at], res.berUpper[at], res.isBound[at], 0.95)
        assert child.HorzOpeningUI.value() > 0.2 and child.VertOpeningCodes.value() > 50
        assert child.ResultFile.get() == ''
    finally:
        root.stop()


def test_a_synchronous_margin_publishes_the_summary():
    root, gt, model, hook = hookedRoot(eyeFn=shifted)
    try:
        child = gt.EyeScan

        res = child.runMargin(floor=1e-6, bathtubFloor=1e-6, horzStep=8, vertStep=8, horzRange=32, vertRange=48,
                              probeWindow=0.3)

        summary = res.summary
        assert child.Status.get() == res.status.value
        assert child.HorzOpeningUI.value() == pytest.approx(summary.horzOpeningUI)
        assert child.VertOpeningCodes.value() == pytest.approx(summary.vertOpeningCodes)
        assert child.BerAtCenter.value() == summary.berAtCenterText
    finally:
        root.stop()


def test_a_synchronous_bathtub_publishes_the_opening_and_a_bound_text():
    root, gt, model, hook = hookedRoot(berFn=gauss)
    try:
        child = gt.EyeScan

        res = child.runBathtub(floor=1e-9, step=16, probeWindow=0.3)

        want = res.openingAtTargetUI if res.extrapolated else res.openingAtFloorUI
        centre = int(np.flatnonzero(res.horzCounts == 0)[0])
        assert child.Status.get() == res.status.value
        assert child.HorzOpeningUI.value() == pytest.approx(want)
        assert math.isnan(child.VertOpeningCodes.value())
        assert child.BerAtCenter.value() == es.formatBer(res.ber[centre], res.berUpper[centre],
                                                         res.isBound[centre], 0.95)
        assert child.BerAtCenter.value() != 'BER = 0.00e+00'
    finally:
        root.stop()


def test_status_reads_running_while_a_synchronous_run_holds_the_scan_lock():
    root, gt, model = makeGtRoot(requireReset=True, countReads=1, berFn=gauss)
    try:
        hook = Hook(model)
        entered, release = threading.Event(), threading.Event()

        def pulse():
            entered.set()
            release.wait(10)
            hook.pulse()

        gt.EyeScan.setRxReset(pulse, hook.ready, settle=0.0, fallWait=0.05, timeout=0.5)
        worker = threading.Thread(target=lambda: gt.EyeScan.runBathtub(step=64, floor=1e-6, probeWindow=0.3))
        worker.start()
        try:
            assert entered.wait(10)
            assert gt.EyeScan.Status.get() == 'Running'
        finally:
            release.set()
            worker.join(60)
        assert gt.EyeScan.Status.get() != 'Running'
    finally:
        root.stop()
