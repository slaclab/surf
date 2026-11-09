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
# - Sweep: the Gtye3Channel, Gthe4Channel, Gtye3Common and Gthe4Common register
#   maps, written from UG578 v1.4 Tables B-1 and B-2 and UG576 v1.7.1 Tables C-1
#   and C-2 without hardware: every variable against its golden list, the
#   eye-scan fields the engine drives against the pinned DRP positions, the
#   enums the drivers share with Gtye4Channel, the two divider tables, the
#   shared-word read-modify-write hazard, and role resolution through
#   EyeScanPort.
# - Stimulus: a fresh driver for the structural checks; real Rogue
#   transactions against the emulated GTYE3 and GTHE4 DRP memories for the
#   placement and hazard checks.
# - Checks: the golden rows are present unchanged and the child adds none; the
#   eye-scan fields of both channel drivers sit at the GTYE4 addresses; the
#   GTHE4 divider enums stop at 16 and the GTYE3 ones reach 32; every other
#   enum equals the Gtye4Channel enum of the same name; a primed set keeps the
#   neighbouring bits of DRP words 0x4F and 0x97; the GTHE4 scan never writes
#   the GTY-only mask words 5 to 9; every role resolves and a missing role
#   raises EyeScanError naming it.
# - Timing: synchronous memory transactions with a bounded Rogue timeout.
#
# Golden list capture (gtye3_variables.json, gthe4_variables.json): each list
# was captured from the new driver constructed with eyeScan=False. Every
# pr.BaseVariable in nodes.values() was recorded as a row with the keys name,
# class (type name), offset, bitOffset (list), bitSize (list) and mode, sorted
# by name. The lists hold 493 and 514 rows. The drivers themselves were
# generated row by row from the user-guide tables and every field was compared
# with its table row before the lists were captured, so the lists pin the
# transcription rather than a hardware observation.

import json
import pathlib

import pytest

pr = pytest.importorskip('pyrogue', reason='Eye-scan tests require Rogue/PyRogue')
rogue = pytest.importorskip('rogue', reason='Eye-scan tests require Rogue/PyRogue')

import surf.xilinx as xil  # noqa: E402
from surf.xilinx.eyescan import GTHE4, GTYE3, EyeScanError, EyeScanPort  # noqa: E402

from tests.xilinx.eyescan.gt_new_eye_model import Gthe4EyeModel, Gtye3EyeModel  # noqa: E402
from tests.xilinx.eyescan.gthe3_eye_model import fieldOf  # noqa: E402
from tests.xilinx.eyescan.gtye4_eye_model import maskVars  # noqa: E402
from tests.xilinx.eyescan.test_Gthe3Registers import rowsOf  # noqa: E402

HERE = pathlib.Path(__file__).parent

CHANNELS = {
    'GTYE3': (xil.Gtye3Channel, Gtye3EyeModel, GTYE3, HERE / 'gtye3_variables.json', 493),
    'GTHE4': (xil.Gthe4Channel, Gthe4EyeModel, GTHE4, HERE / 'gthe4_variables.json', 514),
}

COMMONS = {
    'GTYE3': (xil.Gtye3Common, 70),
    'GTHE4': (xil.Gthe4Common, 79),
}

# role: (DRP word, lsb, width), the GTYE4 layout both new channel drivers share
SCAN_FIELDS = {
    'ES_EYE_SCAN_EN':        (0x3C, 8, 1),
    'ES_ERRDET_EN':          (0x3C, 9, 1),
    'ES_CONTROL':            (0x3C, 10, 6),
    'ES_PRESCALE':           (0x3C, 0, 5),
    'ES_HORZ_OFFSET':        (0x4F, 4, 12),
    'RX_EYESCAN_VS_CODE':    (0x97, 2, 7),
    'RX_EYESCAN_VS_RANGE':   (0x97, 0, 2),
    'RX_EYESCAN_VS_NEG_DIR': (0x97, 10, 1),
    'RX_EYESCAN_VS_UT_SIGN': (0x97, 9, 1),
    'RX_DATA_WIDTH':         (0x03, 5, 4),
    'RX_INT_DATAWIDTH':      (0x66, 0, 2),
    'RXOUT_DIV':             (0x63, 0, 3),
    'es_error_count':        (0x251, 0, 16),
    'es_sample_count':       (0x252, 0, 16),
    'es_control_status':     (0x253, 0, 4),
    'RX_AFE_CM_EN':          (0x97, 12, 1),
    'RX_CAPFF_SARC_ENB':     (0x97, 11, 1),
    'FTS_LANE_DESKEW_CFG':   (0x4F, 0, 4),
}

