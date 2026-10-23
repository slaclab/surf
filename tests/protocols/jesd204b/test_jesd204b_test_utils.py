##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################
"""
Tests for jesd204b_test_utils golden LFSR model, KNOWN_ANSWER_VECTORS, and helpers.

Test methodology:
- Sweep: hand-computed anchor tuples, round-trip sequences, degenerate cases
- Stimulus: lfsr_scramble_tx / lfsr_descramble_rx called directly (pure Python)
- Checks: anchor equality, round-trip identity after self-sync window, non-degenerate
  scramble with non-zero seed, KNOWN_ANSWER_VECTORS length and content
- Timing: pure Python; no cocotb simulation required
"""

from __future__ import annotations

def test_import_exports():
    """Package exports all required symbols."""
    from tests.protocols.jesd204b.jesd204b_test_utils import (  # noqa: F401
        KNOWN_ANSWER_VECTORS,
        JesdTB,
        lfsr_descramble_rx,
        lfsr_scramble_tx,
        measure_lmfc_period,
    )


def test_known_answer_vectors_length():
    """KNOWN_ANSWER_VECTORS has at least 2 anchor tuples."""
    from tests.protocols.jesd204b.jesd204b_test_utils import KNOWN_ANSWER_VECTORS

    assert len(KNOWN_ANSWER_VECTORS) >= 2


def test_known_answer_vectors_anchors():
    """Every (input, lfsr_init, expected) anchor passes lfsr_scramble_tx."""
    from tests.protocols.jesd204b.jesd204b_test_utils import (
        KNOWN_ANSWER_VECTORS,
        lfsr_scramble_tx,
    )

    for input_word, lfsr_init, expected in KNOWN_ANSWER_VECTORS:
        result = lfsr_scramble_tx([input_word], lfsr_init)
        assert result[0] == expected, (
            f"Anchor failed: input={hex(input_word)}, lfsr_init={hex(lfsr_init)}, "
            f"expected={hex(expected)}, got={hex(result[0])}"
        )


def test_roundtrip_after_transient():
    """Round-trip: descramble(scramble(w)) == w for words [1:] (first word self-sync)."""
    from tests.protocols.jesd204b.jesd204b_test_utils import (
        lfsr_descramble_rx,
        lfsr_scramble_tx,
    )

    w = [0x11223344, 0xDEADBEEF, 0xCAFEF00D, 0x01020304]
    scrambled = lfsr_scramble_tx(w, 0)
    recovered, _ = lfsr_descramble_rx(scrambled, 0)
    assert recovered[1:] == w[1:], (
        f"Round-trip mismatch after transient: {[hex(r) for r in recovered[1:]]} "
        f"!= {[hex(x) for x in w[1:]]}"
    )


def test_scramble_not_passthrough_nonzero_seed():
    """Scrambling all-zeros with a non-zero LFSR seed produces non-zero output."""
    from tests.protocols.jesd204b.jesd204b_test_utils import lfsr_scramble_tx

    # lfsr_init=1: LFSR is seeded — output must differ from zero input
    result = lfsr_scramble_tx([0, 0, 0, 0], 1)
    assert result != [0, 0, 0, 0], "lfsr_scramble_tx with nonzero seed must scramble"


def test_descramble_returns_final_lfsr():
    """lfsr_descramble_rx returns (list, int) tuple."""
    from tests.protocols.jesd204b.jesd204b_test_utils import lfsr_descramble_rx

    result = lfsr_descramble_rx([0xDEADBEEF], 0)
    assert isinstance(result, tuple) and len(result) == 2
    assert isinstance(result[0], list)
    assert isinstance(result[1], int)


def test_scramble_tx_msb_first():
    """TX: processes bits MSB-first — first scrambled bit comes from bit 31."""
    from tests.protocols.jesd204b.jesd204b_test_utils import lfsr_scramble_tx

    # With lfsr=0 and input=0x80000000 (only MSB set), first output bit is 1
    # (since lfsr[13]==0 and lfsr[14]==0 at start, so out_bit = 1 XOR 0 XOR 0 = 1)
    result = lfsr_scramble_tx([0x80000000], 0)
    assert (result[0] >> 31) & 1 == 1, "MSB of input 0x80000000 should pass through at zero lfsr"


# ---------------------------------------------------------------------------
# ILAS golden-model tests
# ---------------------------------------------------------------------------


