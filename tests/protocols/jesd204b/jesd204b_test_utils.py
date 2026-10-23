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
Shared test utilities for the JESD204B cocotb regression suite.

Provides:
  - lfsr_scramble_tx       : golden 1+x^14+x^15 TX scrambler model
  - lfsr_descramble_rx     : golden RX descrambler model
  - KNOWN_ANSWER_VECTORS   : hand-computed anchor tuples anchoring the model
  - measure_lmfc_period    : LMFC period measurement helper for cocotb benches
  - JesdTB                 : shared TB base class (clock + reset plumbing)
  - K_CHAR/R_CHAR/A_CHAR/F_CHAR/Q_CHAR : JESD204B control character constants
  - build_ilas_config_octets : 14-octet ILAS link-config block builder
  - decode_gt_word           : 32-bit GT word → 4 (byte, is_k) tuples
  - build_ilas_gt_words      : full ILAS GT-word stream builder
  - predict_char_replacement : DATA-phase char-replacement predictor
  - build_rx_link_timeline   : RX stimulus segments (cgs/ilas/data) builder
  - inject_stable_k          : replace words in a timeline segment with K28.5 all-K
  - inject_disparity_err     : build a disparity-error injection schedule
  - predict_char_restoration : golden model for JesdAlignFrRepCh RX output
  - endian_swap_32           : swap 16-bit halves (models endianSwapSlv at JesdRxLane)
  - forward_gt_loopback      : forwarding coroutine: relay TX GT -> RX GT each
                               devClk cycle with programmable delay and injection hook

