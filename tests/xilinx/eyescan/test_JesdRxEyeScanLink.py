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
# - Sweep: the JESD204b RX link adapter of the command-line runner
#   (JesdRxEyeScanLink): the lane bits read out of the status registers that
#   span every lane, the per-lane error counters, the raw configuration words,
#   the refused loopback, the lane range check, the RX reset hook on the
#   shared ResetGTs with the DataValid bit of one lane as the ready signal and
#   its timings, and Status and Bathtub runs through runEyeScan.
# - Stimulus: real Rogue transactions against makeJesdLaneRoot (a JesdRx and
#   one GT channel behind LaneMemory, the JesdRx words seeded before the hook
#   is attached), over the emulated GTHE3 lane of the AMC carrier and the
#   emulated GTHE4 lane of the UltraScale+ carriers. The GTHE4 model follows
#   UG576 only; no GTHE4 JESD lane has been scanned on hardware.
# - Checks: counters, raw words and Status fields are reads only and report
#   the lane's own bits as ints and bools; a lane outside the core is refused
#   by the constructor, the ready factory and connectRxReset before any write;
#   a loopback request is refused before any write; the hook keeps the
#   setRxReset timings the adapter chose, pulses ResetGTs and leaves the
#   neighbour bits of the control word as they were; ready follows the
#   DataValid bit of its lane on a fresh read, also on a one-lane core; a
#   Bathtub run ends OK on both families, records the JESD evidence in the
#   saved metadata and leaves Enable and Ctrl unchanged.
# - Timing: countReads=1, a zero settle and a reduced floor and grid keep each
#   run to a few seconds.

import os

import pytest

pr = pytest.importorskip('pyrogue', reason='Eye-scan tests require Rogue/PyRogue')
rogue = pytest.importorskip('rogue', reason='Eye-scan tests require Rogue/PyRogue')

import surf.protocols.jesd204b as jesd  # noqa: E402
import surf.xilinx.eyescan as es  # noqa: E402

from tests.xilinx.eyescan.gt_new_eye_model import makeJesdLaneRoot  # noqa: E402
from tests.xilinx.eyescan.test_EyeScanBathtub import gauss  # noqa: E402
from tests.xilinx.eyescan.test_EyeScanRunner import BATHTUB, run, writes  # noqa: E402

FAMILIES = ['GTHE3', 'GTHE4']

# JesdRx words (byte addresses) of the emulated lane
ENABLE_WORD = 0x00
CTRL_WORD   = 0x10
STATUS_WORD = 0x40          # + 4 * lane
VALID_CNT   = 0x100         # + 4 * lane

# Status word bits (JesdRx register map)
GT_READY   = 1 << 0
DATA_VALID = 1 << 1
ALIGN_ERR  = 1 << 2

# Control word neighbours of ResetGTs (bit 2): SubClass (bit 0) and ScrambleEnable (bit 5)
CTRL_SEED = (1 << 0) | (1 << 5)

# The lane of the seed that is not valid, and the lane with errors
INVALID_LANE = 3
ERROR_LANE   = 1
COUNTERS = {'LinkReady', 'StatusValidCnt', 'DisparityErr', 'NotInTableErr', 'AlignErr', 'PositionErr'}


def seedJesd(mem, numRxLanes=4):
    """Seed the JesdRx words: every lane enabled, every lane valid but INVALID_LANE, ERROR_LANE with errors."""
    mem.words[ENABLE_WORD] = (1 << numRxLanes) - 1
    mem.words[CTRL_WORD] = CTRL_SEED
    for lane in range(numRxLanes):
        word = 0 if lane == INVALID_LANE else DATA_VALID
        if lane == ERROR_LANE:
            word |= GT_READY | ALIGN_ERR | (3 << 10) | (2 << 14)   # DisparityErr 3, NotInTableErr 2
        mem.words[STATUS_WORD + 4 * lane] = word
        mem.words[VALID_CNT + 4 * lane] = 10 + lane


@pytest.fixture
def jesdLanes():
    roots = []

    def make(family='GTHE3', lane=0, numRxLanes=4, **kw):
        kw.setdefault('countReads', 1)
        kw.setdefault('berFn', gauss)
        root, gt, jesdRx, model, mem = makeJesdLaneRoot(
            family=family, lane=lane, numRxLanes=numRxLanes,
            seed=lambda mem: seedJesd(mem, numRxLanes), **kw)
        roots.append(root)
        return gt, jesdRx, model, mem

    yield make
    for root in roots:
        root.stop()


