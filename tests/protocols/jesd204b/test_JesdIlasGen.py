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
# - Sweep: Five curated F/K pairs:
#   k32_f2 (RTL default), k32_f4, k16_f2, k32_f1, k16_f4.
#   All satisfy K*F divisible by 4 (GT_WORD_SIZE_C=4).
# - Stimulus: Drive enable_i='1', ilas_i='1', periodic lmfc_i pulses every
#   K*F/4 device clocks (the DUT processes one GT word per clock).
#   lmfc_i is driven by a background coroutine that pulses once per
#   mf_period cycles starting at cycle 0 of the ILAS sequence.
# - Checks: Framing: /R/ (0x1C, K-flag) opens and /A/ (0x7C, K-flag) closes
#   each of 4 multiframes in the captured stream; MF0/MF2/MF3 carry no /Q/
#   and no non-zero non-R/A octets.
#   Config octets: MF1 (second multiframe, mfCnt=0x01) carries /Q/ (0x9C) at the
#   second transmitted octet (data[15:8]) of its opening GT word, followed by
#   14 config octets matching build_ilas_config_octets() byte-for-byte
#   including correct FCHK; config octets absent from MF0/MF2/MF3.
# - RTL timing (post counter-offset fix):
#   mfCnt REG_INIT_C = 0xFF; first lmfc -> mfCnt=0x00 (MF1, no config);
#   second lmfc -> mfCnt=0x01 (MF2, /Q/+config).
#   wordCnt reset to 0xFF on lmfc; reaches 0x01 one cycle AFTER lmfcD2 fires,
#   so the /R/+/Q/+cfg0+cfg1 boundary word is uncontested.
#   lmfcD1 delay: /A/ at data[31:24] fires 1 cycle after lmfc.
#   lmfcD2 delay: /R/ at data[7:0] fires 2 cycles after lmfc.
#   Consequence: the DUT emits /A/ one clock before /R/ around each lmfc
#   boundary; the bench captures both by running 1 extra cycle before
#   the first collection and aligning the golden model to the /R/ found.

import cocotb
import pytest
from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import (
    env_int,
    hdl_parameters_from,
    parameter_case,
    run_surf_vhdl_test,
)
from tests.protocols.jesd204b.jesd204b_test_utils import (
    JesdTB,
    build_ilas_config_octets,
    build_ilas_gt_words,
    decode_gt_word,
    R_CHAR,
    A_CHAR,
    Q_CHAR,
)


# ---------------------------------------------------------------------------
# PARAMETER_SWEEP
# F/K pairs; all satisfy K*F % 4 == 0.
# ---------------------------------------------------------------------------
PARAMETER_SWEEP = [
    parameter_case("k32_f2", K_G="32", F_G="2"),   # RTL default
    parameter_case("k32_f4", K_G="32", F_G="4"),
    parameter_case("k16_f2", K_G="16", F_G="2"),
    parameter_case("k32_f1", K_G="32", F_G="1"),
    parameter_case("k16_f4", K_G="16", F_G="4"),
]

# Config-octet non-default runtime port sweep.
# Only K_G/F_G are HDL generics (positive integers, GHDL -g works natively).
# All config generics (DID_G, BID_G, ...) stay at RTL defaults (0) — avoiding
# the GHDL SLV-generic-override format issue.
# Non-default values are exercised via the runtime ports lid_i/scrEnable_i/subClass_i
# (passed through extra_env as LID/SCR/SUBCLASS) which ARE driven from the coroutine.
# This exercises the full config-octet golden model including FCHK (scr affects octet 3,
# LID affects octet 2, subClass affects octet 8).
ILAS02_SWEEP = [
    parameter_case(
        "ilas02_k32_f2",
        K_G="32", F_G="2",
        LID="5", SCR="1", SUBCLASS="1",
    ),
    parameter_case(
        "ilas02_k16_f4",
        K_G="16", F_G="4",
        LID="7", SCR="1", SUBCLASS="0",
    ),
    # Multi-lane: L_G=2 must advertise L-1=1 in octet 3 (bits [4:0]).
    parameter_case(
        "ilas02_l2_k32_f2",
        K_G="32", F_G="2", L_G="2",
        LID="1", SCR="1", SUBCLASS="1",
    ),
]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

async def wait_for_signal(signal, *, value, clk, timeout_cycles=2048):
    """Bounded poll for signal == value; raise AssertionError on timeout."""
    for _ in range(timeout_cycles):
        await RisingEdge(clk)
        await Timer(1, unit="ns")
        if int(signal.value) == value:
            return
    raise AssertionError(
        f"Signal {signal._name} did not reach {value} within {timeout_cycles} cycles"
    )


