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
# - Sweep: Gthe3Channel register map against the frozen pre-change list, the
#   bit placement of the eight eye-scan additions, the shared-word hazard on
#   DRP words 0x4F and 0x97, and role resolution through EyeScanPort.
# - Stimulus: A fresh Gthe3Channel for the structural checks; real Rogue
#   transactions against an emulated GTHE3 DRP memory seeded like a cold
#   KCU1500 lane for the placement and hazard checks.
# - Checks: Every golden row is present unchanged and the only extra rows are
#   the eight additions; each new RW variable lands on its UG576 bits; an
#   unprimed set clobbers the neighbouring bits and a primed set keeps them;
#   every GTHE3 role resolves and a missing role raises EyeScanError naming it.
# - Timing: Synchronous memory transactions with a bounded Rogue timeout.
#
# Golden list capture (gthe3_variables.json): generated from the pristine
# driver at surf base commit afa6da21a, not from the edited tree. The file
# python/surf/xilinx/_Gthe3Channel.py was taken with `git show` at that commit
# into a temporary directory outside the repository, loaded under a private
# module name, and Gthe3Channel(name='G') was constructed. Every pr.BaseVariable
# in nodes.values() was recorded as a row with the keys name, class (type
# name), offset, bitOffset (list), bitSize (list) and mode, sorted by name.
# The list holds 375 rows and none of the eight additions.
#
# Shared-word neighbours on GTH: DRP word 0x4F holds ES_HORZ_OFFSET [15:4]
# next to FTS_LANE_DESKEW_CFG [3:0], and DRP word 0x97 holds the vertical
# offset fields [10:0] next to RX_AFE_CM_EN [12] and RX_CAPFF_SARC_ENB [11].
# None of those neighbours is a driver variable, so they are checked as raw
# bits. RXCFOK_CFG0 is its own word 0x93 and serves as a canary for stray
# writes, not as a neighbour.

import json
import pathlib

import pytest

pr = pytest.importorskip('pyrogue', reason='Eye-scan tests require Rogue/PyRogue')
rogue = pytest.importorskip('rogue', reason='Eye-scan tests require Rogue/PyRogue')

import surf.xilinx as xil  # noqa: E402
from surf.xilinx.eyescan import EyeScanError, EyeScanPort, GTHE3  # noqa: E402

from tests.xilinx.eyescan.gthe3_eye_model import Gthe3EyeModel  # noqa: E402

GOLDEN = pathlib.Path(__file__).with_name('gthe3_variables.json')

# name: (byte offset, bitOffset, bitSize, mode)
ADDITIONS = {
    'ES_HORZ_OFFSET':        (0x13C, [4], [12], 'RW'),
    'RX_EYESCAN_VS_NEG_DIR': (0x25D, [2], [1],  'RW'),
    'RX_EYESCAN_VS_UT_SIGN': (0x25D, [1], [1],  'RW'),
    'RX_EYESCAN_VS_CODE':    (0x25C, [2], [7],  'RW'),
    'RX_EYESCAN_VS_RANGE':   (0x25C, [0], [2],  'RW'),
    'es_error_count':        (0x544, [0], [16], 'RO'),
    'es_sample_count':       (0x548, [0], [16], 'RO'),
    'es_control_status':     (0x54C, [0], [4],  'RO'),
}

# Names that exist only as commented blocks because their offsets are wrong
MISWIRED = ('RX_AFE_CM_EN', 'RX_CAPFF_SARC_ENB', 'FTS_LANE_DESKEW_CFG')


def rowsOf(device):
    """Rows in the same shape as the golden file, keyed by variable name."""
    rows = {}
    for node in device.nodes.values():
        if isinstance(node, pr.BaseVariable):
            rows[node.name] = {
                'name':      node.name,
                'class':     type(node).__name__,
                'offset':    getattr(node, 'offset', None),
                'bitOffset': list(getattr(node, 'bitOffset', []) or []),
                'bitSize':   list(getattr(node, 'bitSize', []) or []),
                'mode':      node.mode,
            }
    return rows


@pytest.fixture
def lane():
    model = Gthe3EyeModel()
    root = pr.Root(pollEn=False, initRead=False, initWrite=False, timeout=1.0)
    gt = xil.Gthe3Channel(name='Gt', memBase=model)
    root.add(gt)
    model.seedHardwareLike(gt)
    root.start()
    try:
        yield gt, model
    finally:
        root.stop()


def test_golden_list_is_the_base_commit_list():
    golden = json.loads(GOLDEN.read_text())
    names = [row['name'] for row in golden]
    assert len(golden) == 375
    assert len(set(names)) == len(names)
    assert names == sorted(names)
    assert not set(names) & set(ADDITIONS)
    assert not set(names) & set(MISWIRED)
    assert all(set(row) == {'name', 'class', 'offset', 'bitOffset', 'bitSize', 'mode'} for row in golden)


