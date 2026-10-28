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
# - Sweep: the GTHE3 and GTYE4 eye-scan families over their emulated DRP
#   models, through the EyeScan child each driver adds to itself: role
#   resolution, neighbour bits, state machine, bit counts, mask words, the width
#   and divider tables, abort, idempotency, concurrency, start-up, ReadAll,
#   polling, saved YAML, the variable lists against their golden files, the
#   per-family DRP address and bit-overlap table, and the descriptor invariants.
# - Stimulus: real Rogue transactions against Gthe3EyeModel and Gtye4EyeModel
#   with the seeded dual-Dirac BER model of the bathtub tests and a callable
#   RX reset hook. Every scan passes lineRateGbps explicitly so no test depends
#   on the line-rate measurement.
# - Checks: a bathtub ends OK with the family, the sample width and the
#   RXOUT_DIV of the seed in its meta, writes every mask word of the sampler
#   (five per array on GTHE3, ten on GTYE4) with the exact width pattern, keeps
#   the bits that share a DRP word with a scan field, and leaves every scan
#   register at its pre-scan value; a pair outside the width table or a divider
#   outside the divider table is refused with the raw values and no write; a
#   second scan on a busy transceiver is refused.
# - Timing: countReads=1 and a zero settle keep the emulated runs short; the
#   model steps on status reads, so no test waits on real hardware time. The
#   polling tests watch the bus for 2.6 s of wall-clock time.
#
# Golden list capture (gtye4_variables.json): generated from the pristine
# driver at surf commit 6487f1514, not from the edited tree. The file
# python/surf/xilinx/_Gtye4Channel.py was taken with `git show` at that commit
# into a temporary directory outside the repository, loaded under a private
# module name, and Gtye4Channel(name='G') was constructed. Every pr.BaseVariable
# in nodes.values() was recorded as a row with the keys name, class (type
# name), offset, bitOffset (list), bitSize (list) and mode, sorted by name.
# The list holds 526 rows and none for the EyeScan child.

import inspect
import json
import pathlib
import time
from types import SimpleNamespace

import pytest

pr = pytest.importorskip('pyrogue', reason='Eye-scan tests require Rogue/PyRogue')

import numpy as np  # noqa: E402
rogue = pytest.importorskip('rogue', reason='Eye-scan tests require Rogue/PyRogue')
yaml = pytest.importorskip('yaml', reason='Eye-scan tests require PyYAML')

import surf.ethernet.gige as gige  # noqa: E402
import surf.xilinx as xil  # noqa: E402
import surf.xilinx.eyescan as es  # noqa: E402
from surf.xilinx.eyescan import (  # noqa: E402
    EyeScanError,
    EyeScanPort,
    ScanControl,
    ScanStatus,
    decodeControlStatus,
    getFamily,
)
from surf.xilinx.eyescan._EyeScanFamilies import FAMILIES, GTHE3, GTYE4, PHASE_RULES, UNSUPPORTED_FAMILIES  # noqa: E402
from surf.xilinx.eyescan._EyeScanMath import bitsPerRun, internalWidth, maskWords, sdataMask  # noqa: E402

from tests.xilinx.eyescan.gthe3_eye_model import Gthe3EyeModel, fieldOf, makeGtRoot  # noqa: E402
from tests.xilinx.eyescan.gtye4_eye_model import MASK_WORDS, Gtye4EyeModel, makeGtyRoot, maskVars  # noqa: E402
from tests.xilinx.eyescan.test_EyeScanBathtub import Hook, gauss, seedWords  # noqa: E402
from tests.xilinx.eyescan.test_EyeScanDevice import keysOf  # noqa: E402
from tests.xilinx.eyescan.test_Gthe3Registers import ADDITIONS, rowsOf  # noqa: E402

HERE = pathlib.Path(__file__).parent

# Everything that differs between the two families, keyed by family name.
# status is the (error count, sample count, control status) DRP words.
FAMS = {
    'GTHE3': SimpleNamespace(
        name='GTHE3', driver=xil.Gthe3Channel, model=Gthe3EyeModel, make=makeGtRoot,
        golden=HERE / 'gthe3_variables.json', additions=ADDITIONS, maskWords=5, W=32,
        status=(0x151, 0x152, 0x153), scanWords=24),
    'GTYE4': SimpleNamespace(
        name='GTYE4', driver=xil.Gtye4Channel, model=Gtye4EyeModel, make=makeGtyRoot,
        golden=HERE / 'gtye4_variables.json', additions={}, maskWords=10, W=64,
        status=(0x251, 0x252, 0x253), scanWords=39),
}