def test_build_ilas_config_octets_14_elements():
    """Test 1: build_ilas_config_octets returns 14-element list; FCHK at index 13.

    Octet-8 packing (Table 21 §8.3):
    - bits[7:5] = SUBCLASSV<2:0>, bits[4:0] = N'<4:0>.
    Octet-9 packing: bits[7:5] = JESDV<2:0> (=001 for JESD204B), bits[4:0] = S<4:0>.
    FCHK = sum(octets[0:13]) mod 256.
    """
    from tests.protocols.jesd204b.jesd204b_test_utils import build_ilas_config_octets

    octs = build_ilas_config_octets(f_val=2, k_val=32)
    assert len(octs) == 14, f"Expected 14 octets, got {len(octs)}"
    assert octs[0] == 0, f"octet[0] DID should be 0, got {octs[0]}"
    assert octs[13] == sum(octs[:13]) & 0xFF, (
        f"FCHK mismatch: octs[13]={hex(octs[13])}, "
        f"sum([:13])={hex(sum(octs[:13]) & 0xFF)}"
    )


def test_build_ilas_config_octets_known_answer():
    """Test 2: hand-computed known-answer vector (f_val=2, k_val=32, jesdv=1).

    All other parameters zero. Computed per Table 21 with octet-8/9 packing:
      octs[4]  = f_val-1 = 1
      octs[5]  = k_val-1 = 31
      octs[8]  = (SUBCLASSV=0)<<5 | (NPRIME=0) = 0
      octs[9]  = (JESDV=1)<<5 | (S=0) = 32
      FCHK     = 1+31+32 = 64 = 0x40
    """
    from tests.protocols.jesd204b.jesd204b_test_utils import build_ilas_config_octets

    octs = build_ilas_config_octets(f_val=2, k_val=32, jesdv=1)
    expected = [0, 0, 0, 0, 1, 31, 0, 0, 0, 32, 0, 0, 0, 64]
    assert octs == expected, (
        f"Known-answer mismatch:\n  got:      {[hex(b) for b in octs]}\n"
        f"  expected: {[hex(b) for b in expected]}"
    )


def test_decode_gt_word_byte_order():
    """Test 3: decode_gt_word(0xAABBCCDD, 0b0001) LSB-first byte order.

    SURF GT byte order: data[7:0] = first transmitted octet (index 0).
    K-flag bit 0 maps to octet at index 0.
    """
    from tests.protocols.jesd204b.jesd204b_test_utils import decode_gt_word

    result = decode_gt_word(0xAABBCCDD, 0b0001)
    expected = [(0xDD, True), (0xCC, False), (0xBB, False), (0xAA, False)]
    assert result == expected, f"decode_gt_word mismatch: {result} != {expected}"