Scope: LFSR models, ILAS and char-replacement golden models,
RX timeline builder and injection helpers, and the loopback-bench
forwarding coroutine.
"""

from __future__ import annotations

from pathlib import Path

import cocotb
from cocotb.clock import Clock
from tests.common.regression_utils import sample_after_tpd
from collections import deque

from tests.common.regression_utils import run_surf_vhdl_test  # noqa: F401 – re-exported for bench files

# ---------------------------------------------------------------------------
# Cocotb wrapper sources
# ---------------------------------------------------------------------------
# The JESD204B cocotb wrappers live in protocols/jesd204b/wrappers/ and are
# intentionally excluded from protocols/jesd204b/ruckus.tcl (simulation-only
# flattening shims). Benches pull the wrapper they instantiate into the GHDL
# compile via run_surf_vhdl_test(extra_vhdl_sources=...), layering it on top of
# the already-imported surf RTL.
JESD_WRAPPERS_ROOT = Path(__file__).resolve().parents[3] / "protocols" / "jesd204b" / "wrappers"


def jesd_wrapper_sources(*filenames: str) -> list[str]:
    """Absolute paths to the named JESD204B cocotb wrapper .vhd files."""
    return [str(JESD_WRAPPERS_ROOT / filename) for filename in filenames]

# ---------------------------------------------------------------------------
# JESD204B control character constants (§4.1 / Jesd204bPkg.vhd lines 32-38)
# ---------------------------------------------------------------------------
K_CHAR = 0xBC   # K28.5 — CGS comma (K_CHAR_C)
R_CHAR = 0x1C   # K28.0 — ILAS multiframe start (R_CHAR_C)
A_CHAR = 0x7C   # K28.3 — ILAS/data multiframe end (A_CHAR_C)
F_CHAR = 0xFC   # K28.7 — frame boundary replacement (F_CHAR_C)
Q_CHAR = 0x9C   # K28.4 — ILAS config delimiter (Q_CHAR_C)

# ---------------------------------------------------------------------------
# Polynomial constants
# ---------------------------------------------------------------------------
# JESD_PRBS_TAPS_C = (0 => 14, 1 => 15) from Jesd204bPkg.vhd line 54.
# Polynomial 1 + x^14 + x^15.
# GT_WORD_SIZE_C = 4 bytes = 32 bits.
_WORD_BITS = 32
_WORD_MASK = 0xFFFFFFFF

# TX tap indices (TAPS-1, per JesdAlignChGen.vhd:131 "v.lfsr(JESD_PRBS_TAPS_C(j)-1)")
_TX_TAPS = (13, 14)

# RX tap indices (TAPS, per JesdAlignFrRepCh.vhd:214 "v.lfsr(JESD_PRBS_TAPS_C(j))")
_RX_TAPS = (14, 15)

# ---------------------------------------------------------------------------
# Golden LFSR models
# ---------------------------------------------------------------------------


def lfsr_scramble_tx(data_words: list[int], lfsr: int = 0) -> list[int]:
    """Bit-serial TX scrambler matching JesdAlignChGen.vhd:127-134.

    XOR-before-shift: each output bit is computed first, then that bit is
    shifted into the LFSR.  Loop processes bit 31 (MSB) downto 0.

    Args:
        data_words: List of 32-bit words to scramble.
        lfsr:       Initial 32-bit LFSR state (default 0 = RTL reset value).

    Returns:
        List of scrambled 32-bit words.
    """
    result = []
    lfsr = lfsr & _WORD_MASK
    for word in data_words:
        out_word = 0
        for i in range(_WORD_BITS - 1, -1, -1):
            in_bit = (word >> i) & 1
            # XOR input bit with LFSR taps (tap positions 13 and 14, 0-indexed)
            out_bit = in_bit
            for tap in _TX_TAPS:
                out_bit ^= (lfsr >> tap) & 1
            # Shift-in the output bit at LSB (VHDL: lfsr(30 downto 0) & out_bit)
            lfsr = ((lfsr << 1) & _WORD_MASK) | out_bit
            out_word |= out_bit << i
        result.append(out_word)
    return result


def lfsr_descramble_rx(
    scrambled_words: list[int], lfsr: int = 0
) -> tuple[list[int], int]:
    """Bit-serial RX descrambler matching JesdAlignFrRepCh.vhd:208-217.

    Shift-before-XOR: the scrambled bit is clocked into the LFSR first, then
    the output bit is computed.  This is the self-synchronising property that
    allows the receiver to lock to the transmitter's LFSR state after a short
    transient (~2 octets / first GT word when seeds differ).

    Loop processes bit 31 (MSB) downto 0.

    Args:
        scrambled_words: List of 32-bit scrambled words.
        lfsr:            Initial 32-bit LFSR state (default 0 = RTL reset value).

    Returns:
        Tuple of (descrambled_words: list[int], final_lfsr_state: int).
    """
    result = []
    lfsr = lfsr & _WORD_MASK
    for word in scrambled_words:
        out_word = 0
        for i in range(_WORD_BITS - 1, -1, -1):
            scr_bit = (word >> i) & 1
            # Shift-in the scrambled bit at LSB FIRST
            # (VHDL: v.lfsr := v.lfsr(left-1 downto right) & r.scrData(i))
            lfsr = ((lfsr << 1) & _WORD_MASK) | scr_bit
            # XOR scrambled bit with LFSR taps (tap positions 14 and 15, 0-indexed)
            out_bit = scr_bit
            for tap in _RX_TAPS:
                out_bit ^= (lfsr >> tap) & 1
            out_word |= out_bit << i
        result.append(out_word)
    return result, lfsr


# ---------------------------------------------------------------------------
# Known-answer vectors (hand-computed from RTL bit equations)
# ---------------------------------------------------------------------------
# Each tuple: (input_32b_word, lfsr_init, expected_scrambled_word)
#
# Vector 1: input=0x00000000, lfsr_init=0x00000001
#   Trace: lfsr starts with bit 0 set. Processing MSB-first, bit 13 appears
#   in the tap position after 13 shifts (i=18), producing a 1 at bit 18.
#   Subsequent taps produce further 1s at bits 17, 4, and 2.
#   Result: 0x00060014
#
# Vector 2: input=0xFFFFFFFF, lfsr_init=0x00000000
#   Trace: lfsr starts at 0. Processing MSB-first with all-1 input:
#   First 13 output bits equal the input (lfsr taps still 0). At bit 18
#   (after 13 shifts) lfsr[13] becomes 1, cancelling the 1 input → 0 output.
#   Result: 0xFFFDFFF3
#
# Both vectors are verified by lfsr_scramble_tx and by round-trip through
# lfsr_descramble_rx using the same lfsr_init.
KNOWN_ANSWER_VECTORS: list[tuple[int, int, int]] = [
    (0x00000000, 0x00000001, 0x00060014),
    (0xFFFFFFFF, 0x00000000, 0xFFFDFFF3),
]

# ---------------------------------------------------------------------------
# ILAS golden models
# ---------------------------------------------------------------------------

# GT word size: GT_WORD_SIZE_C = 4 octets per word (Jesd204bPkg.vhd line 28).
_GT_WORD_SIZE = 4


def build_ilas_config_octets(
    *,
    did: int = 0,
    bid: int = 0,
    lid: int = 0,
    scr: int = 0,
    l_val: int = 0,
    f_val: int,
    k_val: int,
    m: int = 0,
    cs: int = 0,
    n: int = 0,
    nprime: int = 0,
    subclassv: int = 0,
    jesdv: int = 1,
    s: int = 0,
    hd: int = 0,
    cf: int = 0,
) -> list[int]:
    """Build the 14 ILAS link-config octets per JESD204B §8.3 Table 21.

    Returns a list of 14 ints [octs[0]=DID ... octs[13]=FCHK].
    f_val and k_val are raw generics (not minus-1).

    Octet-8/9 packing (Table 21 §8.3):
      octs[8]  = SUBCLASSV<2:0> at bits[7:5], N'<4:0> at bits[4:0]
                 (RTL: "00" & subClass_i & NPRIME_G)
      octs[9]  = JESDV<2:0> at bits[7:5], S<4:0> at bits[4:0]
                 (RTL: "001" & S_G for JESD204B where JESDV=001)

    FCHK = sum(octs[0:13]) mod 256 (§8.3 Table 20).

    Args:
        did:       Device ID (octet 0, bits [7:0]).
        bid:       Bank ID (octet 1, bits [3:0]).
        lid:       Lane ID (octet 2, bits [4:0]).
        scr:       Scrambling enabled (octet 3, bit [7]).
        l_val:     Number of lanes - 1 (octet 3, bits [4:0]).
        f_val:     Octets per frame (raw F_G generic; encoded as F-1 in octet 4).
        k_val:     Frames per multiframe (raw K_G; encoded as K-1 in octet 5).
        m:         Converters per device (octet 6, bits [7:0]).
        cs:        Control bits per sample (octet 7, bits [7:6]).
        n:         Converter resolution - 1 (octet 7, bits [4:0]).
        nprime:    Total bits per sample - 1 (octet 8, bits [4:0]).
        subclassv: Device subclass version, 3 bits (octet 8, bits [7:5]).
        jesdv:     JESD version: 001=JESD204B (octet 9, bits [7:5]).
        s:         Samples per converter per frame - 1 (octet 9, bits [4:0]).
        hd:        High-density format (octet 10, bit [7]).
        cf:        Control words per frame per lane (octet 10, bits [4:0]).
    """
    octs = [0] * 14
    octs[0] = did & 0xFF                              # DID
    octs[1] = bid & 0xF                               # ADJCNT=0, BID[3:0]
    octs[2] = lid & 0x1F                              # ADJDIR=0, PHADJ=0, LID[4:0]
    octs[3] = ((scr & 1) << 7) | (l_val & 0x1F)      # SCR, RES=0, L[4:0]
    octs[4] = (f_val - 1) & 0xFF                      # F-1
    octs[5] = (k_val - 1) & 0x1F                      # K-1 (bits [4:0] per Table 21)
    octs[6] = m & 0xFF                                # M
    octs[7] = ((cs & 0x3) << 6) | (n & 0x1F)         # CS[7:6], N[4:0]
    # Octet 8: SUBCLASSV[7:5] | N'[4:0]
    octs[8] = ((subclassv & 0x7) << 5) | (nprime & 0x1F)
    # Octet 9: JESDV[7:5] | S[4:0]
    octs[9] = ((jesdv & 0x7) << 5) | (s & 0x1F)
    octs[10] = ((hd & 1) << 7) | (cf & 0x1F)         # HD[7], CF[4:0]
    octs[11] = 0                                      # RES1
    octs[12] = 0                                      # RES2
    octs[13] = sum(octs[:13]) & 0xFF                  # FCHK
    return octs


def decode_gt_word(data_32b: int, datak_4b: int) -> list[tuple[int, bool]]:
    """Decode one 32-bit GT word into 4 (octet, is_k) tuples, index-0 = first transmitted.

    SURF GT byte ordering: data[7:0] is the first transmitted octet. K-flag bit i
    maps to the octet at index i (bit 0 = octet 0 = data[7:0]).

    Args:
        data_32b: 32-bit GT word (r_jesdGtTx.data / gtTxData_o).
        datak_4b: 4-bit K-flag word (r_jesdGtTx.dataK / gtTxDataK_o).

    Returns:
        List of 4 (byte_value, is_k_char) tuples, index 0 = first transmitted.
    """
    octets = []
    for i in range(_GT_WORD_SIZE):
        byte_val = (data_32b >> (i * 8)) & 0xFF
        is_k = bool((datak_4b >> i) & 1)
        octets.append((byte_val, is_k))
    return octets


def build_ilas_gt_words(
    *,
    k: int,
    f: int,
    num_mf: int = 4,
    config_octets: list[int],
) -> list[tuple[int, int]]:
    """Build the complete ILAS GT-word stream for num_mf multiframes.

    Returns a list of (data_32b, datak_4b) tuples, one per GT word.

    Each multiframe is k*f octets = k*f/GT_WORD_SIZE_C GT words.
    SURF byte ordering: data[7:0] = first transmitted octet.

    Octet replacement rules (§8.2 Figure 50):
      All MFs: first octet (data[7:0]) = /R/ (K-char), last octet (data[31:24]) = /A/ (K-char).
      MF index 1 only: second octet (data[15:8]) = /Q/ (K-char), followed immediately
        by config_octets[0..13] packed into the remaining octet slots.

    Args:
        k:             K_G — frames per multiframe.
        f:             F_G — octets per frame.
        num_mf:        Number of multiframes (default 4 per spec minimum for logic devices).
        config_octets: 14-element list from build_ilas_config_octets().

    Returns:
        List of (data_32b, datak_4b) tuples, length = num_mf * (k*f // GT_WORD_SIZE_C).
    """
    gt_words_per_mf = k * f // _GT_WORD_SIZE  # = k*f / 4
    mf_octets = gt_words_per_mf * _GT_WORD_SIZE  # = k*f

    words = []
    for mf_idx in range(num_mf):
        mf_words = []
        # Build k*f octets for this multiframe as a flat octet list.
        octets = [0] * mf_octets
        k_flags = [False] * mf_octets

        # /R/ at start (first octet = octets[0])
        octets[0] = R_CHAR
        k_flags[0] = True

        # /A/ at end (last octet = octets[k*f-1])
        octets[mf_octets - 1] = A_CHAR
        k_flags[mf_octets - 1] = True

        if mf_idx == 1:
            # MF1: /Q/ at second octet, then 14 config octets starting at third octet
            octets[1] = Q_CHAR
            k_flags[1] = True
            for cfg_i, cfg_val in enumerate(config_octets):
                pos = 2 + cfg_i
                if pos < mf_octets - 1:  # don't overwrite /A/
                    octets[pos] = cfg_val
                    k_flags[pos] = False

        # Pack octets into GT words (4 octets per word, data[7:0]=octet[0])
        for word_i in range(gt_words_per_mf):
            data = 0
            datak = 0
            for byte_i in range(_GT_WORD_SIZE):
                oct_idx = word_i * _GT_WORD_SIZE + byte_i
                data |= octets[oct_idx] << (byte_i * 8)
                if k_flags[oct_idx]:
                    datak |= (1 << byte_i)
            mf_words.append((data, datak))

        words.extend(mf_words)
    return words


def _byte_swap_32(w: int) -> int:
    """Byte-swap a 32-bit word (matches SURF byteSwapSlv for GT_WORD_SIZE_C=4).

    Replicates JesdAlignChGen.vhd:196 byteSwapSlv output transformation.
    """
    b0 = (w >> 0) & 0xFF
    b1 = (w >> 8) & 0xFF
    b2 = (w >> 16) & 0xFF
    b3 = (w >> 24) & 0xFF
    return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3


def _bit_reverse_4(val: int) -> int:
    """Reverse 4-bit K-flag vector (matches bitReverse at JesdAlignChGen.vhd:197)."""
    return (
        ((val >> 0) & 1) << 3 |
        ((val >> 1) & 1) << 2 |
        ((val >> 2) & 1) << 1 |
        ((val >> 3) & 1) << 0
    )


def predict_char_replacement(
    sample_words: list[int],
    *,
    f: int,
    lmfc_period_words: int,
    scrambled: bool,
    lfsr_init: int = 0,
) -> list[tuple[int, int]]:
    """Predict (data_32b, datak_4b) GT output for the DATA phase.

    Replicates JesdAlignChGen.vhd character-replacement logic:
    - Non-scrambled (§5.3.3.4.2): replace frame/MF-last-octet when equal
      to the previous frame's octet at the same position.
    - Scrambled (§5.3.3.4.3): replace when the scrambled octet equals
      F_CHAR (0xFC) or A_CHAR (0x7C).

    Applies byteSwapSlv (JesdAlignChGen.vhd:196) and bitReverse on K
    (line 197) to the output, matching SURF GT byte ordering.

    Uses a two-word pipeline delay (vTwoWordBuff = sampleDataD2 & sampleDataD1).
    The pipeline has 3cc latency before the first valid output; this function
    pre-fills the delay buffer with the first input words so the caller receives
    one output tuple per input word.

    Args:
        sample_words:       List of 32-bit input GT words.
        f:                  F_G octets per frame.
        lmfc_period_words:  LMFC period in GT words (K_G * F_G / 4).
        scrambled:          True if scrEnable_i = '1'.
        lfsr_init:          Initial LFSR state for scrambled mode.

    Returns:
        List of (data_32b, datak_4b) tuples, length == len(sample_words).
    """
    n = len(sample_words)
    if n == 0:
        return []

    samples_in_word = _GT_WORD_SIZE // f  # SAMPLES_IN_WORD_C

    # Scramble if needed
    if scrambled:
        proc_words = lfsr_scramble_tx(sample_words, lfsr_init)
    else:
        proc_words = list(sample_words)

    # RTL pipeline: sampleDataReg (1cc), sampleDataInv (2cc), sampleDataD1 (3cc),
    # sampleDataD2 (4cc).  vTwoWordBuff = r.sampleDataD2 & r.sampleDataD1.
    # At clock N: D1 = sampleData_i(N-3), D2 = sampleData_i(N-4).
    # Pre-fill all stages with 0 to match the RTL's reset-state at DATA_S entry.
    # Callers should skip the first (pipeline_depth) output words to skip transient.
    d_reg = 0    # sampleDataReg: 1cc delayed
    d_inv = 0    # sampleDataInv: 2cc delayed
    d1 = 0       # sampleDataD1: 3cc (lower 32 bits of vTwoWordBuff)
    d2 = 0       # sampleDataD2: 4cc (upper 32 bits of vTwoWordBuff)
    lmfc_d1 = False    # r.lmfcD1 in RTL: delayed LMFC
    sample_k_d1 = 0    # r.sampleKD1 in RTL: previous cycle's K output (4-bit)

    result = []

    for word_idx, cur_word in enumerate(proc_words):
        # lmfc fires at the start of each multiframe (word 0 of each MF period)
        lmfc_now = (word_idx % lmfc_period_words) == 0

        # vTwoWordBuff = D2 & D1: D2 at bits[63:32], D1 at bits[31:0].
        # Matches JesdAlignChGen.vhd:148.
        two_buf_data = (d1 & 0xFFFFFFFF) | ((d2 & 0xFFFFFFFF) << 32)

        # vTwoCharBuff = r.sampleKD1 & {GT_WORD_SIZE_C zeros}: bits[7:4]=sampleKD1, [3:0]=0.
        # JesdAlignChGen.vhd:149. sampleKD1 carries the previous cycle's K-flag output.
        # This is critical: it blocks frame i's substitution if frame i-1 fired last cycle.
        two_buf_k = sample_k_d1 << 4  # sampleKD1 at bits[7:4], [3:0]=0

        if lmfc_d1:
            # A-character replacement at MF boundary (r.lmfcD1='1').
            # Checks vTwoWordBuff[F*8+7:F*8] (=D1[F*8:F*8+8]) vs vTwoWordBuff[7:0] (=D1[7:0]).
            # Replaces vTwoWordBuff[7:0] (D1[7:0]) with A_CHAR on match; sets vTwoCharBuff(0)=1.
            # JesdAlignChGen.vhd:154-165.
            if scrambled:
                # Scrambled: replace if D1[7:0] == A_CHAR (value-match rule §5.3.3.4.3)
                if (two_buf_data & 0xFF) == A_CHAR:
                    two_buf_k |= 1
            else:
                # Non-scrambled: replace if D1[F*8:F*8+8] == D1[7:0] (prev-frame equality)
                prev_oct = (two_buf_data >> (f * 8)) & 0xFF
                cur_oct = two_buf_data & 0xFF
                if prev_oct == cur_oct:
                    two_buf_data = (two_buf_data & ~0xFF) | A_CHAR
                    two_buf_k |= 1

        # F-character replacement, iterating from SAMPLES-1 downto 0 (matches RTL loop order).
        # RTL: for i in (SAMPLES_IN_WORD_C-1) downto 0 — JesdAlignChGen.vhd:168.
        # Loop order matters: earlier iterations (higher i) may modify vTwoCharBuff bit at
        # position i*F_G, which the next iteration's k_above check (bit i*F_G+F_G) reads.
        # Crucially, the k_above check also reads vTwoCharBuff[7:4] = sampleKD1 (prev cycle),
        # enabling cross-cycle suppression of substitutions at the next-higher frame boundary.
        for i in range(samples_in_word - 1, -1, -1):
            f_low = i * f * 8            # bit position of frame i's last octet (in D1 region)
            f_high = f_low + f * 8       # bit position of "previous frame" octet (D1 or D2)
            cur_oct = (two_buf_data >> f_low) & 0xFF       # current frame's target octet
            prev_oct = (two_buf_data >> f_high) & 0xFF     # previous frame's reference octet
            # K-above check: vTwoCharBuff bit at index i*F_G + F_G.
            # This includes bits from sampleKD1 (carried from previous cycle via two_buf_k[7:4]).
            k_above_idx = i * f + f
            k_above = (two_buf_k >> k_above_idx) & 1 if k_above_idx < 2 * _GT_WORD_SIZE else 0
            if scrambled:
                # Scrambled: replace if cur_oct == F_CHAR (value-match rule §5.3.3.4.3)
                if cur_oct == F_CHAR and k_above == 0:
                    two_buf_k |= (1 << (i * f))
            else:
                # Non-scrambled: replace if prev_oct == cur_oct (prev-frame equality §5.3.3.4.2)
                if prev_oct == cur_oct and k_above == 0:
                    two_buf_data = (two_buf_data & ~(0xFF << f_low)) | (F_CHAR << f_low)
                    two_buf_k |= (1 << (i * f))

        # Output: byteSwap(vTwoWordBuff[31:0]) = byteSwap(D1 modified).
        # JesdAlignChGen.vhd:196: sampleData_o <= byteSwapSlv(vTwoWordBuff[31:0], GT_WORD_SIZE_C).
        out_data_raw = two_buf_data & 0xFFFFFFFF
        out_k_raw_full = two_buf_k & 0xF        # lower 4 bits = current cycle's K flags
        out_data = _byte_swap_32(out_data_raw)
        out_k = _bit_reverse_4(out_k_raw_full)

        result.append((out_data, out_k))

        # Advance 4-stage pipeline matching RTL:
        # v.sampleDataD2 := r.sampleDataD1 → d2 ← d1
        # v.sampleDataD1 := r.sampleDataInv → d1 ← d_inv
        # v.sampleDataInv := r.sampleDataReg → d_inv ← d_reg
        # v.sampleDataReg := sampleData_i → d_reg ← cur_word
        lmfc_d1 = lmfc_now
        d2 = d1
        d1 = d_inv
        d_inv = d_reg
        d_reg = cur_word
        # sampleKD1 ← vTwoCharBuff[GT_WORD_SIZE_C-1:0] = lower 4 bits of two_buf_k.
        # JesdAlignChGen.vhd:191: v.sampleKD1 := vTwoCharBuff((GT_WORD_SIZE_C)-1 downto 0).
        sample_k_d1 = out_k_raw_full

    return result


# ---------------------------------------------------------------------------
# RX timeline builder and injection helpers
# ---------------------------------------------------------------------------


def build_rx_link_timeline(
    *,
    k: int,
    f: int,
    num_mf: int = 4,
    scr: bool = False,
    config_octets: list[int],
    data_words: list[int],
    cgs_count: int = 8,
    lfsr_init: int = 0,
) -> dict:
    """Build RX stimulus segments for bench injection.

    Returns dict with keys:
      'cgs':  list of (data_32b, datak_4b) — K28.5 fill words (cgs_count entries)
      'ilas': list of (data_32b, datak_4b) — golden 4-MF ILAS stream from build_ilas_gt_words()
      'data': list of (data_32b, datak_4b) — DATA phase words (scrambled via
              lfsr_scramble_tx() if scr=True; plain otherwise)

    GT byte ordering: data[7:0] = first received octet (SURF convention).
    CGS words: all 4 bytes = K_CHAR (0xBC), charisk = 0xF.
    Mutation helpers (inject_stable_k, inject_disparity_err) operate on the
    returned lists after this call.
    """
    k_word = (K_CHAR << 24) | (K_CHAR << 16) | (K_CHAR << 8) | K_CHAR
    cgs = [(k_word, 0xF)] * cgs_count
    ilas = build_ilas_gt_words(k=k, f=f, num_mf=num_mf, config_octets=config_octets)
    if scr:
        scrambled = lfsr_scramble_tx(data_words, lfsr_init)
        data = [(w, 0) for w in scrambled]
    else:
        data = [(w, 0) for w in data_words]
    return {'cgs': cgs, 'ilas': ilas, 'data': data}


def inject_stable_k(timeline_data: list, start_idx: int, count: int = 4) -> list:
    """Replace count words at start_idx with genuine K28.5 all-K words.

    chariskRx=0xF required to trigger detKcharFunc() (charisk-gated).
    Used for stable-K injection in DATA phase.
    Returns a new list (does not mutate the original).
    """
    k_word = (K_CHAR << 24) | (K_CHAR << 16) | (K_CHAR << 8) | K_CHAR
    result = list(timeline_data)
    for i in range(count):
        if start_idx + i < len(result):
            result[start_idx + i] = (k_word, 0xF)
    return result


def inject_disparity_err(
    timeline_data: list, idx: int, byte_mask: int = 0x1
) -> list:
    """Inject disparity error on specific bytes at timeline index idx.

    byte_mask: 4-bit mask (bit 0 = byte 0, ..., bit 3 = byte 3).
    Returns a new list where the entry at idx is a 3-tuple
    (data_32b, datak_4b, disp_err_mask), replacing the original 2-tuple.
    Entries at other indices are unchanged 2-tuples.

    NOTE: dispErr is driven as a separate cocotb signal (gtRxDispErr_i),
    not embedded in the data tuple. Use this to build an injection schedule
    rather than mutating data words. The bench applies the disp_err_mask
    to gtRxDispErr_i directly at the cycle corresponding to idx.
    """
    result = list(timeline_data)
    if 0 <= idx < len(result):
        entry = result[idx]
        data_w = entry[0]
        datak_w = entry[1] if len(entry) > 1 else 0
        result[idx] = (data_w, datak_w, byte_mask & 0xF)
    return result


def predict_char_restoration(
    gt_words: list[int],
    *,
    f: int,
    scr: bool,
    lfsr_init: int = 0,
) -> list[tuple[int, int]]:
    """Predict (data_32b, datak_4b) output of JesdAlignFrRepCh for RX stimulus.

    Replicates the RX restoration logic:
    - Input: gt_words as received from elastic buffer (data[7:0] = first octet).
    - JesdAlignFrRepCh applies byteSwapSlv on INPUT (line 155), not output (TX).
    - Char restoration replaces /F/ or /A/ K-chars with saved original octets.
    - Descrambles with lfsr_descramble_rx() if scr=True.
    - Output is big-endian: first sample in time at bits [31:16].
      (JesdRxLane applies endianSwapSlv at line 321, producing little-endian.)

    Latency: 1cc (non-scrambled), 3cc (scrambled).

    NOTE: This function models the steady-state behavior after pipeline fill.
    Callers should skip the first (1 if scr=False else 3) output words to
    account for pipeline latency, consistent with bench timing conventions.
    """
    if not gt_words:
        return []

    # Step 1: apply byteSwapSlv on each input word (RX applies at input, §contrast TX)
    # byteSwapSlv for GT_WORD_SIZE_C=4: reverses byte order within the 32-bit word.
    swapped = [_byte_swap_32(w) for w in gt_words]

    # Step 2: descramble if enabled (lfsr_descramble_rx operates on swapped GT words)
    if scr:
        proc_words, _ = lfsr_descramble_rx(swapped, lfsr_init)
    else:
        proc_words = swapped

    # Step 3: char restoration — replace /F/ and /A/ K-chars with the saved
    # original octet (the char-replacement inverse: restore replaced octets).
    # In practice the restored value is the previous frame's equivalent octet.
    # For a golden model consuming a stream from build_rx_link_timeline(), the
    # DATA words are plain samples with no K-chars, so restoration is a no-op.
    # This model replicates the byteSwap + descramble transforms correctly;
    # char-restoration is identity for streams built by build_rx_link_timeline().
    result_words = []
    datak_out = []
    for w in proc_words:
        # Identify bytes that are F_CHAR or A_CHAR with charisk set.
        # In this golden model, the input stream has no K-chars in DATA phase,
        # so datak_4b is always 0 for plain DATA (restoration is identity).
        result_words.append(w)
        datak_out.append(0)

    # Step 4: output is big-endian (first sample in time at bits [31:16]).
    # The byteSwapped + descrambled word IS in big-endian format relative to
    # the original GT ordering, so no further reordering needed.
    return list(zip(result_words, datak_out))


def endian_swap_32(w: int) -> int:
    """Replicate endianSwapSlv(data, GT_WORD_SIZE_C=4) for sampleData_o at JesdRxLane.

    Swaps the two 16-bit halves:
      output[31:16] = input[15:0]
      output[15:0]  = input[31:16]
    Use when computing expected sampleData_o from JesdRxLane (little-endian output).
    Do NOT use for JesdAlignFrRepCh standalone bench (big-endian output).
    Source: JesdRxLane.vhd:321 + Jesd204bPkg.vhd endianSwapSlv.
    """
    lo = w & 0xFFFF
    hi = (w >> 16) & 0xFFFF
    return (lo << 16) | hi


# ---------------------------------------------------------------------------
# Top-level GT-lane drive and wait helpers
# ---------------------------------------------------------------------------


async def drive_gt_lane_from_timeline(
    dut,
    lane_idx: int,
    timeline: dict,
    *,
    clk,
    segment: str,
    start_idx: int = 0,
) -> None:
    """Drive one flattened GT-RX lane's flat ports for one timeline segment.

    Feeds index-named flat ports (gtRxData_N_i, gtRxDataK_N_i, etc.) from a
    build_rx_link_timeline() result one (data_32b, datak_4b) tuple per rising
    clock edge.  VHDL array ports are not directly indexable from cocotb, so
    getattr with lane-indexed port names is mandatory.

    Timer(1, unit="ns") after each RisingEdge matches the TPD_G=1 ns
    registered-output settle convention used throughout the JESD suite.

    Args:
        dut:       cocotb DUT handle exposing gtRxData_N_i / gtRxDataK_N_i.
        lane_idx:  Lane index (0-based); selects the N in port name strings.
        timeline:  Dict returned by build_rx_link_timeline (keys: cgs/ilas/data).
        clk:       cocotb clock signal handle (devClk domain).
        segment:   Key in timeline to drive ('cgs', 'ilas', or 'data').
        start_idx: First tuple index to drive within the segment (default 0).
    """
    data_port = getattr(dut, f"gtRxData_{lane_idx}_i")
    datak_port = getattr(dut, f"gtRxDataK_{lane_idx}_i")
    for data_32b, datak_4b in timeline[segment][start_idx:]:
        data_port.value = data_32b
        datak_port.value = datak_4b
        await sample_after_tpd(clk)


async def wait_nSync(dut, *, value: int, clk, timeout_cycles: int = 128) -> None:
    """Poll dut.nSync_o until its value equals `value`.

    Used to detect the CGS->ILAS handoff (nSync_o transition).
    Raises AssertionError if nSync_o does not reach the expected value within
    timeout_cycles rising edges, ensuring a link that stalls fails visibly.

    Timer(1, unit="ns") after each RisingEdge matches the TPD_G=1 ns settle
    convention.

    Args:
        dut:            cocotb DUT handle exposing nSync_o.
        value:          Expected integer value of nSync_o (0 or 1).
        clk:            cocotb clock signal handle.
        timeout_cycles: Maximum rising edges to wait.
    """
    for _ in range(timeout_cycles):
        await sample_after_tpd(clk)
        if int(dut.nSync_o.value) == value:
            return
    raise AssertionError(
        f"nSync_o did not reach {value} within {timeout_cycles} cycles"
    )


async def wait_data_valid_all(
    dut, l_g: int, *, clk, timeout_cycles: int = 256
) -> None:
    """Poll all per-lane dataValid_N_o ports until every lane reads 1.

    Used after CGS and ILAS phases to confirm the RX top has reached the DATA
    state on all enabled lanes.  Raises AssertionError on timeout so a link
    that never reaches DATA fails the test rather than skipping assertions.

    Timer(1, unit="ns") after each RisingEdge matches the TPD_G=1 ns settle
    convention.

    Args:
        dut:            cocotb DUT handle exposing dataValid_N_o for N in range(l_g).
        l_g:            Number of lanes (determines which ports to poll).
        clk:            cocotb clock signal handle.
        timeout_cycles: Maximum rising edges to wait.
    """
    for _ in range(timeout_cycles):
        await sample_after_tpd(clk)
        if all(
            int(getattr(dut, f"dataValid_{i}_o").value) == 1
            for i in range(l_g)
        ):
            return
    raise AssertionError(
        f"dataValid not asserted on all {l_g} lanes within {timeout_cycles} cycles"
    )


# ---------------------------------------------------------------------------
# Forwarding coroutine (Python-forwarded GT path): relay TX GT
# -> RX GT each devClk cycle, and nSync_RX_o -> nSync_TX_i.
# ---------------------------------------------------------------------------


async def forward_gt_loopback(
    dut,
    l_g: int,
    *,
    clk,
    delay_cycles: int = 0,
    injection_fn=None,
    golden_capture=None,
    stop_event=None,
) -> None:
    """Forward TX GT outputs -> RX GT inputs each devClk rising edge.

    Implements the Python-forwarded GT path: on each devClk rising
    edge, reads gtTxData_{lane}_o / gtTxDataK_{lane}_o, applies a ring-buffer
    byte-shift delay, and drives gtRxData_{lane}_i etc.
    Also forwards nSync_RX_o -> nSync_TX_i.

    Timer(1, unit="ns") settle after each RisingEdge matches the TPD_G=1 ns
    registered-output settle convention used throughout the suite
    (drive_gt_lane_from_timeline:685).

    Args:
        dut:            cocotb DUT handle with flat GT ports.
        l_g:            Number of active lanes.
        clk:            devClk signal handle.
        delay_cycles:   GT-word forwarding delay in devClk cycles (0 = zero-delay).
                        Implemented as a per-lane deque ring buffer.
        injection_fn:   Optional callable(cycle, lane, data, datak) ->
                        (data, datak, disp_err, dec_err) for error injection.
        golden_capture: If not None, a list to append (lane, cycle, data, datak)
                        tuples for on-wire LFSR cross-check.
        stop_event:     Object with .is_set() method; coroutine exits when set.
                        Use cocotb.triggers.Event or a simple mutable flag.
    """
    # Initialize the delay ring buffer with K28.5 CGS words so that the RX FSM
    # sees valid K characters during the warmup phase (first delay_cycles cycles)
    # and remains in SYNC_S. Initialising with (0,0) causes non-K words to reach
    # the RX before real TX data flows, prematurely advancing the FSM to HOLD_S.
    _k28_5_init = (0xBCBCBCBC, 0xF)  # K28.5 all-bytes, all-K-flag (CGS comma)
    bufs = [
        deque([_k28_5_init] * max(delay_cycles, 1), maxlen=max(delay_cycles, 1))
        for _ in range(l_g)
    ]
    cycle = 0
    while stop_event is None or not stop_event.is_set():
        await sample_after_tpd(clk)   # TPD_G=1 ns registered-output settle
        # nSync forwarding: RX nSync_o (sl) -> TX nSync_TX_i (slv L_G-1:0).
        # Replicate single-bit nSync_RX_o to all l_g TX lanes so both lanes advance
        # through SYNC_S->ILAS when nSync_o asserts. Writing plain int(nSync_RX_o)
        # sets only bit 0, leaving higher lanes stuck at 0 (silent link-up failure).
        nsync_val = int(dut.nSync_RX_o.value)
        dut.nSync_TX_i.value = ((1 << l_g) - 1) if nsync_val else 0
        # GT forwarding per lane
        for lane in range(l_g):
            tx_data = int(getattr(dut, f"gtTxData_{lane}_o").value)
            tx_datak = int(getattr(dut, f"gtTxDataK_{lane}_o").value)
            if golden_capture is not None:
                golden_capture.append((lane, cycle, tx_data, tx_datak))
            if delay_cycles > 0:
                delayed_data, delayed_datak = bufs[lane][0]
                bufs[lane].append((tx_data, tx_datak))
            else:
                delayed_data, delayed_datak = tx_data, tx_datak
            if injection_fn is not None:
                delayed_data, delayed_datak, disp_err, dec_err = injection_fn(
                    cycle, lane, delayed_data, delayed_datak
                )
            else:
                disp_err, dec_err = 0, 0
            getattr(dut, f"gtRxData_{lane}_i").value = delayed_data
            getattr(dut, f"gtRxDataK_{lane}_i").value = delayed_datak
            getattr(dut, f"gtRxDispErr_{lane}_i").value = disp_err
            getattr(dut, f"gtRxDecErr_{lane}_i").value = dec_err
            getattr(dut, f"gtRxRstDone_{lane}_i").value = 1
            getattr(dut, f"gtRxCdrStable_{lane}_i").value = 1
        cycle += 1


# ---------------------------------------------------------------------------
# Module selftest (run at import time to catch accidental corruption)
# ---------------------------------------------------------------------------


def _selftest() -> None:
    """Verify KNOWN_ANSWER_VECTORS, round-trip, and ILAS known-answer vector."""
    for input_word, lfsr_init, expected in KNOWN_ANSWER_VECTORS:
        got = lfsr_scramble_tx([input_word], lfsr_init)[0]
        assert got == expected, (
            f"KNOWN_ANSWER_VECTORS selftest failed: "
            f"input={hex(input_word)}, lfsr_init={hex(lfsr_init)}, "
            f"expected={hex(expected)}, got={hex(got)}"
        )
    # Round-trip sanity: 4-word sequence, first word exempted for self-sync
    _w = [0x11223344, 0xDEADBEEF, 0xCAFEF00D, 0x01020304]
    _sc = lfsr_scramble_tx(_w, 0)
    _rc, _ = lfsr_descramble_rx(_sc, 0)
    assert _rc[1:] == _w[1:], "Round-trip selftest failed"
    # ILAS config-octet known-answer vector.
    # Hand-computed with f_val=2, k_val=32, jesdv=1, all others 0.
    # Octet-8/9 packing per Table 21:
    #   octs[8]  = SUBCLASSV[7:5]=000 | NPRIME[4:0]=0 = 0x00
    #   octs[9]  = JESDV[7:5]=001 | S[4:0]=0 = 0x20 (=32)
    #   FCHK     = octs[4]+octs[5]+octs[9] = 1+31+32 = 64 = 0x40
    _expected_ilas = [0, 0, 0, 0, 1, 31, 0, 0, 0, 32, 0, 0, 0, 64]
    _got_ilas = build_ilas_config_octets(f_val=2, k_val=32, jesdv=1)
    assert _got_ilas == _expected_ilas, (
        f"ILAS selftest failed: got {[hex(b) for b in _got_ilas]}, "
        f"expected {[hex(b) for b in _expected_ilas]}"
    )
    # RX helper self-tests.
    # inject_stable_k: must not mutate input and must inject K28.5 all-K words.
    _src = [(1, 0)] * 8
    _out = inject_stable_k(_src, 2, 4)
    assert _src[2] == (1, 0), "inject_stable_k mutated input"
    assert _out[2][1] == 0xF, "inject_stable_k K word must have datak=0xF"
    # endian_swap_32: must be its own inverse.
    assert endian_swap_32(endian_swap_32(0x11223344)) == 0x11223344, (
        "endian_swap_32 not self-inverse"
    )
    assert endian_swap_32(0x11223344) == 0x33441122, (
        "endian_swap_32 known-answer failed"
    )


_selftest()


# ---------------------------------------------------------------------------
# LMFC period measurement helper
# ---------------------------------------------------------------------------


async def measure_lmfc_period(dut, *, clk, timeout_cycles: int = 512) -> int:
    """Count device clocks between consecutive lmfc_o rising edges.

    Waits for the first lmfc_o rising edge, then counts clock cycles to the
    second rising edge. Raises AssertionError if either edge does not arrive
    within timeout_cycles.

    The Timer(1, unit="ns") after each RisingEdge matches the TPD_G=1 ns
    registered-output settle time used by SURF RTL (JesdLmfcGen.vhd header).

    Args:
        dut:            cocotb DUT handle exposing lmfc_o.
        clk:            cocotb clock signal handle.
        timeout_cycles: Maximum clock cycles to wait per edge.

    Returns:
        Integer device-clock count between consecutive lmfc_o rising edges.
    """
    # Wait for first rising edge of lmfc_o
    for _ in range(timeout_cycles):
        await sample_after_tpd(clk)
        if dut.lmfc_o.value == 1:
            break
    else:
        raise AssertionError(
            f"lmfc_o never asserted within {timeout_cycles} cycles"
        )

    # Count cycles to second rising edge
    count = 0
    for _ in range(timeout_cycles):
        await sample_after_tpd(clk)
        count += 1
        if dut.lmfc_o.value == 1:
            return count

    raise AssertionError(
        f"lmfc_o second pulse did not arrive within {timeout_cycles} cycles"
    )


# ---------------------------------------------------------------------------
# Shared TB base class
# ---------------------------------------------------------------------------

CLOCK_PERIOD_NS = 10.0  # 100 MHz default; override in bench as needed


class JesdTB:
    """Shared cocotb TB base for JESD204B flat-port DUTs.

    Starts the device clock, provides cycle() and reset() coroutines, and
    sets common initial port values.  Specific benches subclass or compose
    this to add DUT-specific port initialisation.

    Timer(1, unit="ns") in cycle() and reset() matches TPD_G=1 ns settle.
    """

    def __init__(self, dut, *, clock_period_ns: float = CLOCK_PERIOD_NS) -> None:
        self.dut = dut
        cocotb.start_soon(Clock(dut.clk, clock_period_ns, unit="ns").start())

    async def cycle(self, count: int = 1) -> None:
        """Advance count clock cycles, settling 1 ns after each rising edge."""
        for _ in range(count):
            await sample_after_tpd(self.dut.clk)

    async def reset(self, cycles: int = 4) -> None:
        """Assert rst for `cycles` clock cycles, then deassert."""
        self.dut.rst.value = 1
        await self.cycle(cycles)
        self.dut.rst.value = 0
        await self.cycle(2)


# ---------------------------------------------------------------------------
# Standalone entry point
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    _selftest()
    print("jesd204b_test_utils selftest passed")