# role: (DRP word, lsb, width) shared by both families
COMMON_TABLE = {
    'eyeScanEn':      (0x3C, 8, 1),
    'errDetEn':       (0x3C, 9, 1),
    'control':        (0x3C, 10, 6),
    'prescale':       (0x3C, 0, 5),
    'horzOffset':     (0x4F, 4, 12),
    'vsCode':         (0x97, 2, 7),
    'vsRange':        (0x97, 0, 2),
    'vsNegDir':       (0x97, 10, 1),
    'vsUtSign':       (0x97, 9, 1),
    'rxDataWidth':    (0x03, 5, 4),
    'rxIntDataWidth': (0x66, 0, 2),
    'rxOutDiv':       (0x63, 0, 3),
}

# role: DRP words of the mask arrays, word 0 first
MASK_TABLE = {
    'GTHE3': {
        'qualifier': [0x3F, 0x40, 0x41, 0x42, 0x43],
        'qualMask':  [0x44, 0x45, 0x46, 0x47, 0x48],
        'sdataMask': [0x49, 0x4A, 0x4B, 0x4C, 0x4D],
    },
    'GTYE4': {
        'qualifier': [0x3F, 0x40, 0x41, 0x42, 0x43, 0xE7, 0xE8, 0xE9, 0xEA, 0xEB],
        'qualMask':  [0x44, 0x45, 0x46, 0x47, 0x48, 0xEC, 0xED, 0xEE, 0xEF, 0xF0],
        'sdataMask': [0x49, 0x4A, 0x4B, 0x4C, 0x4D, 0xF1, 0xF2, 0xF3, 0xF4, 0xF5],
    },
}

# GTYE4 words where two pre-existing driver variables share bits; none is a scan word
GTYE4_OVERLAP_WORDS = {0x11, 0x60, 0xD5}


@pytest.fixture(params=sorted(FAMS))
def fam(request):
    return FAMS[request.param]


@pytest.fixture
def rigs():
    roots = []

    def make(fam, berFn=gauss, hooked=True, **kw):
        kw.setdefault('requireReset', True)
        kw.setdefault('countReads', 1)
        root, gt, model = fam.make(berFn=berFn, **kw)
        roots.append(root)
        hook = None
        if hooked:
            hook = Hook(model)
            gt.EyeScan.setRxReset(hook.pulse, hook.ready, settle=0.0, fallWait=0.05, timeout=0.5)
        return root, gt, model, hook
    yield make
    for root in roots:
        root.stop()


def build(fam, eyeScan, initRead=False, pollEn=False):
    """Root with one driver over a seeded model; returns (root, gt, model)."""
    model = fam.model()
    root = pr.Root(pollEn=pollEn, initRead=initRead, initWrite=False, timeout=1.0)
    gt = fam.driver(name='Gt', memBase=model, eyeScan=eyeScan)
    root.add(gt)
    model.seedHardwareLike(gt)
    return root, gt, model


def rawCode(codes, value):
    """The raw register code whose decoded value is ``value``."""
    return next(raw for raw, decoded in codes.items() if decoded == value)


def scanWords(port):
    """DRP words of every driver variable a scan reads or writes."""
    words = {fieldOf(port.var(role))[0] for role in port.family.regs}
    for role in port.family.arrays:
        words.update(var.offset >> 2 for var in port.words(role))
    return words


def bitOwners(device):
    """DRP word to bit position to the names of the variables that occupy it."""
    owners = {}
    for node in device.nodes.values():
        if not isinstance(node, pr.RemoteVariable):
            continue
        offsets = node.bitOffset if isinstance(node.bitOffset, list) else [node.bitOffset]
        sizes = node.bitSize if isinstance(node.bitSize, list) else [node.bitSize]
        for lsb, size in zip(offsets, sizes):
            for bit in range(size):
                pos = 8 * (node.offset & 3) + lsb + bit
                if pos >= 16:
                    break
                owners.setdefault(node.offset >> 2, {}).setdefault(pos, set()).add(node.name)
    return owners