async def capture_ilas_words(dut, tb, *, k, f, num_mf=4):
    """Drive ILAS sequence and return the raw GT word stream.

    Drives enable_i=ilas_i=1 and mf_period-periodic lmfc_i pulses, then
    samples ilasData_o/ilasK_o each clock cycle for (num_mf+1)*mf_period
    cycles.  Returns a flat list of (data_32b, datak_4b) tuples.

    The caller uses find_ilas_mf_starts() to locate multiframe boundaries in
    the returned stream.
    """
    mf_period = (k * f) // 4  # GT words per multiframe

    dut.enable_i.value = 1
    dut.ilas_i.value = 0
    dut.lmfc_i.value = 0

    # Mimic the in-context JesdSyncFsmTx alignment: the SYNC->ILAS transition
    # happens ON an lmfc pulse, so ilas_i rises one cycle AFTER that pulse and
    # JesdIlasGen never counts the MF1-starting pulse.  Driving ilas_i=1
    # together with the first pulse is an alignment the real FSM never
    # produces (post-merge reconciliation of plans 03-03/03-04).
    dut.lmfc_i.value = 1
    await RisingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.ilas_i.value = 1
    dut.lmfc_i.value = 0

    words = []
    # Collect (num_mf + 1) * mf_period words, driving one lmfc pulse at the
    # start of each mf_period window.  Extra period ensures the last /A/ is
    # captured.
    total_words = (num_mf + 1) * mf_period
    lmfc_countdown = mf_period - 1  # next pulse lands mf_period after the first

    for _ in range(total_words):
        if lmfc_countdown == 0:
            dut.lmfc_i.value = 1
        else:
            dut.lmfc_i.value = 0

        await RisingEdge(dut.clk)
        await Timer(1, unit="ns")

        data = int(dut.ilasData_o.value)
        datak = int(dut.ilasK_o.value)
        words.append((data, datak))

        # After driving lmfc=1 for one cycle, reset countdown
        if lmfc_countdown == 0:
            lmfc_countdown = mf_period

        lmfc_countdown -= 1

    dut.lmfc_i.value = 0
    return words


def find_ilas_mf_starts(words, *, mf_period):
    """Find the start indices of ILAS multiframes in a raw word stream.

    Looks for GT words where octets[0] == (R_CHAR, True) — the opening of
    each multiframe.  Returns a list of indices in words[].  The returned
    indices are mf_period-spaced after the first one is found.
    """
    starts = []
    for i, (data, datak) in enumerate(words):
        octets = decode_gt_word(data, datak)
        if octets[0] == (R_CHAR, True):
            starts.append(i)
    return starts


# ---------------------------------------------------------------------------
# Framing bench
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_ilas01_framing(dut):
    """Framing: /R/ opens and /A/ closes each of 4 multiframes; MF0/MF2/MF3 no config.

    Captures the raw ILAS stream, finds 4 consecutive /R/-opened multiframes,
    and verifies:
    - /R/ (0x1C, K-flag) at first octet of each MF opening word.
    - /A/ (0x7C, K-flag) at last octet of each MF closing word.
    - No /Q/ and no non-zero non-R/A octets in MF0, MF2, MF3.
    """
    k = env_int("K_G", default=32)
    f = env_int("F_G", default=2)
    mf_period = (k * f) // 4

    dut.enable_i.setimmediatevalue(0)
    dut.ilas_i.setimmediatevalue(0)
    dut.lmfc_i.setimmediatevalue(0)
    dut.lid_i.setimmediatevalue(0)
    dut.scrEnable_i.setimmediatevalue(0)
    dut.subClass_i.setimmediatevalue(0)
    dut.rst.setimmediatevalue(1)

    tb = JesdTB(dut)
    await tb.reset()

    words = await capture_ilas_words(dut, tb, k=k, f=f, num_mf=4)

    # Find the first /R/ in the stream
    first_r = None
    for i, (data, datak) in enumerate(words):
        octets = decode_gt_word(data, datak)
        if octets[0] == (R_CHAR, True):
            first_r = i
            break

    assert first_r is not None, (
        f"Framing FAIL: K={k} F={f}: could not find any /R/ (0x{R_CHAR:02X}, K) "
        f"in {len(words)} captured words"
    )

    # Check 4 multiframes starting from first_r
    num_mf = 4
    for mf_idx in range(num_mf):
        r_offset = first_r + mf_idx * mf_period
        a_offset = r_offset + mf_period - 1

        if r_offset >= len(words) or a_offset >= len(words):
            # Not enough capture coverage; skip remaining
            break

        # --- /R/ at start ---
        r_data, r_datak = words[r_offset]
        r_octets = decode_gt_word(r_data, r_datak)
        assert r_octets[0] == (R_CHAR, True), (
            f"Framing FAIL: K={k} F={f} MF{mf_idx} start (word {r_offset}): "
            f"expected /R/ (0x{R_CHAR:02X}, K) at octet 0, "
            f"got (0x{r_octets[0][0]:02X}, {r_octets[0][1]})"
        )

        # --- /A/ at end ---
        a_data, a_datak = words[a_offset]
        a_octets = decode_gt_word(a_data, a_datak)
        assert a_octets[3] == (A_CHAR, True), (
            f"Framing FAIL: K={k} F={f} MF{mf_idx} end (word {a_offset}): "
            f"expected /A/ (0x{A_CHAR:02X}, K) at octet 3, "
            f"got (0x{a_octets[3][0]:02X}, {a_octets[3][1]})"
        )

        # --- MF0, MF2, MF3 carry no /Q/ and no non-zero non-R/A octets ---
        if mf_idx != 1:
            for w_off in range(mf_period):
                word_idx = r_offset + w_off
                if word_idx >= len(words):
                    break
                data, datak = words[word_idx]
                oct_list = decode_gt_word(data, datak)
                for oct_pos, (byte_val, is_k) in enumerate(oct_list):
                    is_r_pos = (w_off == 0 and oct_pos == 0)
                    is_a_pos = (w_off == mf_period - 1 and oct_pos == 3)
                    if is_r_pos or is_a_pos:
                        continue
                    assert byte_val == 0, (
                        f"Framing FAIL: K={k} F={f} MF{mf_idx} word[{w_off}] "
                        f"oct[{oct_pos}]: expected 0x00, got 0x{byte_val:02X} "
                        f"(no config/Q in non-MF2)"
                    )
                    assert not is_k, (
                        f"Framing FAIL: K={k} F={f} MF{mf_idx} word[{w_off}] "
                        f"oct[{oct_pos}]: unexpected K-flag in non-MF2 interior"
                    )