def target(gt, jesdRx, lane=0, number=0):
    return es.EyeScanLane(lane=number, gt=gt, link=jesd.JesdRxEyeScanLink(jesdRx, lane))

#################################################################


def test_counters_report_the_bits_and_counters_of_the_lane_as_ints(jesdLanes):
    gt, jesdRx, model, mem = jesdLanes()
    before = writes(model, mem)
    for lane in range(4):
        counters = jesd.JesdRxEyeScanLink(jesdRx, lane).counters()
        assert set(counters) == COUNTERS
        assert all(type(value) is int for value in counters.values())
        assert counters['LinkReady'] == (0 if lane == INVALID_LANE else 1)
        assert counters['StatusValidCnt'] == 10 + lane
        assert counters['DisparityErr'] == (3 if lane == ERROR_LANE else 0)
        assert counters['NotInTableErr'] == (2 if lane == ERROR_LANE else 0)
        assert counters['AlignErr'] == (1 if lane == ERROR_LANE else 0)
        assert counters['PositionErr'] == 0
    assert writes(model, mem) == before


def test_raw_words_and_status_fields_are_reads_only(jesdLanes):
    gt, jesdRx, model, mem = jesdLanes()
    before = writes(model, mem)
    link = jesd.JesdRxEyeScanLink(jesdRx, ERROR_LANE)
    assert link.rawWords() == {'Enable': '0x0000000F', 'Ctrl': f'0x{CTRL_SEED:08X}'}
    fields = link.statusFields()
    assert set(fields) == {'GTReady', 'DataValid', 'nSync', 'CommaDetected'}
    assert fields['GTReady'] is True and fields['DataValid'] is True
    assert fields['nSync'] is False and fields['CommaDetected'] is False
    assert jesd.JesdRxEyeScanLink(jesdRx, 0).statusFields()['GTReady'] is False
    assert writes(model, mem) == before


@pytest.mark.parametrize('lane', [-1, 4, 7])
def test_a_lane_outside_the_core_is_refused_before_any_write(jesdLanes, lane):
    gt, jesdRx, model, mem = jesdLanes()
    before = writes(model, mem)
    with pytest.raises(ValueError, match=f'4 RX lanes, no lane {lane}'):
        jesd.JesdRxEyeScanLink(jesdRx, lane)
    with pytest.raises(ValueError, match='4 RX lanes'):
        jesd.JesdRxEyeScanLink.laneReady(jesdRx, lane)
    gt.EyeScan.clearRxReset()
    with pytest.raises(ValueError, match='4 RX lanes'):
        jesd.JesdRxEyeScanLink.connectRxReset(gt, jesdRx, lane)
    assert gt.EyeScan.RxResetHook.get() == 'none'
    assert writes(model, mem) == before


def test_the_link_has_no_loopback_so_a_requested_loopback_is_refused_before_any_write(jesdLanes, tmp_path):
    gt, jesdRx, model, mem = jesdLanes()
    link = jesd.JesdRxEyeScanLink(jesdRx, 0)
    assert link.hasLoopback is False
    with pytest.raises(NotImplementedError):
        link.getLoopback()
    before = writes(model, mem)
    with pytest.raises(ValueError, match='no loopback control'):
        run([*BATHTUB, '--loopback', '2'], [target(gt, jesdRx)], tmp_path)
    assert os.listdir(tmp_path) == []
    assert writes(model, mem) == before


@pytest.mark.parametrize('family', FAMILIES)
def test_connect_rx_reset_registers_the_shared_reset_with_the_jesd_timings_and_pulses_it_cleanly(jesdLanes, family):
    gt, jesdRx, model, mem = jesdLanes(family=family, lane=2)
    assert gt.EyeScan.Family.get() == family
    gt.EyeScan.clearRxReset()
    assert gt.EyeScan.RxResetHook.get() == 'none'
    jesd.JesdRxEyeScanLink.connectRxReset(gt, jesdRx, 2)
    hook = gt.EyeScan._hook
    # The adapter's timings: a JESD lane re-synchronizes through the ILAS, the rest are the setRxReset defaults
    assert (hook.settle, hook.timeout, hook.fallWait, hook.hold) == (1.0, 10.0, 0.5, 0.05)
    assert gt.EyeScan.RxResetHook.get() == f'{jesdRx.ResetGTs.path} / callable'
    # Overrides go through
    jesd.JesdRxEyeScanLink.connectRxReset(gt, jesdRx, 2, settle=0.0, timeout=2.0, hold=0.01)
    hook = gt.EyeScan._hook
    assert (hook.settle, hook.timeout, hook.hold) == (0.0, 2.0, 0.01)
    count = len(mem.writes)
    hook.pulse()
    # Bit 2 set then cleared, the neighbour bits kept through the read-modify-write
    assert mem.writes[count:] == [(CTRL_WORD, CTRL_SEED | (1 << 2)), (CTRL_WORD, CTRL_SEED)]
    assert mem.words[CTRL_WORD] == CTRL_SEED