# ----------------------------------------------------------------------
# Tracer: one emulated GTYE4 bathtub through the auto-added child
# ----------------------------------------------------------------------
def test_gtye4_bathtub_runs_end_to_end_through_the_auto_added_child():
    root, gt, model = makeGtyRoot(requireReset=True, berFn=gauss, countReads=1)
    try:
        before = seedWords(model, gt)
        hook = Hook(model)
        gt.EyeScan.setRxReset(hook.pulse, hook.ready, settle=0.0, fallWait=0.05, timeout=0.5)

        res = gt.EyeScan.runBathtub(step=8, lineRateGbps=6.25, probeWindow=0.3)

        assert res.status is ScanStatus.OK, res.message
        assert res.meta['family'] == 'GTYE4'
        assert res.meta['bitsPerSample'] == 64 and res.meta['rxOutDiv'] == 2
        assert np.array_equal(res.horzCounts, np.arange(-64, 65, 8))
        assert hook.pulses == 1
        assert model.phaseViolations == 0

        expected = {
            'ES_SDATA_MASK': maskWords(sdataMask(64, 80), MASK_WORDS),
            'ES_QUAL_MASK':  [0xFFFF] * MASK_WORDS,
            'ES_QUALIFIER':  [0x0000] * MASK_WORDS,
        }
        assert expected['ES_SDATA_MASK'] == [0xFFFF, 0, 0, 0, 0] + [0xFFFF] * 5
        written = 0
        for name, values in expected.items():
            # The seeded words never equal the mask values, so the first match is the scan write
            first = [model.writes.index((var.offset >> 2, value))
                     for var, value in zip(maskVars(gt, name), values)]
            assert first == sorted(first), f'{name} words not written in index order'
            written += len(first)
        assert written == 3 * MASK_WORDS

        assert seedWords(model, gt) == before
    finally:
        root.stop()


# ----------------------------------------------------------------------
# Role resolution
# ----------------------------------------------------------------------
def test_every_role_and_array_resolves_on_the_driver(fam):
    gt = fam.driver(name='G')
    family = FAMILIES[fam.name]
    port = EyeScanPort(gt, family)

    for role, name in family.regs.items():
        assert port.var(role) is getattr(gt, name), role
    for role, (name, count) in family.arrays.items():
        words = port.words(role)
        assert len(words) == count == fam.maskWords, role
        assert len({id(var) for var in words}) == count, role


def test_a_missing_mask_word_is_named_by_pattern_and_role(fam):
    family = FAMILIES[fam.name]
    name, count = family.arrays['sdataMask']
    if '{}' in name:
        device = SimpleNamespace(**{name.format(i): object() for i in range(count - 1)})
    else:
        device = SimpleNamespace(**{name: {i: object() for i in range(count - 1)}})

    with pytest.raises(EyeScanError) as err:
        EyeScanPort(device, family).words('sdataMask')

    assert name in str(err.value) and 'sdataMask' in str(err.value)


def test_a_driver_without_one_mask_word_is_refused_before_any_write(rigs):
    root, gt, model, hook = rigs(FAMS['GTYE4'])
    gt._nodes.pop('ES_SDATA_MASK9')

    res = gt.EyeScan.runBathtub(step=16, lineRateGbps=6.25, probeWindow=0.3)

    assert res.status is ScanStatus.ERROR
    assert 'ES_SDATA_MASK{}' in res.message and 'sdataMask' in res.message
    assert model.writes == [] and hook.pulses == 0


# ----------------------------------------------------------------------
# Neighbour bits of the shared DRP words
# ----------------------------------------------------------------------
def neighbourFields(fam, gt):
    """(word, lsb, width) of the bits that share a DRP word with a scan field."""
    fields = [(0x3C, 5, 3)]   # unnamed bits 7:5 next to ES_PRESCALE and the enables
    if fam.name == 'GTHE3':
        return fields + [(0x4F, 0, 4), (0x97, 11, 2)]
    named = [fieldOf(getattr(gt, name)) for name in ('FTS_LANE_DESKEW_CFG', 'RX_CAPFF_SARC_ENB', 'RX_AFE_CM_EN')]
    assert named == [(0x4F, 0, 4), (0x97, 11, 1), (0x97, 12, 1)]
    return fields + named


def test_a_scan_keeps_every_neighbour_bit_of_the_shared_words(fam, rigs):
    root, gt, model, hook = rigs(fam)
    fields = neighbourFields(fam, gt)
    seed = {word: model.word(word) for word in (0x3C, 0x4F, 0x97)}
    before = seedWords(model, gt)
    allowed = scanWords(EyeScanPort(gt, FAMILIES[fam.name]))

    res = gt.EyeScan.runBathtub(step=16, lineRateGbps=6.25, probeWindow=0.3)

    assert res.status is ScanStatus.OK, res.message
    seen = dict.fromkeys(seed, 0)
    for addr, value in model.writes:
        assert addr in allowed, f'write to DRP word 0x{addr:X} outside the scan words'
        for word, lsb, width in fields:
            if addr == word:
                mask = ((1 << width) - 1) << lsb
                assert value & mask == seed[word] & mask, f'neighbour bits of 0x{word:X} changed'
        if addr in seen:
            seen[addr] += 1
    assert all(seen.values()), f'a shared word was never written: {seen}'
    # The word next to the scan words and the known overlapping words are never written
    assert 0x93 not in {addr for addr, _ in model.writes}
    assert not {addr for addr, _ in model.writes} & GTYE4_OVERLAP_WORDS
    assert seedWords(model, gt) == before


