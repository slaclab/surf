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
# - DUT: JesdAlignFrRepCh (flat ports, no wrapper needed).
# - Sweep: Full TI F sweep x SCR_ENABLE {0, 1}.
#   JesdAlignFrRepCh has only F_G as HDL generic (not K_G); K does not affect
#   char restoration logic. F_G {1, 2, 4} x SCR {0, 1} covers the TI union.
# - Stimulus: Python golden stream — pre-swapped GT words matching what the
#   elastic FIFO delivers (raw GT format, data[7:0] = first octet). The RTL
#   applies byteSwapSlv on INPUT (JesdAlignFrRepCh.vhd:155) — golden model must
#   replicate this. Use predict_char_restoration() (not predict_char_replacement).
# - Checks: char restoration — original data recovered, charisk cleared, alignErr
#   on misplaced K-chars, positionErr on bad comma position.
#   Seeded-random soak: fixed-seed reproducibility.
# - BIG-endian output: sampleData_o first sample in time at bits [31:16].
#   Do NOT apply endian_swap_32 for standalone AlignFrRepCh bench.
#   endian_swap_32 is only for JesdRxLane output (which applies endianSwapSlv).
# - byteSwap on INPUT: JesdAlignFrRepCh applies byteSwapSlv at line 155 of
#   JesdAlignFrRepCh.vhd, unlike TX which applies it at output. Golden model
#   predict_char_restoration() replicates this input-side swap.
# - Latency: 1cc non-scrambled, 3cc scrambled.
#   Skip pipeline-fill cycles before golden compare.

from __future__ import annotations

import random

import cocotb
import pytest

from tests.common.regression_utils import sample_after_tpd

from tests.common.regression_utils import (
    env_int,
    env_sl,
    hdl_parameters_from,
    parameter_case,
    run_surf_vhdl_test,
)
from tests.protocols.jesd204b.jesd204b_test_utils import (
    JesdTB,
    K_CHAR,
    predict_char_restoration,
)

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

_GT_WORD_MASK = 0xFFFFFFFF
_K4_MASK      = 0xF

# ---------------------------------------------------------------------------
# Parameter sweep: Full TI F/K union x SCR_ENABLE {0, 1}
# SCR_ENABLE is a Python-only env key (not an HDL generic on JesdAlignFrRepCh).
# ---------------------------------------------------------------------------

PARAMETER_SWEEP = [
    # F_G is the only HDL generic (JesdAlignFrRepCh has only TPD_G / F_G).
    # SCR_ENABLE is Python-only (stripped by hdl_parameters_from).
    # K_G is omitted — not a generic of JesdAlignFrRepCh; F/SCR fully covers the union.
    # RTL default (K=32, F=2) x both scrambling modes:
    parameter_case("f2_scr0", F_G="2", SCR_ENABLE="0"),
    parameter_case("f2_scr1", F_G="2", SCR_ENABLE="1"),
    # F extremes (full TI F/K union coverage):
    parameter_case("f1_scr0", F_G="1", SCR_ENABLE="0"),
    parameter_case("f4_scr0", F_G="4", SCR_ENABLE="0"),
    parameter_case("f1_scr1", F_G="1", SCR_ENABLE="1"),
    parameter_case("f4_scr1", F_G="4", SCR_ENABLE="1"),
]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _init_dut(dut, *, scr_enable: int) -> JesdTB:
    """Instantiate JesdTB and initialise all DUT inputs via setimmediatevalue."""
    tb = JesdTB(dut)
    dut.replEnable_i.setimmediatevalue(1)
    dut.scrEnable_i.setimmediatevalue(scr_enable)
    dut.alignFrame_i.setimmediatevalue(0)
    dut.dataValid_i.setimmediatevalue(1)
    dut.dataRx_i.setimmediatevalue(0)
    dut.chariskRx_i.setimmediatevalue(0)
    return tb


# ---------------------------------------------------------------------------
# Test 1 (char restoration): non-scrambled char restoration
# ---------------------------------------------------------------------------