MASK_WORDS = {
    'ES_QUALIFIER':  [0x3F, 0x40, 0x41, 0x42, 0x43, 0xE7, 0xE8, 0xE9, 0xEA, 0xEB],
    'ES_QUAL_MASK':  [0x44, 0x45, 0x46, 0x47, 0x48, 0xEC, 0xED, 0xEE, 0xEF, 0xF0],
    'ES_SDATA_MASK': [0x49, 0x4A, 0x4B, 0x4C, 0x4D, 0xF1, 0xF2, 0xF3, 0xF4, 0xF5],
}

# Eye-scan read-only capture words: UG576 Table 4-21 gives the UltraScale+ GTH five words each,
# UG578 Table 4-22 gives the GTY ten
CAPTURE_WORDS = {f'es_rdata_byte{i}': a for i, a in enumerate([0x258, 0x257, 0x256, 0x255, 0x254, 0x288, 0x289, 0x28A, 0x28B, 0x28C])}
CAPTURE_WORDS.update({f'es_sdata_byte{i}': a for i, a in enumerate([0x25D, 0x25C, 0x25B, 0x25A, 0x259, 0x283, 0x284, 0x285, 0x286, 0x287])})
CAPTURE_COUNT = {'GTYE3': 10, 'GTHE4': 5}


@pytest.fixture(params=sorted(CHANNELS))
def chan(request):
    return request.param


@pytest.fixture
def lane(chan):
    cls, modelCls, family, golden, count = CHANNELS[chan]
    model = modelCls()
    root = pr.Root(pollEn=False, initRead=False, initWrite=False, timeout=1.0)
    gt = cls(name='Gt', memBase=model)
    root.add(gt)
    model.seedHardwareLike(gt)
    model.seedNeighbours(gt)
    root.start()
    try:
        yield gt, model, family
    finally:
        root.stop()


def enumsOf(device):
    return {node.name: node.enum for node in device.nodes.values()
            if isinstance(node, pr.RemoteVariable) and node.enum is not None}


# ----------------------------------------------------------------------
# Golden lists
# ----------------------------------------------------------------------
def test_golden_lists_are_sorted_unique_and_complete(chan):
    cls, modelCls, family, golden, count = CHANNELS[chan]
    rows = json.loads(golden.read_text())
    names = [row['name'] for row in rows]
    assert len(rows) == count
    assert names == sorted(names) and len(set(names)) == len(names)
    assert all(set(row) == {'name', 'class', 'offset', 'bitOffset', 'bitSize', 'mode'} for row in rows)
    assert 'EyeScan' not in names


def test_the_driver_equals_its_golden_list_with_and_without_the_child(chan):
    cls, modelCls, family, golden, count = CHANNELS[chan]
    expected = {row['name']: row for row in json.loads(golden.read_text())}
    for eyeScan in (True, False):
        gt = cls(name='G', eyeScan=eyeScan)
        assert rowsOf(gt) == expected
        assert ('EyeScan' in gt.nodes) is eyeScan


@pytest.mark.parametrize('name', sorted(COMMONS))
def test_the_common_driver_has_only_user_guide_rows(name):
    cls, count = COMMONS[name]
    dev = cls(name='C')
    # The three built-in device variables (enable, ReadDevice, WriteDevice) are not register rows
    rows = {name: row for name, row in rowsOf(dev).items() if row['class'] == 'RemoteVariable'}
    assert len(rows) == count
    assert len(rowsOf(dev)) == count + 3
    assert not hasattr(dev, 'EyeScan')
    # Every QPLL word is a 16-bit DRP word behind a 32-bit window
    assert all(row['offset'] % 4 == 0 and max(row['bitOffset']) + max(row['bitSize']) <= 16 for row in rows.values())
    assert {'QPLL0_CFG0', 'QPLL1_CFG0', 'QPLL0_FBDIV', 'QPLL1_FBDIV', 'QPLL0_REFCLK_DIV', 'QPLL1_REFCLK_DIV'} <= set(rows)
    assert dev.QPLL0CLKOUT_RATE.enum == dev.QPLL1CLKOUT_RATE.enum == {0: 'HALF', 1: 'FULL'}