# ----------------------------------------------------------------------
# State machine and status decode
# ----------------------------------------------------------------------
def test_every_run_steps_reset_count_end(fam, rigs):
    states = []
    root, gt, model, hook = rigs(fam, onState=states.append)

    res = gt.EyeScan.runBathtub(step=32, lineRateGbps=6.25, probeWindow=0.3)

    assert res.status is ScanStatus.OK, res.message
    starts = [i for i, state in enumerate(states) if state == 'RESET']
    assert len(starts) == model.runs and model.runs > 3
    for index in starts:
        assert states[index:index + 3] == ['RESET', 'COUNT', 'END']


def test_control_status_raw_values_decode_to_the_same_names(fam, rigs):
    root, gt, model, hook = rigs(fam, hooked=False)
    word = fam.status[2]
    assert fieldOf(gt.es_control_status) == (word, 0, 4)

    for raw, name in ((0x1, 'WAIT'), (0x2, 'RESET'), (0x6, 'COUNT'), (0x5, 'END')):
        model.setWord(word, raw)
        assert decodeControlStatus(raw) == name
        assert gt.EyeScan.readState().controlStatusName == name
    assert model.writes == []


# ----------------------------------------------------------------------
# Bit counts
# ----------------------------------------------------------------------
@pytest.mark.parametrize('prescale', [6, 8])
def test_a_point_counts_samples_times_prescale_times_width_bits(fam, rigs, prescale):
    root, gt, model, hook = rigs(fam)

    res = gt.EyeScan.runBathtub(step=64, fixedPrescale=prescale, floor=1e-6, lineRateGbps=6.25, probeWindow=0.3)

    assert res.status is ScanStatus.OK, res.message
    assert res.horzCounts.tolist() == [-64, 0, 64]
    assert res.meta['bitsPerSample'] == fam.W
    centre = 1
    assert int(res.prescale[centre]) == prescale
    assert res.errors[:, centre].tolist() == [0, 0]
    # Zero errors: the run ends with the sample counter at its maximum
    exact = 65535 * 2 ** (1 + prescale) * fam.W
    assert [int(bits) for bits in res.bits[:, centre]] == [exact, exact]
    assert exact == bitsPerRun(65535, prescale, fam.W)


def test_bits_per_run_is_exact_above_two_to_the_53():
    assert bitsPerRun(65535, 31, 80) == 65535 * 2 ** 32 * 80
    assert bitsPerRun(65535, 31, 80) > 2 ** 53
    assert isinstance(bitsPerRun(65535, 31, 80), int)


# ----------------------------------------------------------------------
# Mask words
# ----------------------------------------------------------------------
PINNED_SDATA = {
    'GTHE3': (32, [0x00FF, 0x0000, 0xFF00, 0xFFFF, 0xFFFF]),
    'GTYE4': (64, [0xFFFF, 0, 0, 0, 0] + [0xFFFF] * 5),
}


def test_mask_words_hold_sixteen_bits_each_in_index_order(fam, rigs):
    root, gt, model, hook = rigs(fam, hooked=False)
    family = FAMILIES[fam.name]
    port = EyeScanPort(gt, family)
    width, pinned = PINNED_SDATA[fam.name]
    assert width == fam.W

    port.writeMasks(width)

    addrs = {role: [var.offset >> 2 for var in port.words(role)] for role in family.arrays}
    assert addrs == MASK_TABLE[fam.name]
    expected = {'sdataMask': pinned, 'qualMask': [0xFFFF] * fam.maskWords, 'qualifier': [0] * fam.maskWords}
    assert maskWords(sdataMask(width, family.busWidth), fam.maskWords) == pinned
    assert sum(word << (16 * i) for i, word in enumerate(pinned)) == sdataMask(width, family.busWidth)
    for role, words in expected.items():
        written = [(addr, value) for addr, value in model.writes if addr in addrs[role]]
        assert written == list(zip(addrs[role], words)), role
    assert len(model.writes) == 3 * fam.maskWords


def test_a_scan_writes_the_words_of_every_mask_array_in_index_order(fam, rigs):
    root, gt, model, hook = rigs(fam)

    res = gt.EyeScan.runBathtub(step=32, lineRateGbps=6.25, probeWindow=0.3)

    assert res.status is ScanStatus.OK, res.message
    for role, addrs in MASK_TABLE[fam.name].items():
        first = [next(i for i, (addr, _) in enumerate(model.writes) if addr == a) for a in addrs]
        assert first == sorted(first), role


# ----------------------------------------------------------------------
# Width and divider tables
# ----------------------------------------------------------------------
def setWidth(fam, model, gt, bits, intRaw):
    model.setField(gt.RX_DATA_WIDTH, rawCode(FAMILIES[fam.name].rxDataWidthCodes, bits))
    model.setField(gt.RX_INT_DATAWIDTH, intRaw)