# ---------------------------------------------------------------------------
# Config-octet bench (proves the RTL fix)
# ---------------------------------------------------------------------------

@cocotb.test()
async def test_ilas02_config_octets(dut):
    """Config octets: MF1 (mfCnt=0x01) /Q/ + 14 config octets match golden model byte-for-byte.

    Config octets (including FCHK) must be present in MF1 and absent from
    MF0, MF2, MF3.  Proves the ILAS config-octet RTL fix.
    """
    k = env_int("K_G", default=32)
    f = env_int("F_G", default=2)
    mf_period = (k * f) // 4

    # Read config values from env.  Config generics (DID_G etc.) use RTL defaults
    # (0) since they cannot be overridden via GHDL -g for slv types without
    # format conversion.  Runtime ports (LID/SCR/SUBCLASS) are set via extra_env.
    did    = 0
    bid    = 0
    m      = 0
    n      = 0
    nprime = 0
    cs     = 0
    s      = 0
    hd     = 0
    cf     = 0
    lid    = env_int("LID",      default=0)
    scr    = env_int("SCR",      default=0)
    subcls = env_int("SUBCLASS", default=0)
    l_g    = env_int("L_G",      default=1)

    dut.enable_i.setimmediatevalue(0)
    dut.ilas_i.setimmediatevalue(0)
    dut.lmfc_i.setimmediatevalue(0)
    dut.lid_i.setimmediatevalue(lid)
    dut.scrEnable_i.setimmediatevalue(scr)
    dut.subClass_i.setimmediatevalue(subcls)
    dut.rst.setimmediatevalue(1)

    tb = JesdTB(dut)
    await tb.reset()

    # Golden model using the same values driven into the DUT
    config_octets = build_ilas_config_octets(
        did=did, bid=bid, lid=lid, scr=scr, l_val=l_g - 1,
        f_val=f, k_val=k, m=m, cs=cs, n=n,
        nprime=nprime, subclassv=subcls, jesdv=1, s=s, hd=hd, cf=cf,
    )

    # Verify FCHK
    expected_fchk = sum(config_octets[:13]) & 0xFF
    assert config_octets[13] == expected_fchk, (
        f"Config-octet FAIL: golden FCHK: expected 0x{expected_fchk:02X}, "
        f"got 0x{config_octets[13]:02X}"
    )

    golden = build_ilas_gt_words(k=k, f=f, num_mf=4, config_octets=config_octets)

    words = await capture_ilas_words(dut, tb, k=k, f=f, num_mf=4)

    # Find first /R/ to locate MF0 start
    first_r = None
    for i, (data, datak) in enumerate(words):
        octets = decode_gt_word(data, datak)
        if octets[0] == (R_CHAR, True):
            first_r = i
            break

    assert first_r is not None, (
        f"Config-octet FAIL: K={k} F={f}: no /R/ found in captured stream"
    )

    # --- Test 1: MF1 (second multiframe) carries /Q/ at octet 1 ---
    mf1_start = first_r + 1 * mf_period
    assert mf1_start < len(words), (
        f"Config-octet FAIL: K={k} F={f}: not enough words for MF1 (need {mf1_start}+, have {len(words)})"
    )

    mf1_w0_data, mf1_w0_datak = words[mf1_start]
    mf1_w0_octets = decode_gt_word(mf1_w0_data, mf1_w0_datak)

    assert mf1_w0_octets[0] == (R_CHAR, True), (
        f"Config-octet FAIL: K={k} F={f} MF1 word0 oct0: "
        f"expected /R/ (0x{R_CHAR:02X}, K), got {mf1_w0_octets[0]}"
    )
    assert mf1_w0_octets[1] == (Q_CHAR, True), (
        f"Config-octet FAIL: K={k} F={f} MF1 word0 oct1: "
        f"expected /Q/ (0x{Q_CHAR:02X}, K), got {mf1_w0_octets[1]}"
    )

    # --- Test 2: MF1 matches golden model byte-for-byte ---
    golden_mf1 = golden[1 * mf_period : 2 * mf_period]
    dut_mf1    = words[mf1_start : mf1_start + mf_period]

    assert len(dut_mf1) == len(golden_mf1), (
        f"Config-octet FAIL: K={k} F={f} MF1 length mismatch"
    )

    for w_idx, ((gdata, gdatak), (ddata, ddatak)) in enumerate(
        zip(golden_mf1, dut_mf1)
    ):
        g_octs = decode_gt_word(gdata, gdatak)
        d_octs = decode_gt_word(ddata, ddatak)
        assert g_octs == d_octs, (
            f"Config-octet FAIL: K={k} F={f} MF1 word[{w_idx}] mismatch:\n"
            f"  golden={[(hex(b), ik) for b, ik in g_octs]}\n"
            f"  DUT   ={[(hex(b), ik) for b, ik in d_octs]}"
        )

    # --- Test 2b: octet-3 lane-count field advertises L-1 explicitly ---
    # cfg[2..5] land in the GT word right after the /R/+/Q/ opener (RTL wordCnt=2):
    # cfg[2]@oct0, cfg[3]@oct1, cfg[4]@oct2, cfg[5]@oct3.  octet 3 carries SCR|L-1.
    cfg_word_octets = decode_gt_word(*words[mf1_start + 1])
    octet3_val = cfg_word_octets[1][0]
    assert (octet3_val & 0x1F) == (l_g - 1), (
        f"ILAS lane-count FAIL: K={k} F={f} L_G={l_g}: octet-3 L field "
        f"expected L-1={l_g - 1}, got {octet3_val & 0x1F}"
    )

    # --- Test 3: Config octets absent from MF0, MF2, MF3 ---
    for mf_idx in [0, 2, 3]:
        mf_start = first_r + mf_idx * mf_period
        for w_off in range(mf_period):
            word_pos = mf_start + w_off
            if word_pos >= len(words):
                break
            data, datak = words[word_pos]
            oct_list = decode_gt_word(data, datak)
            for oct_pos, (byte_val, is_k) in enumerate(oct_list):
                is_r_pos = (w_off == 0 and oct_pos == 0)
                is_a_pos = (w_off == mf_period - 1 and oct_pos == 3)
                if is_r_pos or is_a_pos:
                    continue
                assert byte_val == 0, (
                    f"Config-octet FAIL: K={k} F={f} MF{mf_idx} word[{w_off}] "
                    f"oct[{oct_pos}]: expected 0x00 (no config outside MF1), "
                    f"got 0x{byte_val:02X}"
                )
                assert not is_k, (
                    f"Config-octet FAIL: K={k} F={f} MF{mf_idx} word[{w_off}] "
                    f"oct[{oct_pos}]: unexpected K-flag outside MF1"
                )


# ---------------------------------------------------------------------------
# pytest wrappers
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_JesdIlasGen_ilas01(parameters):
    """Framing: /R/ open + /A/ close across F/K sweep."""
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.jesdilasgen",
        parameters=parameters,
        extra_env={**parameters, "COCOTB_TEST_FILTER": "test_ilas01_framing"},
    )


@pytest.mark.parametrize("parameters", ILAS02_SWEEP)
def test_JesdIlasGen_ilas02(parameters):
    """Config octets: MF1 /Q/ + 14 config octets match golden model byte-for-byte."""
    hdl_params = hdl_parameters_from(parameters)
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.jesdilasgen",
        parameters=hdl_params,
        extra_env={**parameters, "COCOTB_TEST_FILTER": "test_ilas02_config_octets"},
    )


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_JesdIlasGen(parameters):
    """Full suite: framing + config-octet default-config parameters."""
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.jesdilasgen",
        parameters=parameters,
        extra_env=parameters,
    )