# ----------------------------------------------------------------------
# Eye-scan fields and the neighbouring bits
# ----------------------------------------------------------------------
def test_every_scan_field_sits_at_its_gtye4_position(chan):
    cls = CHANNELS[chan][0]
    gt = cls(name='G')
    for name, field in SCAN_FIELDS.items():
        assert fieldOf(getattr(gt, name)) == field, name
    for name, words in MASK_WORDS.items():
        assert [fieldOf(var) for var in maskVars(gt, name)] == [(word, 0, 16) for word in words], name
    for name, word in CAPTURE_WORDS.items():
        index = int(name[-1])
        if index >= CAPTURE_COUNT[chan]:
            assert not hasattr(gt, name), name
            continue
        var = getattr(gt, name)
        assert fieldOf(var) == (word, 0, 16) and var.mode == 'RO', name
    assert gt.RX_PRBS_ERR_CNT.offset == 0x25E << 2 and gt.RX_PRBS_ERR_CNT.bitSize == [16, 16]


def test_every_role_resolves_and_a_missing_role_is_named(chan):
    cls, modelCls, family, golden, count = CHANNELS[chan]
    gt = cls(name='G')
    port = EyeScanPort(gt, family)
    for role, name in family.regs.items():
        assert port.var(role) is getattr(gt, name), role
    for role, (name, nWords) in family.arrays.items():
        words = port.words(role)
        assert len(words) == nWords, role
        assert words == [getattr(gt, name.format(i)) for i in range(nWords)], role

    with pytest.raises(EyeScanError) as err:
        EyeScanPort(pr.Device(name='Empty'), family).var('horzOffset')
    assert 'horzOffset' in str(err.value) and 'ES_HORZ_OFFSET' in str(err.value)


def test_gtye3_word_0xfb_overlap_is_declared():
    # UG578 v1.4 Table B-2 puts TX_FIFO_BYP_EN and TX_PI_DIV2_MODE_B both on bit 0 of word 0xFB
    gt = xil.Gtye3Channel(name='G')
    assert fieldOf(gt.TX_FIFO_BYP_EN) == fieldOf(gt.TX_PI_DIV2_MODE_B) == (0xFB, 0, 1)
    assert gt.TX_FIFO_BYP_EN.overlapEn and gt.TX_PI_DIV2_MODE_B.overlapEn
    others = [n for n in xil.Gtye3Channel(name='H').nodes.values() if isinstance(n, pr.RemoteVariable) and n.overlapEn]
    assert sorted(n.name for n in others) == ['TX_FIFO_BYP_EN', 'TX_PI_DIV2_MODE_B']
    assert not any(n.overlapEn for n in xil.Gthe4Channel(name='I').nodes.values() if isinstance(n, pr.RemoteVariable))


def test_gthe4_scan_words_are_the_five_gth_words(chan):
    cls, modelCls, family, golden, count = CHANNELS[chan]
    gt = cls(name='G')
    port = EyeScanPort(gt, family)
    scanned = {var.offset >> 2 for role in family.arrays for var in port.words(role)}
    gtyOnly = {word for words in MASK_WORDS.values() for word in words[5:]}
    if chan == 'GTHE4':
        assert family.busWidth == 40 and not scanned & gtyOnly
        # The GTY-only words stay plain driver registers
        assert all(hasattr(gt, f'{name}{i}') for name in MASK_WORDS for i in range(5, 10))
    else:
        assert family.busWidth == 80 and gtyOnly <= scanned


def test_new_rw_fields_land_on_their_bits_with_a_primed_set(lane):
    gt, model, family = lane
    for name in ('ES_HORZ_OFFSET', 'RX_EYESCAN_VS_CODE'):
        getattr(gt, name).get()

    gt.ES_HORZ_OFFSET.set(0xABC)
    assert model.word(0x4F) >> 4 == 0xABC
    assert model.word(0x4F) & 0xF == 0xF                  # FTS_LANE_DESKEW_CFG kept

    gt.RX_EYESCAN_VS_NEG_DIR.set(1)
    gt.RX_EYESCAN_VS_UT_SIGN.set(1)
    gt.RX_EYESCAN_VS_CODE.set(0x55)
    gt.RX_EYESCAN_VS_RANGE.set(0x2)
    assert (model.word(0x97) >> 11) & 0x1F == 0x1F         # bits 15:11 of the seed kept
    assert model.word(0x97) & 0x7FF == (1 << 10) | (1 << 9) | (0x55 << 2) | 0x2