@pytest.mark.parametrize('bits,intRaw,decoded', [(160, 2, 80), (128, 2, 64), (80, 2, 80), (64, 2, 64)])
def test_gtye4_width_pairs_at_the_bus_limit_decode(rigs, bits, intRaw, decoded):
    root, gt, model, hook = rigs(FAMS['GTYE4'], hooked=False)
    setWidth(FAMS['GTYE4'], model, gt, bits, intRaw)

    state = gt.EyeScan.readState()

    assert state.widthError is None
    assert state.bitsPerSample == decoded <= FAMILIES['GTYE4'].busWidth
    assert model.writes == []


def test_a_pair_outside_the_family_table_is_refused_with_both_raw_values(fam, rigs):
    root, gt, model, hook = rigs(fam)
    setWidth(fam, model, gt, 64, 0)

    state = gt.EyeScan.readState()
    assert state.bitsPerSample is None
    assert 'RX_DATA_WIDTH raw 6' in state.widthError and 'RX_INT_DATAWIDTH raw 0' in state.widthError

    res = gt.EyeScan.runBathtub(step=16, lineRateGbps=6.25, probeWindow=0.3)

    assert res.status is ScanStatus.ERROR
    assert 'RX_DATA_WIDTH raw 6' in res.message and 'RX_INT_DATAWIDTH raw 0' in res.message
    assert model.writes == [] and hook.pulses == 0


def test_a_divider_outside_the_table_is_refused_without_a_write(fam, rigs):
    root, gt, model, hook = rigs(fam)
    model.setField(gt.RXOUT_DIV, 5)

    state = gt.EyeScan.readState()
    assert state.rxOutDiv is None and state.horzHalfRange is None

    res = gt.EyeScan.runBathtub(step=16, lineRateGbps=6.25, probeWindow=0.3)

    assert res.status is ScanStatus.ERROR
    assert 'unsupported RXOUT_DIV raw 5' in res.message
    assert model.writes == [] and hook.pulses == 0
    # Divider 32 would need +-1024 counts, one past the 11-bit two's complement range
    assert 32 * FAMILIES[fam.name].countsPerHalfUiPerDiv > 2 ** 10 - 1


def test_the_largest_divider_keeps_the_half_range_in_the_offset_field(fam, rigs):
    root, gt, model, hook = rigs(fam, hooked=False)
    model.setField(gt.RXOUT_DIV, 4)

    state = gt.EyeScan.readState()

    assert state.rxOutDiv == 16 and state.horzHalfRange == 512
    assert -2 ** 10 <= -state.horzHalfRange and state.horzHalfRange <= 2 ** 10 - 1


def test_a_step_equal_to_the_half_range_measures_minus_half_zero_and_plus_half(fam, rigs):
    root, gt, model, hook = rigs(fam)
    half = gt.EyeScan.readState().horzHalfRange
    assert half == 64

    res = gt.EyeScan.runBathtub(step=half, lineRateGbps=6.25, probeWindow=0.3)

    assert res.status is ScanStatus.OK, res.message
    assert res.horzCounts.tolist() == [-half, 0, half]
    assert {horz for horz, _, _, _ in model.runLog} == {-half, 0, half}
    assert model.phaseViolations == 0


# ----------------------------------------------------------------------
# Abort, idempotency, concurrency
# ----------------------------------------------------------------------
def test_an_abort_at_activation_restores_every_register(fam, rigs):
    root, gt, model, hook = rigs(fam)
    before = seedWords(model, gt)

    res = gt.EyeScan.runBathtub(step=16, lineRateGbps=6.25, probeWindow=0.3,
                                control=ScanControl(isAborted=lambda: True))

    assert res.status is ScanStatus.ABORTED
    assert res.horzCounts.size == 0
    assert model.getField(gt.ES_CONTROL) == 0
    assert seedWords(model, gt) == before


def test_an_abort_after_three_points_keeps_them_and_restores(fam, rigs):
    root, gt, model, hook = rigs(fam)
    before = seedWords(model, gt)
    done = []
    control = ScanControl(isAborted=lambda: len(done) >= 3, onProgress=lambda n, total: done.append(n))

    res = gt.EyeScan.runBathtub(step=8, lineRateGbps=6.25, probeWindow=0.3, control=control)

    assert res.status is ScanStatus.ABORTED
    assert res.horzCounts.tolist() == [-64, -56, -48]
    assert model.getField(gt.ES_CONTROL) == 0
    assert seedWords(model, gt) == before