def test_build_ilas_gt_words_structure():
    """Test 4: build_ilas_gt_words returns num_mf*(k*f//4) tuples with correct framing.

    MF index 0, 2, 3: opening word data[7:0]=R_CHAR (K), closing word data[31:24]=A_CHAR (K).
    MF index 1: opening word has R_CHAR at [7:0] and Q_CHAR at [15:8] (both K-flagged);
                followed by 14 config octets packed at octets 2..15.

    Uses k=32, f=4 (default case) for the full 14-octet config fit check
    (k*f=128 octets = 32 GT words per MF, config fits at octets 2..15 of MF1).
    """
    from tests.protocols.jesd204b.jesd204b_test_utils import (
        build_ilas_config_octets,
        build_ilas_gt_words,
        decode_gt_word,
        R_CHAR, A_CHAR, Q_CHAR,
    )

    k, f, num_mf = 32, 4, 4
    gt_words_per_mf = k * f // 4  # = 32
    config_octets = build_ilas_config_octets(f_val=f, k_val=k)
    words = build_ilas_gt_words(k=k, f=f, num_mf=num_mf, config_octets=config_octets)

    assert len(words) == num_mf * gt_words_per_mf, (
        f"Expected {num_mf * gt_words_per_mf} GT words, got {len(words)}"
    )

    # MF0: opening word has R_CHAR at data[7:0], K-flag bit 0 set
    mf0_open = words[0]
    assert (mf0_open[0] & 0xFF) == R_CHAR, (
        f"MF0 opening word[7:0] should be R_CHAR=0x{R_CHAR:02x}, got 0x{mf0_open[0]&0xFF:02x}"
    )
    assert (mf0_open[1] >> 0) & 1 == 1, "MF0 opening word K bit 0 should be set"

    # MF0: closing word has A_CHAR at data[31:24], K-flag bit 3 set
    mf0_close = words[gt_words_per_mf - 1]
    assert (mf0_close[0] >> 24) == A_CHAR, (
        f"MF0 closing word[31:24] should be A_CHAR=0x{A_CHAR:02x}, "
        f"got 0x{mf0_close[0]>>24:02x}"
    )
    assert (mf0_close[1] >> 3) & 1 == 1, "MF0 closing word K bit 3 should be set"

    # MF1 opening: R_CHAR at [7:0] and Q_CHAR at [15:8]
    mf1_open = words[gt_words_per_mf]
    assert (mf1_open[0] & 0xFF) == R_CHAR, (
        f"MF1 opening [7:0] should be R_CHAR, got 0x{mf1_open[0]&0xFF:02x}"
    )
    assert (mf1_open[0] >> 8) & 0xFF == Q_CHAR, (
        f"MF1 opening [15:8] should be Q_CHAR=0x{Q_CHAR:02x}, "
        f"got 0x{(mf1_open[0]>>8)&0xFF:02x}"
    )
    assert (mf1_open[1] >> 1) & 1 == 1, "MF1 opening word K bit 1 (Q_CHAR) should be set"

    # MF1: verify all 14 config octets are present (using decode_gt_word)
    # Config starts at octet 2 of MF1 (after /R/ and /Q/)
    mf1_octets_flat = []
    for w in words[gt_words_per_mf : 2 * gt_words_per_mf]:
        for byte_val, _ in decode_gt_word(w[0], w[1]):
            mf1_octets_flat.append(byte_val)
    # octets 0=/R/, 1=/Q/, 2..15=config[0..13]
    for cfg_i, expected in enumerate(config_octets):
        got = mf1_octets_flat[2 + cfg_i]
        assert got == expected, (
            f"MF1 config octet [{cfg_i}]: expected 0x{expected:02x}, got 0x{got:02x}"
        )


# ---------------------------------------------------------------------------
# RX timeline builder and helpers
# ---------------------------------------------------------------------------


def test_rx_exports_available():
    """RX exports: build_rx_link_timeline, inject_stable_k, inject_disparity_err,
    predict_char_restoration, endian_swap_32 are importable."""
    from tests.protocols.jesd204b.jesd204b_test_utils import (  # noqa: F401
        build_rx_link_timeline,
        endian_swap_32,
        inject_disparity_err,
        inject_stable_k,
        predict_char_restoration,
    )


def test_build_rx_link_timeline_segments():
    """build_rx_link_timeline returns dict with cgs/ilas/data keys."""
    from tests.protocols.jesd204b.jesd204b_test_utils import build_rx_link_timeline

    t = build_rx_link_timeline(
        k=32, f=2, num_mf=4, scr=False,
        config_octets=[0] * 14,
        data_words=[0x11223344, 0x55667788],
    )
    assert set(t) == {'cgs', 'ilas', 'data'}, f"Expected keys cgs/ilas/data, got {set(t)}"


def test_build_rx_link_timeline_cgs_datak():
    """CGS segment: all words have datak=0xF (all-K K28.5 fill)."""
    from tests.protocols.jesd204b.jesd204b_test_utils import build_rx_link_timeline

    t = build_rx_link_timeline(
        k=32, f=2, num_mf=4, scr=False,
        config_octets=[0] * 14,
        data_words=[0xABCD1234],
        cgs_count=8,
    )
    assert len(t['cgs']) == 8, f"cgs_count=8 but got {len(t['cgs'])} words"
    assert all(dk == 0xF for _, dk in t['cgs']), "All CGS datak must be 0xF"


def test_build_rx_link_timeline_ilas_length():
    """ilas segment length matches build_ilas_gt_words output."""
    from tests.protocols.jesd204b.jesd204b_test_utils import (
        build_ilas_gt_words,
        build_rx_link_timeline,
    )

    k, f, num_mf = 32, 2, 4
    cfg = [0] * 14
    t = build_rx_link_timeline(k=k, f=f, num_mf=num_mf, scr=False,
                               config_octets=cfg, data_words=[])
    expected_len = len(build_ilas_gt_words(k=k, f=f, num_mf=num_mf, config_octets=cfg))
    assert len(t['ilas']) == expected_len, (
        f"ilas length {len(t['ilas'])} != expected {expected_len}"
    )