def test_ro_status_words_read_back(lane):
    gt, model, family = lane
    model.setWord(0x251, 0xBEEF)
    model.setWord(0x252, 0x1234)
    model.setWord(0x253, 0xFFF5)

    assert gt.es_error_count.get() == 0xBEEF
    assert gt.es_sample_count.get() == 0x1234
    assert gt.es_control_status.get() == 0x5
    assert model.writes == []


# ----------------------------------------------------------------------
# Enums against the GTYE4 driver and the user guides
# ----------------------------------------------------------------------
def test_divider_enums_follow_the_user_guide(chan):
    gt = CHANNELS[chan][0](name='G')
    if chan == 'GTHE4':
        # UG576 Table 4-20: 1, 2, 4, 8 and 16 (no /32 divider on the GTH)
        assert gt.RXOUT_DIV.enum == gt.TXOUT_DIV.enum == {0: '1', 1: '2', 2: '4', 3: '8', 4: '16'}
    else:
        assert gt.RXOUT_DIV.enum == gt.TXOUT_DIV.enum == {0: '1', 1: '2', 2: '4', 3: '8', 4: '16', 5: '32'}
    assert gt.RX_DATA_WIDTH.enum == {0: '-', 2: '16', 3: '20', 4: '32', 5: '40', 6: '64', 7: '80', 8: '128', 9: '160'}
    assert gt.RX_INT_DATAWIDTH.enum is None


def test_the_other_enums_equal_the_gtye4_enums(chan):
    gt = CHANNELS[chan][0](name='G')
    ref = enumsOf(xil.Gtye4Channel(name='R'))
    mine = enumsOf(gt)
    familySpecific = {'RXOUT_DIV', 'TXOUT_DIV', 'RX_PROGDIV_CFG', 'TX_PROGDIV_CFG', 'CPLL_FBDIV', 'CPLL_REFCLK_DIV',
                      'SATA_CPLL_CFG', 'TX_DATA_WIDTH'}
    shared = (set(mine) & set(ref)) - familySpecific
    assert len(shared) >= 45
    for name in sorted(shared):
        assert mine[name] == ref[name], name
    # The only enum on a variable Gtye4Channel does not have decodes TXPI_PPMCLK_SEL (UG table)
    assert set(mine) - set(ref) == {'TXPI_PPMCLK_SEL'}
    assert mine['TXPI_PPMCLK_SEL'] == {0: 'TXUSRCLK', 1: 'TXUSRCLK2'}


def test_gthe4_enums_carry_the_ultrascale_plus_gth_encodings():
    gt = xil.Gthe4Channel(name='G')
    # UG576 Table C-2: the full CPLL divider tables and the 6 GHz SATA VCO
    assert gt.CPLL_FBDIV.enum == {0: '2', 1: '3', 2: '4', 3: '5', 5: '6', 6: '8', 7: '10', 13: '12', 14: '16', 15: '20', 16: '1'}
    assert gt.CPLL_REFCLK_DIV.enum == gt.CPLL_FBDIV.enum
    assert gt.SATA_CPLL_CFG.enum == {0: 'VCO_3000MHZ', 1: 'VCO_1500MHZ', 2: 'VCO_750MHZ', 3: 'VCO_6000MHZ'}
    # The PROGDIV table is the GTYE4 one (binary pairs in UG576 Table C-2 decode to the same words)
    assert gt.RX_PROGDIV_CFG.enum == gt.TX_PROGDIV_CFG.enum
    assert gt.RX_PROGDIV_CFG.enum[57880] == '16.5' and gt.RX_PROGDIV_CFG.enum[24654] == '128'
    assert gt.RX_PROGDIV_CFG.enum[57862] == '132'


def test_gtye3_progdiv_enums_follow_ug578_table_b2():
    gt = xil.Gtye3Channel(name='G')
    # UG578 Table B-2 lists the UltraScale encodings (49648 for 5, 49672 for 16.5), unlike the
    # UltraScale+ table of Gtye4Channel
    expected = {32768: '0', 57744: '4', 49648: '5', 57728: '8', 57760: '10', 57730: '16', 49672: '16.5',
                57762: '20', 57734: '32', 49800: '33', 57766: '40', 57742: '64', 50056: '66', 57743: '80',
                57775: '100'}
    assert gt.RX_PROGDIV_CFG.enum == gt.TX_PROGDIV_CFG.enum == expected
    assert gt.SATA_CPLL_CFG.enum == {0: 'VCO_3000MHZ', 1: 'VCO_1500MHZ', 2: 'VCO_750MHZ'}
    assert gt.CPLL_FBDIV.enum == {0: '2', 1: '3', 2: '4', 3: '5', 16: '1'}