def test_two_consecutive_bathtubs_both_end_ok_and_restore(fam, rigs):
    root, gt, model, hook = rigs(fam)
    before = seedWords(model, gt)

    first = gt.EyeScan.runBathtub(step=16, resetPolicy='Always', lineRateGbps=6.25, probeWindow=0.3)
    assert first.status is ScanStatus.OK, first.message
    assert hook.pulses == 1 and seedWords(model, gt) == before

    second = gt.EyeScan.runBathtub(step=16, resetPolicy='Never', lineRateGbps=6.25, probeWindow=0.3)
    assert second.status is ScanStatus.OK, second.message
    assert hook.pulses == 1 and seedWords(model, gt) == before
    assert second.horzCounts.tolist() == first.horzCounts.tolist()


def test_a_second_run_on_a_busy_transceiver_is_refused_without_bus_traffic(fam, rigs):
    root, gt, model, hook = rigs(fam)
    assert model.transactions == 0

    with gt.EyeScan._scanLock:
        with pytest.raises(EyeScanError, match='another eye-scan run is in progress'):
            gt.EyeScan.runBathtub(lineRateGbps=6.25)

    assert model.transactions == 0
    assert hook.pulses == 0


# ----------------------------------------------------------------------
# Start, ReadAll, polling and saved YAML
# ----------------------------------------------------------------------
def test_root_start_issues_no_transactions_with_or_without_the_child(fam):
    for eyeScan in (True, False):
        root, gt, model = build(fam, eyeScan)
        with root:
            assert model.transactions == 0
        assert hasattr(gt, 'EyeScan') is eyeScan


@pytest.mark.parametrize('initRead', [False, True])
def test_start_and_read_all_cost_the_same_with_or_without_the_child(fam, initRead):
    counts = {}
    for eyeScan in (True, False):
        root, gt, model = build(fam, eyeScan, initRead=initRead)
        with root:
            atStart = model.transactions
            root.ReadAll()
            counts[eyeScan] = (atStart, model.transactions - atStart, set(model.readAddrs))
    assert counts[True] == counts[False]
    assert (counts[True][0] > 0) is initRead
    assert counts[True][1] > 0


def test_polling_reads_only_the_status_word_with_or_without_the_child(fam):
    seen = {}
    for eyeScan in (True, False):
        root, gt, model = build(fam, eyeScan, pollEn=True)
        # One RO status register is polled so the window has real traffic to compare
        gt.es_control_status.setPollInterval(0.5)
        with root:
            assert model.transactions == 0
            time.sleep(2.6)
            seen[eyeScan] = (model.transactions, set(model.readAddrs), model.writes[:])
    assert seen[True][1] == seen[False][1] == {fam.status[2]}
    assert seen[True][0] > 0 and seen[False][0] > 0
    assert seen[True][2] == seen[False][2] == []


def test_saved_config_and_state_yaml_exclude_the_child(fam):
    golden = json.loads(fam.golden.read_text())
    # Commands are never written to the config YAML, every other writable
    # variable of the golden list is, and the child adds none
    expected = {row['name'] for row in golden if row['mode'] in ('RW', 'WO') and row['class'] != 'BaseCommand'}
    configKeys = {}
    for eyeScan in (True, False):
        root, gt, model = build(fam, eyeScan)
        with root:
            config = yaml.safe_load(root.getYaml(readFirst=False, modes=['RW', 'WO'], excGroups='NoConfig'))
            state = yaml.safe_load(root.getYaml(readFirst=False, modes=['RW', 'RO', 'WO'], excGroups='NoState'))
            assert model.transactions == 0
        assert 'EyeScan' not in keysOf(config)
        assert 'EyeScan' not in keysOf(state)
        configKeys[eyeScan] = set(config['Root']['Gt'])
    assert configKeys[True] == configKeys[False] == expected
    scanRw = {'ES_HORZ_OFFSET', 'RX_EYESCAN_VS_CODE', 'RX_EYESCAN_VS_RANGE',
              'RX_EYESCAN_VS_NEG_DIR', 'RX_EYESCAN_VS_UT_SIGN'}
    if fam.name == 'GTHE3':
        # The added GTHE3 scan variables are NoConfig
        assert not configKeys[True] & scanRw
    else:
        # The GTYE4 scan variables are older than the child and stay in the saved file as they were
        assert scanRw <= configKeys[True]


# ----------------------------------------------------------------------
# Variable lists against the golden files
# ----------------------------------------------------------------------
def test_variable_rows_equal_the_golden_rows_with_and_without_the_child(fam):
    golden = {row['name']: row for row in json.loads(fam.golden.read_text())}
    expected = dict(golden)
    for name, (offset, bitOffset, bitSize, mode) in fam.additions.items():
        expected[name] = dict(name=name, offset=offset, bitOffset=bitOffset, bitSize=bitSize, mode=mode,
                              **{'class': 'RemoteVariable'})
    for eyeScan in (True, False):
        gt = fam.driver(name='G', eyeScan=eyeScan)
        assert rowsOf(gt) == expected
        assert ('EyeScan' in gt.nodes) is eyeScan
        assert 'EyeScan' not in rowsOf(gt)
    assert len(golden) == {'GTHE3': 375, 'GTYE4': 526}[fam.name]