@pytest.mark.parametrize('family', FAMILIES)
def test_ready_follows_the_data_valid_bit_of_its_own_lane(jesdLanes, family):
    gt, jesdRx, model, mem = jesdLanes(family=family, lane=2)
    ready = gt.EyeScan._hook.ready
    assert ready() is True
    mem.words[STATUS_WORD + 4 * 2] &= ~DATA_VALID
    assert ready() is False
    # Another lane's bit does not count
    mem.words[STATUS_WORD + 4 * 3] |= DATA_VALID
    assert ready() is False
    mem.words[STATUS_WORD + 4 * 2] |= DATA_VALID
    assert ready() is True


def test_a_one_lane_core_works_with_the_bitmask_read(jesdLanes):
    gt, jesdRx, model, mem = jesdLanes(numRxLanes=1)
    link = jesd.JesdRxEyeScanLink(jesdRx, 0)
    assert link.counters()['LinkReady'] == 1
    assert link.rawWords()['Enable'] == '0x00000001'
    ready = gt.EyeScan._hook.ready
    assert ready() is True
    mem.words[STATUS_WORD] &= ~DATA_VALID
    assert ready() is False
    with pytest.raises(ValueError, match='1 RX lanes, no lane 1'):
        jesd.JesdRxEyeScanLink(jesdRx, 1)


@pytest.mark.parametrize('family', FAMILIES)
def test_bathtub_ends_ok_and_records_the_jesd_evidence(jesdLanes, family, tmp_path, capsys):
    gt, jesdRx, model, mem = jesdLanes(family=family)
    code, plan = run([*BATHTUB, '--parallel', 'false'], [target(gt, jesdRx)], tmp_path, extraMeta={'bay': 0})
    assert code == 0
    npz = [name for name in os.listdir(plan.folder) if name.endswith('.npz')]
    assert len(npz) == 1
    _, meta = es.loadResult(os.path.join(plan.folder, npz[0]))
    extra = meta['application']
    assert extra['bay'] == 0
    assert set(extra['countersBefore']) == COUNTERS
    assert extra['countersBefore']['LinkReady'] == 1
    assert set(extra['rawBefore']) == {'0x3C', '0x4F', '0x93', '0x97', 'Enable', 'Ctrl'}
    assert meta['engine']['family'] == family
    out = capsys.readouterr().out
    assert 'Lane[0] bathtub status=OK' in out
    assert 'Lane[0] raw words: 0x4F/0x93/0x97 unchanged, 0x3C unchanged except bits 9:8, Enable unchanged, Ctrl unchanged' in out
    # The scan pulsed the shared reset and left the control word as it found it
    assert any(addr == CTRL_WORD and value & (1 << 2) for addr, value in mem.writes)
    assert mem.words[CTRL_WORD] == CTRL_SEED


@pytest.mark.parametrize('family', FAMILIES)
def test_status_mode_prints_the_jesd_fields_and_writes_nothing(jesdLanes, family, tmp_path, capsys):
    gt, jesdRx, model, mem = jesdLanes(family=family)
    before = writes(model, mem)
    code, plan = run([], [target(gt, jesdRx)], tmp_path)
    assert code == 0
    assert plan.folder is None
    assert os.listdir(tmp_path) == []
    assert writes(model, mem) == before
    out = capsys.readouterr().out
    line = next(text for text in out.splitlines() if text.startswith('Lane[0] '))
    for field in ('EyeScanEn=', 'GTReady=False', 'DataValid=True', 'nSync=False', 'CommaDetected=False',
                  f'Hook={jesdRx.ResetGTs.path} / callable', 'LineRate=0'):
        assert field in line