def test_build_rx_link_timeline_data_plain():
    """data segment without scrambling: datak=0, data words match input."""
    from tests.protocols.jesd204b.jesd204b_test_utils import build_rx_link_timeline

    words = [0xDEADBEEF, 0xCAFEF00D]
    t = build_rx_link_timeline(k=32, f=2, num_mf=4, scr=False,
                               config_octets=[0] * 14, data_words=words)
    assert all(dk == 0 for _, dk in t['data']), "Plain data datak must be 0"
    assert [d for d, _ in t['data']] == words, "Plain data words must match input"


def test_build_rx_link_timeline_data_scrambled():
    """data segment with scr=True: words are scrambled via lfsr_scramble_tx."""
    from tests.protocols.jesd204b.jesd204b_test_utils import (
        build_rx_link_timeline,
        lfsr_scramble_tx,
    )

    words = [0x11223344, 0x55667788, 0x99AABBCC]
    t = build_rx_link_timeline(k=32, f=2, num_mf=4, scr=True,
                               config_octets=[0] * 14, data_words=words)
    expected = lfsr_scramble_tx(words, 0)
    assert [d for d, _ in t['data']] == expected, (
        "Scrambled data words must match lfsr_scramble_tx output"
    )
    assert all(dk == 0 for _, dk in t['data']), "Scrambled data datak must be 0"


def test_inject_stable_k_non_mutating():
    """inject_stable_k does not mutate the original list."""
    from tests.protocols.jesd204b.jesd204b_test_utils import inject_stable_k

    original = [(0x11223344, 0)] * 8
    _ = inject_stable_k(original, 2, count=4)
    assert original[2] == (0x11223344, 0), "inject_stable_k must not mutate input"


def test_inject_stable_k_content():
    """inject_stable_k replaces count words with K28.5 all-K (datak=0xF)."""
    from tests.protocols.jesd204b.jesd204b_test_utils import inject_stable_k

    K_WORD = (0xBC << 24) | (0xBC << 16) | (0xBC << 8) | 0xBC
    original = [(0x11223344, 0)] * 8
    result = inject_stable_k(original, 2, count=4)
    for i in range(2, 6):
        assert result[i] == (K_WORD, 0xF), (
            f"index {i} should be K28.5 all-K, got {hex(result[i][0])}/{hex(result[i][1])}"
        )
    # Words outside the range are unchanged
    assert result[0] == original[0]
    assert result[6] == original[6]


def test_endian_swap_32_self_inverse():
    """endian_swap_32 applied twice returns the original value."""
    from tests.protocols.jesd204b.jesd204b_test_utils import endian_swap_32

    for w in [0x11223344, 0xDEADBEEF, 0x00000000, 0xFFFFFFFF]:
        assert endian_swap_32(endian_swap_32(w)) == w, (
            f"endian_swap_32 not self-inverse for {hex(w)}"
        )


def test_endian_swap_32_known_answer():
    """endian_swap_32 swaps the two 16-bit halves."""
    from tests.protocols.jesd204b.jesd204b_test_utils import endian_swap_32

    # 0x11223344 -> lo=0x3344, hi=0x1122 -> result = (0x3344<<16)|(0x1122) = 0x33441122
    assert endian_swap_32(0x11223344) == 0x33441122, (
        f"endian_swap_32(0x11223344) should be 0x33441122, "
        f"got {hex(endian_swap_32(0x11223344))}"
    )


def test_predict_char_replacement_nonscrambled():
    """Test 5: predict_char_replacement round-trips for non-scrambled input.

    Non-scrambled: frame/multiframe boundary octets where octet == previous frame's
    octet are replaced by F_CHAR/A_CHAR. Use a simple all-zero input where no
    replacement fires (all zeros, prev-frame equality on boundary octets = still 0,
    so no K-char substitution unless equality holds; test verifies output is returned
    as a list of (data_32b, datak_4b) tuples with correct length).
    """
    from tests.protocols.jesd204b.jesd204b_test_utils import predict_char_replacement

    # Use a simple all-zero input sequence; verify output shape
    f = 2
    sample_words = [0x00000000] * 16
    lmfc_period = 8
    result = predict_char_replacement(
        sample_words,
        f=f,
        lmfc_period_words=lmfc_period,
        scrambled=False,
    )
    assert isinstance(result, list), "predict_char_replacement must return a list"
    assert len(result) == len(sample_words), (
        f"Output length {len(result)} != input length {len(sample_words)}"
    )
    assert all(isinstance(t, tuple) and len(t) == 2 for t in result), (
        "Each element must be a (data_32b, datak_4b) tuple"
    )