def test_the_default_driver_equals_the_explicit_opt_out_in_every_row():
    assert rowsOf(xil.Gtye4Channel(name='G')) == rowsOf(xil.Gtye4Channel(name='G', eyeScan=False))
    assert len(rowsOf(xil.Gtye4Channel(name='G'))) == 526


def test_golden_rows_are_sorted_and_the_comparison_is_keyed_by_name():
    rows = json.loads((HERE / 'gtye4_variables.json').read_text())
    names = [row['name'] for row in rows]
    assert names == sorted(names) and len(set(names)) == len(names)
    current = rowsOf(xil.Gtye4Channel(name='G'))
    assert current == {row['name']: row for row in reversed(rows)}


@pytest.mark.parametrize('mutation', [
    ('bitOffset', lambda row: [row['bitOffset'][0] + 1] + row['bitOffset'][1:]),
    ('offset', lambda row: row['offset'] + 4),
    ('bitSize', lambda row: [row['bitSize'][0] + 1] + row['bitSize'][1:]),
    ('mode', lambda row: 'RO' if row['mode'] != 'RO' else 'RW'),
    ('class', lambda row: 'LocalVariable'),
])
def test_a_changed_row_fails_the_comparison(mutation):
    key, change = mutation
    rows = {row['name']: dict(row) for row in json.loads((HERE / 'gtye4_variables.json').read_text())}
    assert rowsOf(xil.Gtye4Channel(name='G')) == rows
    victim = rows['ES_HORZ_OFFSET']
    victim[key] = change(victim)
    assert rowsOf(xil.Gtye4Channel(name='G')) != rows


def test_a_renamed_row_fails_the_comparison():
    rows = {row['name']: dict(row) for row in json.loads((HERE / 'gtye4_variables.json').read_text())}
    row = rows.pop('ES_HORZ_OFFSET')
    rows['ES_HORZ_OFFSET_OLD'] = dict(row, name='ES_HORZ_OFFSET_OLD')
    assert rowsOf(xil.Gtye4Channel(name='G')) != rows


# ----------------------------------------------------------------------
# Per-family DRP address and bit-overlap table
# ----------------------------------------------------------------------
def test_every_role_sits_at_its_pinned_drp_field(fam):
    gt = fam.driver(name='G')
    family = FAMILIES[fam.name]
    table = dict(COMMON_TABLE)
    table.update(errorCount=(fam.status[0], 0, 16), sampleCount=(fam.status[1], 0, 16),
                 controlStatus=(fam.status[2], 0, 4))
    assert set(table) == set(family.regs)
    for role, field in table.items():
        assert fieldOf(getattr(gt, family.regs[role])) == field, role
    for role, words in MASK_TABLE[fam.name].items():
        name, count = family.arrays[role]
        variables = EyeScanPort(gt, family).words(role)
        assert [fieldOf(var) for var in variables] == [(word, 0, 16) for word in words], role


def test_no_two_variables_overlap_inside_the_scan_words(fam):
    gt = fam.driver(name='G')
    words = scanWords(EyeScanPort(gt, FAMILIES[fam.name]))
    owners = bitOwners(gt)

    assert len(words) == fam.scanWords
    for word in sorted(words):
        clashes = {pos: names for pos, names in owners.get(word, {}).items() if len(names) > 1}
        assert clashes == {}, f'0x{word:X}: {clashes}'


def test_the_known_gtye4_overlaps_lie_outside_the_scan_words():
    gt = xil.Gtye4Channel(name='G')
    owners = bitOwners(gt)
    overlapping = {word for word, bits in owners.items() if any(len(names) > 1 for names in bits.values())}

    assert overlapping == GTYE4_OVERLAP_WORDS
    assert not overlapping & scanWords(EyeScanPort(gt, FAMILIES['GTYE4']))
    assert not any(len(names) > 1 for bits in bitOwners(xil.Gthe3Channel(name='G')).values() for names in bits.values())


# ----------------------------------------------------------------------
# Family registry and the deferred families
# ----------------------------------------------------------------------
def test_the_registry_holds_exactly_the_two_ultrascale_families():
    assert set(FAMILIES) == {'GTHE3', 'GTYE4'}
    assert set(UNSUPPORTED_FAMILIES) == {'GTPE2', 'GTXE2'}
    for name in ('GTXE2', 'GTPE2'):
        with pytest.raises(EyeScanError, match='not supported for this family yet'):
            getFamily(name)
    with pytest.raises(EyeScanError, match='unknown eye-scan family'):
        getFamily('GTZE9')