@cocotb.test(skip=env_sl("SCR_ENABLE", default=0) != 0)
async def test_char03_restore_nonscrambled(dut):
    """Non-scrambled: original data recovered, charisk cleared (§5.3.3.4.2).

    Drives plain data through JesdAlignFrRepCh with replEnable=1, scrEnable=0.
    Golden model is predict_char_restoration(scr=False).
    Output is BIG-endian (first sample at bits [31:16]) — no endian_swap_32 applied.
    Latency: 1cc (non-scrambled, JesdAlignFrRepCh.vhd:228-230).

    Original data recovered, no residual control chars.
    """
    f = env_int("F_G", default=2)

    tb = _init_dut(dut, scr_enable=0)
    await tb.reset()

    # Craft plain data stimulus — no K-chars, no char-replacement positions.
    # Use a repeating non-trivial pattern so any mismatch is visible.
    n_words = 32
    stimulus = [0x12345678, 0xDEADBEEF, 0xCAFEF00D, 0xA5A5A5A5] * (n_words // 4)
    golden = predict_char_restoration(stimulus, f=f, scr=False, lfsr_init=0)

    _LATENCY = 1
    _DRAIN   = _LATENCY + 4
    got_raw: list[int] = []

    total_cycles = n_words + _DRAIN
    for cycle_i in range(total_cycles):
        dut.dataRx_i.value    = stimulus[cycle_i] if cycle_i < n_words else 0
        dut.chariskRx_i.value = 0
        await sample_after_tpd(dut.clk)
        if cycle_i >= _LATENCY:
            got_raw.append(int(dut.sampleData_o.value) & _GT_WORD_MASK)

    # Compare against golden — skip pipeline pre-fill transient.
    # The RTL alignment pipeline (position="0001" initial → JesdDataAlign extracts
    # the PREVIOUS word from the two-word buffer) introduces a 1-word offset:
    # RTL output[i] ≈ byteSwap(stimulus[i-1]).  Align by comparing got_raw[_SKIP_G:]
    # against golden[_SKIP_E:] where _SKIP_G = _SKIP_E + 1.
    _SKIP_E = 2   # expected offset (skip first 2 golden words = transient)
    _SKIP_G = 3   # got offset (skip 1 more to compensate 1-word alignment delay)
    got = got_raw[_SKIP_G:]
    exp = golden[_SKIP_E:]

    assert len(exp) > 0, "non-scr: golden is empty"
    n_compare = min(len(got), len(exp))
    assert n_compare > 0, "non-scr: nothing to compare"

    for idx in range(n_compare):
        got_data = got[idx]
        exp_data = exp[idx][0] & _GT_WORD_MASK
        exp_k    = exp[idx][1] & _K4_MASK
        assert got_data == exp_data, (
            f"non-scr mismatch at word {idx}: "
            f"got={got_data:#010x} exp={exp_data:#010x} "
            f"(f={f})"
        )
        assert exp_k == 0, (
            f"golden model produced residual charisk at word {idx}: "
            f"exp_k={exp_k:#x}"
        )

    # Verify RTL does not assert alignErr on a plain data stream
    assert int(dut.alignErr_o.value) == 0, (
        "non-scr: alignErr_o asserted on plain data stream"
    )


# ---------------------------------------------------------------------------
# Test 2 (char restoration): scrambled char restoration
# ---------------------------------------------------------------------------


@cocotb.test(skip=env_sl("SCR_ENABLE", default=0) != 1)
async def test_char03_restore_scrambled(dut):
    """Scrambled: original data recovered, charisk cleared (§5.3.3.4.3).

    Drives plain data through JesdAlignFrRepCh with replEnable=1, scrEnable=1.
    Golden model is predict_char_restoration(scr=True).
    Latency: 3cc (scrambled, JesdAlignFrRepCh.vhd:222-226).

    The RTL descrambles internally; the bench drives raw data (no pre-scrambling).
    The golden model descrambles the byte-swapped input to produce expected output.
    No residual K-chars expected on output.

    Original data recovered, no residual control chars.
    """
    f = env_int("F_G", default=2)

    tb = _init_dut(dut, scr_enable=1)
    await tb.reset()

    n_words = 32
    stimulus = [0x12345678, 0xDEADBEEF, 0xCAFEF00D, 0xA5A5A5A5] * (n_words // 4)
    golden = predict_char_restoration(stimulus, f=f, scr=True, lfsr_init=0)

    _LATENCY = 3
    _DRAIN   = _LATENCY + 4
    got_raw: list[int] = []

    total_cycles = n_words + _DRAIN
    for cycle_i in range(total_cycles):
        dut.dataRx_i.value    = stimulus[cycle_i] if cycle_i < n_words else 0
        dut.chariskRx_i.value = 0
        await sample_after_tpd(dut.clk)
        if cycle_i >= _LATENCY:
            got_raw.append(int(dut.sampleData_o.value) & _GT_WORD_MASK)

    # Skip pipeline transient. Scrambled path: 3cc latency + 1-word alignment delay.
    _SKIP_E = 3
    _SKIP_G = 4
    got = got_raw[_SKIP_G:]
    exp = golden[_SKIP_E:]

    assert len(exp) > 0, "scr: golden is empty"
    n_compare = min(len(got), len(exp))
    assert n_compare > 0, "scr: nothing to compare"

    for idx in range(n_compare):
        got_data = got[idx]
        exp_data = exp[idx][0] & _GT_WORD_MASK
        assert got_data == exp_data, (
            f"scr mismatch at word {idx}: "
            f"got={got_data:#010x} exp={exp_data:#010x} "
            f"(f={f})"
        )


# ---------------------------------------------------------------------------
# Test 3 (char restoration): alignErr on misplaced K-char
# ---------------------------------------------------------------------------


@cocotb.test()
async def test_char03_align_error(dut):
    """Char restoration: alignErr_o asserted on residual K-char that is not /F/ or /A/.

    Drives a word where chariskRx_i has a bit set for a byte that is neither
    F_CHAR (0xFC) nor A_CHAR (0x7C). The char-restoration loop does not clear
    this charisk bit, leaving a residual K-char, so alignErr_o should assert.

    Source: JesdAlignFrRepCh.vhd:192-199 — alignErr fires on any residual charisk.
    alignErr raised on misplaced control characters.
    """
    scr_enable = env_sl("SCR_ENABLE", default=0)

    tb = _init_dut(dut, scr_enable=scr_enable)
    await tb.reset()

    # Prime the two-word buffer with plain data for a few cycles
    for _ in range(4):
        dut.dataRx_i.value    = 0x11111111
        dut.chariskRx_i.value = 0
        await sample_after_tpd(dut.clk)

    # Inject a K-char (K28.5 = 0xBC) at byte 0 — K28.5 is not /F/ or /A/,
    # so it will NOT be consumed by char restoration → residual charisk → alignErr.
    # Use chariskRx_i=0x1 to flag byte 0 as a K-char.
    k_word = K_CHAR   # K28.5 at byte 0 (data[7:0])
    for _ in range(4):
        dut.dataRx_i.value    = k_word
        dut.chariskRx_i.value = 0x1
        await sample_after_tpd(dut.clk)

    # alignErr_o is combinatorial — sample it immediately after settle
    assert int(dut.alignErr_o.value) == 1, (
        "alignErr: expected alignErr_o=1 on K28.5 byte (not /F/ or /A/), "
        "got 0 — residual K-char not flagged"
    )


# ---------------------------------------------------------------------------
# Test 4 (char restoration): positionErr on bad comma position at alignment
# ---------------------------------------------------------------------------


@cocotb.test()
async def test_char03_position_error(dut):
    """Char restoration: positionErr_o asserted when no valid comma position at alignFrame.

    positionErr fires when detectPosFuncSwap returns all-ones (r.position=0xF),
    which happens when no K-char is found at any valid alignment position in the
    GT word on the alignFrame_i pulse (JesdAlignFrRepCh.vhd:145-152).

    Drive alignFrame_i=1 with plain data (no K-chars) — detectPosFuncSwap cannot
    find a comma position → returns all-ones → positionErr_o=1 (combinatorial).

    positionErr raised on bad comma position at alignment.
    """
    scr_enable = env_sl("SCR_ENABLE", default=0)

    tb = _init_dut(dut, scr_enable=scr_enable)
    await tb.reset()

    # Prime the pipeline with plain data (no K-chars)
    for _ in range(4):
        dut.dataRx_i.value    = 0x55555555
        dut.chariskRx_i.value = 0
        await sample_after_tpd(dut.clk)

    # Drive alignFrame_i=1 with K_CHAR at byte 3 only (data[31:24] = K_CHAR)
    # and chariskRx_i=0x8 (bit 3 set for byte 3).
    # detectPosFuncSwap (Jesd204bPkg.vhd:258-288) requires K_CHAR at bytes 0..n
    # contiguously from byte 0. A K_CHAR only at byte 3 (not byte 0) falls into
    # the "else" branch → returns "1111" → positionErr_o=1.
    illegal_word = (K_CHAR << 24) | 0x00555555   # K_CHAR only at byte 3
    dut.alignFrame_i.value = 1
    dut.dataRx_i.value     = illegal_word
    dut.chariskRx_i.value  = 0x8   # only byte 3 flagged
    await sample_after_tpd(dut.clk)
    dut.alignFrame_i.value = 0

    # positionErr_o is combinatorial from r.position.
    # After one more clock, r.position = 0xF → positionErr_o = 1.
    dut.dataRx_i.value    = 0x55555555
    dut.chariskRx_i.value = 0
    await sample_after_tpd(dut.clk)

    assert int(dut.positionErr_o.value) == 1, (
        "positionErr: expected positionErr_o=1 after alignFrame with "
        "K_CHAR only at byte 3 (not byte 0), got 0 — bad comma position not flagged"
    )


# ---------------------------------------------------------------------------
# Test 5 (char restoration): seeded-random soak
# ---------------------------------------------------------------------------


@cocotb.test()
async def test_char03_random_soak(dut):
    """Seeded-random soak: byte-for-byte check against predictor.

    Fixed seed for reproducibility. One run per test invocation (SCR_ENABLE
    selects scrambled vs non-scrambled path via PARAMETER_SWEEP).
    Drives random data words, compares every sampled word against
    predict_char_restoration() byte-for-byte. Skips pipeline-fill cycles.

    Spec: JESD204B §5.3.3.4.2/.3.
    """
    f = env_int("F_G", default=2)
    scr_enable = env_sl("SCR_ENABLE", default=0)

    tb = _init_dut(dut, scr_enable=scr_enable)
    await tb.reset()

    # Fixed seed for reproducibility
    rng = random.Random(0xC0C0_BABE)
    n_words = 64
    stimulus = [rng.randint(0, 0xFFFFFFFF) for _ in range(n_words)]

    golden = predict_char_restoration(stimulus, f=f, scr=bool(scr_enable), lfsr_init=0)

    _LATENCY = 3 if scr_enable else 1
    _DRAIN   = _LATENCY + 6
    got_raw: list[int] = []

    total_cycles = n_words + _DRAIN
    for cycle_i in range(total_cycles):
        dut.dataRx_i.value    = stimulus[cycle_i] if cycle_i < n_words else 0
        dut.chariskRx_i.value = 0
        await sample_after_tpd(dut.clk)
        if cycle_i >= _LATENCY:
            got_raw.append(int(dut.sampleData_o.value) & _GT_WORD_MASK)

    # Skip pipeline-fill transient.
    # For non-scr (1cc latency): RTL has a 1-word alignment delay due to JesdDataAlign
    # extracting the previous word; use _SKIP_G = _SKIP_E + 1.
    # For scr (3cc latency): the descrambler introduces additional pipeline stages;
    # use a generous skip window for both.
    _SKIP_E = _LATENCY + 1   # expected offset
    _SKIP_G = _LATENCY + 2   # got offset (1 extra for alignment delay)
    got = got_raw[_SKIP_G:]
    exp = golden[_SKIP_E:]

    assert len(exp) > 0, "soak: golden is empty"
    n_compare = min(len(got), len(exp))
    assert n_compare >= 4, (
        f"soak: insufficient comparison window ({n_compare} words)"
    )

    for idx in range(n_compare):
        got_data = got[idx]
        exp_data = exp[idx][0] & _GT_WORD_MASK
        assert got_data == exp_data, (
            f"soak mismatch at word {idx}: "
            f"got={got_data:#010x} exp={exp_data:#010x} "
            f"(f={f}, scr={scr_enable})"
        )


# ---------------------------------------------------------------------------
# Pytest wrapper
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_JesdAlignFrRepCh(parameters):
    """Char restoration: both modes, alignErr/positionErr.

    Flat-port DUT — no extra_vhdl_sources needed.
    SCR_ENABLE is a Python-only env key stripped by hdl_parameters_from().
    """
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.jesdalignfrrepch",
        parameters=hdl_parameters_from(parameters),   # strips SCR_ENABLE
        extra_env=parameters,
    )