def test_current_list_is_golden_plus_only_the_additions():
    golden = {row['name']: row for row in json.loads(GOLDEN.read_text())}
    current = rowsOf(xil.Gthe3Channel(name='G'))

    missing = sorted(set(golden) - set(current))
    changed = sorted(name for name in golden if name in current and current[name] != golden[name])
    assert missing == []
    assert changed == []

    extra = {name: row for name, row in current.items() if name not in golden}
    assert sorted(extra) == sorted(ADDITIONS)
    for name, (offset, bitOffset, bitSize, mode) in ADDITIONS.items():
        row = extra[name]
        assert (row['offset'], row['bitOffset'], row['bitSize'], row['mode']) == (offset, bitOffset, bitSize, mode), name
        assert row['class'] == 'RemoteVariable', name
    assert len(current) == len(golden) + len(ADDITIONS)


def test_miswired_blocks_stay_absent():
    current = rowsOf(xil.Gthe3Channel(name='G'))
    assert [name for name in MISWIRED if name in current] == []


def test_new_rw_variables_land_on_their_ug_bits(lane):
    gt, model = lane
    # Prime each block with a read so the set keeps the neighbouring bits
    for name in ('ES_HORZ_OFFSET', 'RX_EYESCAN_VS_CODE'):
        getattr(gt, name).get()

    gt.ES_HORZ_OFFSET.set(0xABC)
    assert model.word(0x4F) >> 4 == 0xABC
    assert model.word(0x4F) & 0xF == 0xF

    gt.RX_EYESCAN_VS_NEG_DIR.set(1)
    assert (model.word(0x97) >> 10) & 0x1 == 1
    gt.RX_EYESCAN_VS_UT_SIGN.set(1)
    assert (model.word(0x97) >> 9) & 0x1 == 1
    gt.RX_EYESCAN_VS_CODE.set(0x55)
    assert (model.word(0x97) >> 2) & 0x7F == 0x55
    gt.RX_EYESCAN_VS_RANGE.set(0x2)
    assert model.word(0x97) & 0x3 == 0x2

    # Every field set above is still in place and bits [12:11] are untouched
    assert model.word(0x97) == 0x1800 | (1 << 10) | (1 << 9) | (0x55 << 2) | 0x2


def test_ro_status_words_read_back(lane):
    gt, model = lane
    model.setWord(0x151, 0xBEEF)
    model.setWord(0x152, 0x1234)
    model.setWord(0x153, 0xFFF5)   # only [3:0] belongs to the field

    assert gt.es_error_count.get() == 0xBEEF
    assert gt.es_sample_count.get() == 0x1234
    assert gt.es_control_status.get() == 0x5


def test_unprimed_horz_offset_clobbers_and_primed_preserves(lane):
    gt, model = lane
    assert model.word(0x4F) == 0x000F

    gt.ES_HORZ_OFFSET.set(0x123)
    assert model.word(0x4F) & 0xF == 0x0       # unprimed set loses the FTS bits

    model.setWord(0x4F, 0x000F)
    gt.ES_HORZ_OFFSET.get()
    gt.ES_HORZ_OFFSET.set(0x123)
    assert model.word(0x4F) & 0xF == 0xF       # primed set keeps them
    assert model.word(0x4F) >> 4 == 0x123


def test_unprimed_ut_sign_clobbers_and_primed_preserves(lane):
    gt, model = lane
    assert (model.word(0x97) >> 11) & 0x3 == 0x3

    gt.RX_EYESCAN_VS_UT_SIGN.set(1)
    assert (model.word(0x97) >> 11) & 0x3 == 0x0   # unprimed set loses bits [12:11]

    model.setWord(0x97, 0x1800)
    gt.RX_EYESCAN_VS_UT_SIGN.get()
    gt.RX_EYESCAN_VS_UT_SIGN.set(1)
    assert (model.word(0x97) >> 11) & 0x3 == 0x3   # primed set keeps them
    assert (model.word(0x97) >> 9) & 0x1 == 0x1


def test_canary_word_is_never_written(lane):
    gt, model = lane
    gt.ES_HORZ_OFFSET.get()
    gt.ES_HORZ_OFFSET.set(0x7FF)
    gt.RX_EYESCAN_VS_CODE.get()
    gt.RX_EYESCAN_VS_CODE.set(0x7F)
    assert model.word(0x93) == 0x4000
    assert 0x93 not in {addr for addr, _ in model.writes}


def test_port_resolves_every_gthe3_role():
    gt = xil.Gthe3Channel(name='G')
    port = EyeScanPort(gt, GTHE3)

    for role, name in GTHE3.regs.items():
        assert port.var(role) is getattr(gt, name), role
    for role, (name, count) in GTHE3.arrays.items():
        words = port.words(role)
        assert len(words) == count, role
        assert words == [getattr(gt, name)[i] for i in range(count)], role


def test_port_names_the_missing_role():
    port = EyeScanPort(pr.Device(name='Empty'), GTHE3)
    with pytest.raises(EyeScanError) as err:
        port.var('horzOffset')
    assert 'horzOffset' in str(err.value)
    assert 'ES_HORZ_OFFSET' in str(err.value)