def test_gtye4_hardware_verified_flag_matches_the_hardware_record():
    # Varium C1100 lanes 4-7 over the QSFP[1] fiber loopback, 6.25 Gb/s image: the
    # battery passed on its first run on all four lanes (activation, advancing,
    # full, walls, monotone, continuous and bounded bathtubs, three-run opening
    # repeatability within one RX reset, Eye and Margin OK), so no failed battery
    # is on record; the phase rule stayed 'sign' and the vertical Q-scale fit gate
    # failed on every lane, as on GTHE3; see docs/plans/eyescan/README.md.
    assert GTYE4.hwVerified is True
    assert GTHE3.hwVerified is True
    root, gt, model = build(FAMS['GTYE4'], True)
    with root:
        assert gt.EyeScan.HwVerified.get() is GTYE4.hwVerified


def test_the_seven_series_drivers_have_no_child_and_no_eye_scan_argument():
    drivers = {
        'Gtxe2Channel': xil.Gtxe2Channel(name='A'),
        'Gtpe2Channel': xil.Gtpe2Channel(name='B'),
        'GigEthGtx7':   gige.GigEthGtx7(name='C', gtxe2_read_only=True),
    }
    for name, device in drivers.items():
        assert device.find(typ=es.EyeScan) == [], name
        assert not hasattr(device, 'EyeScan'), name
    for cls in (xil.Gtxe2Channel, xil.Gtpe2Channel, gige.GigEthGtx7):
        assert 'eyeScan' not in inspect.signature(cls.__init__).parameters, cls.__name__
    for cls, kwargs in ((xil.Gtxe2Channel, {}), (xil.Gtpe2Channel, {}), (gige.GigEthGtx7, {'gtxe2_read_only': True})):
        with pytest.raises(TypeError):
            cls(name='D', eyeScan=False, **kwargs)


# ----------------------------------------------------------------------
# Descriptor invariants
# ----------------------------------------------------------------------
DRIVERS = {name: ns.driver for name, ns in FAMS.items()}


def test_every_family_round_trips_through_its_driver():
    assert set(DRIVERS) == set(FAMILIES), 'a family has no driver in this test table'
    assert not set(FAMILIES) & set(UNSUPPORTED_FAMILIES)
    for name, family in FAMILIES.items():
        ns = FAMS[name]
        model = ns.model()
        root = pr.Root(pollEn=False, initRead=False, initWrite=False, timeout=1.0)
        gt = DRIVERS[name](name='Gt', memBase=model)
        root.add(gt)
        model.seedHardwareLike(gt)
        port = EyeScanPort(gt, family)
        try:
            root.start()
            assert family.name == name and getFamily(name) is family
            # Every role and mask array resolves on the driver class with the descriptor's word count
            for role in family.regs:
                assert port.var(role) is not None, (name, role)
            for role, (_, count) in family.arrays.items():
                assert len(port.words(role)) == count, (name, role)

            # writeMasks writes exactly that many words per array
            port.writeMasks(family.busWidth)
            for role, (_, count) in family.arrays.items():
                addrs = {var.offset >> 2 for var in port.words(role)}
                assert len([addr for addr, _ in model.writes if addr in addrs]) == count, (name, role)

            # Every width pair decodes and fits the sdata bus
            for bits, intRaw in sorted(family.widthCombos):
                model.setField(gt.RX_DATA_WIDTH, rawCode(family.rxDataWidthCodes, bits))
                model.setField(gt.RX_INT_DATAWIDTH, intRaw)
                decoded = port.bitsPerSample()
                assert decoded == internalWidth(bits, intRaw) <= family.busWidth, (name, bits, intRaw)

            # Every divider decodes and the largest keeps the half range inside the offset field
            for raw, divider in family.rxOutDivCodes.items():
                model.setField(gt.RXOUT_DIV, raw)
                assert port.rxOutDiv() == divider
                assert port.horzHalfRange() == family.countsPerHalfUiPerDiv * divider
            assert family.countsPerHalfUiPerDiv * max(family.rxOutDivCodes.values()) <= 2 ** (family.horzBits - 1) - 1

            # The phase rule is a known one, the threshold a real rate, and the lane the estimate prices
            # before the first scan is one the family can have
            assert family.phaseUnification in PHASE_RULES, name
            assert family.rateThresholdGbps > 0, name
            assert family.defaultDivider in family.rxOutDivCodes.values(), name
            assert family.defaultWidth in {internalWidth(bits, intRaw) for bits, intRaw in family.widthCombos}, name
        finally:
            root.stop()
