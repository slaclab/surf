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
# - Sweep: Two elaborations, one per RX_ODD_ALIGN_MODE_G value. The generic
#   gates a constant and a generate, so it cannot be varied inside one build.
# - Stimulus: A bit-accurate serial stream of tagged 20-bit frames feeds a GT
#   model that presents word k as stream[20k + b - d] for a landing offset d and
#   decrements d on every rxSlide pulse. Every one of the 20 possible comma
#   landings is driven, one per test, so the aligner is exercised across its
#   whole input space rather than at a sampled subset.
# - Checks: The property under test is that the fiber-to-rxDataOut latency does
#   not depend on where the CDR happened to land. Each landing must reach
#   alignment, present a correctly comma-aligned word, and -- the part that
#   matters -- present the SAME frame on the SAME cycle as every other landing.
#   Under BITSLIP each landing must also settle using an EVEN rxSlide count and
#   must never assert rxReset. Under RESET the legacy contract is pinned
#   instead: odd landings assert rxReset, even landings do not.
# - Cross-mode: each mode's ABSOLUTE latency is pinned against EXPECTED_TRAIL,
#   so the cost of choosing BITSLIP over RESET (one rxUsrClk) is itself a
#   regression target rather than an unstated consequence of two independent
#   within-mode checks. That check reaches the aligner's boundary contract only;
#   Gtx7Core's mux is reproduced by the harness, not elaborated.
# - Timing: Latency is compared in exact frame indices at a common cycle, which
#   is a stricter statement than comparing rxPhaseAlignmentDone timing. The
#   comparison is held over several cycles so a one-sample coincidence cannot
#   pass. Frames carry a 6-bit sequence tag for exactly this purpose.
# - Does not prove: Anything about the GTX PMA itself. Whether a final offset of
#   1 costs a sub-UI recovered-clock phase step relative to a final offset of 0
#   is a property of the silicon, not of this RTL, and no fabric simulation can
#   settle it. This test proves the fabric contributes no landing-dependent
#   latency of its own; the residual sub-UI term must be measured on hardware.

import os

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import (
    env_int,
    parameter_case,
    run_surf_vhdl_test,
)

WORD_SIZE = 20
CLK_PERIOD_NS = 5.384          # lane 1's measured rxUsrClk period
COMMA = "0101111100"           # K28.5, bits 9:0 of every frame
SLIDE_SETTLE_CYCLES = 70       # SLIDE_WAIT_S burns 64; give it margin
N_FRAMES = 4096

# Whole rxUsrClk of fiber-to-rxDataOut latency each mode adds once aligned, and
# therefore the cost of choosing BITSLIP over RESET. Both entries are asserted
# below, so the delta between them is a checked contract and not just a comment.
#
# RESET takes Gtx7Core's RX_DATA_OUT_RESET_GEN leg (rxDataOut <= rxDataInt),
# combinational off RXDATA through RX_DATA_8B10B_GLUE, so it adds no fabric
# stage. BITSLIP takes RX_DATA_OUT_BITSLIP_GEN, whose select asserts in BOTH
# terminal states, so once aligned it always adds the aligner's one stage. One
# stage is the floor, not a convenience: at final offset 1 the aligned word's
# MSB only arrives with the next GT word.
#
# The delta is therefore one rxUsrClk: 5.385 ns on an LCLS-II link at 3.714
# Gbps, 8.403 ns on an LCLS-I link at 2.380 Gbps. It is constant across
# bring-ups, so it costs a caller one re-calibration rather than introducing
# run-to-run jitter, but it is a real change to the absolute number and a
# reviewer switching a link to BITSLIP will ask for it by name.
#
# Scope: the aligner drives one end of this (rxDataAligned one stage deep, and
# rxDataAlignedSel telling Gtx7Core which leg to take), and that end is
# elaborated. Gtx7Core's mux itself is reproduced by Harness.data_out(), since
# Gtx7Core needs GTXE2_CHANNEL and does not build under GHDL, so an edit to the
# mux expressions is out of reach of this file.
EXPECTED_TRAIL = {"RESET": 0, "BITSLIP": 1}

ODD_ALIGN_MODE = os.environ.get("RX_ODD_ALIGN_MODE_G", "RESET").strip().strip("'")
LANDING = env_int("LANDING", default=0)


def frame_of(m: int) -> int:
    """Frame m: comma in bits 9:0, '1111' in bits 19:16, 6-bit tag in bits 15:10.

    The tag nibble is pinned to all ones so the comma pattern (and its inverse)
    can only match at the true frame boundary; a run of four ones cannot occur
    inside either comma code, which rules out a false landing.
    """
    return (0xF << 16) | ((m % 64) << 10) | int(COMMA, 2)


def bit_at(p: int) -> int:
    if p < 0:
        return 0
    return (frame_of(p // WORD_SIZE) >> (p % WORD_SIZE)) & 1


def gt_word(k: int, d: int) -> int:
    """The GT's parallel word k when the comma lands d bits into the word."""
    word = 0
    for b in range(WORD_SIZE):
        word |= bit_at(WORD_SIZE * k + b - d) << b
    return word


def is_frame(word: int) -> bool:
    return (word & 0x3FF) == int(COMMA, 2) and ((word >> 16) & 0xF) == 0xF


def tag_of(word: int) -> int:
    return (word >> 10) & 0x3F


def expected_tag_at(cycle: int) -> int:
    """Tag this mode must be presenting at `cycle`, per EXPECTED_TRAIL.

    Harness.step() drives GT word index (cycle-1) before clocking, so at `cycle`
    the model is sourcing index cycle-1 and the output must sit EXPECTED_TRAIL
    cycles behind it.
    """
    return (cycle - 1 - EXPECTED_TRAIL[ODD_ALIGN_MODE]) % 64


class Harness:
    """GT model plus Gtx7Core's output mux, wrapped around one aligner."""

    def __init__(self, dut, landing):
        self.dut = dut
        self.offset = landing
        self.landing = landing
        self.slides = 0
        self.saw_reset = False
        self.cycle = 0

        dut.rxRunPhAlignment.value = 0
        dut.rxData.value = 0
        cocotb.start_soon(Clock(dut.rxUsrClk, CLK_PERIOD_NS, unit="ns").start())

    async def release_reset(self):
        for _ in range(10):
            await RisingEdge(self.dut.rxUsrClk)
        self.dut.rxRunPhAlignment.value = 1

    async def step(self):
        """Advance one cycle, presenting the GT word and consuming rxSlide."""
        self.dut.rxData.value = gt_word(self.cycle, self.offset)
        await RisingEdge(self.dut.rxUsrClk)
        await Timer(1, unit="ns")
        self.cycle += 1
        if self.dut.rxReset.value == 1:
            self.saw_reset = True
        if self.dut.rxSlide.value == 1:
            self.offset -= 1
            self.slides += 1

    def data_out(self) -> int:
        """Reproduce Gtx7Core's RX_DATA_OUT_BITSLIP_GEN mux."""
        if ODD_ALIGN_MODE == "BITSLIP" and self.dut.rxDataAlignedSel.value == 1:
            return int(self.dut.rxDataAligned.value)
        return int(self.dut.rxData.value)

    def aligned(self) -> bool:
        return self.dut.rxPhaseAlignmentDone.value == 1


async def run_landing(dut, landing):
    tb = Harness(dut, landing)
    await tb.release_reset()

    # Worst case is landing 19: 18 slides, each costing SLIDE_WAIT_S's full wait.
    budget = 20 * SLIDE_SETTLE_CYCLES
    for _ in range(budget):
        await tb.step()
        if tb.aligned():
            break
    return tb


@cocotb.test()
async def bitslip_landing_is_latency_invariant(dut):
    """Every landing must align with an even slide count and no RX reset."""
    if ODD_ALIGN_MODE != "BITSLIP":
        return

    tb = await run_landing(dut, LANDING)

    assert tb.aligned(), f"landing {LANDING}: never reached alignment"
    assert not tb.saw_reset, (
        f"landing {LANDING}: asserted rxReset in BITSLIP mode, which is the "
        f"unbounded-relock behavior this mode exists to remove"
    )
    assert tb.slides % 2 == 0, (
        f"landing {LANDING}: settled with an ODD slide count ({tb.slides}). "
        f"An odd count moves the recovered sampling phase off the grid that "
        f"even counts preserve, which is what RESET mode refuses to do."
    )
    assert tb.offset in (0, 1), (
        f"landing {LANDING}: settled at offset {tb.offset}, expected 0 or 1"
    )
    assert tb.offset == LANDING % 2, (
        f"landing {LANDING}: parity is not conserved by sliding "
        f"(settled at {tb.offset})"
    )

    word = tb.data_out()
    assert is_frame(word), (
        f"landing {LANDING}: output 0x{word:05X} is not a comma-aligned frame"
    )

    # Latency in exact frames: the aligned word must trail the GT word the
    # model is presenting by the same amount for every landing, and that amount
    # is EXPECTED_TRAIL's BITSLIP entry, so the mode's absolute cost is pinned
    # here rather than left as a bare offset. One stage is the floor at offset
    # 1, so the contract is exactly one.
    expected_tag = expected_tag_at(tb.cycle)
    assert tag_of(word) == expected_tag, (
        f"landing {LANDING}: presented frame tag {tag_of(word)} at cycle "
        f"{tb.cycle}, expected {expected_tag}. The fabric added a "
        f"landing-dependent delay."
    )

    # Hold it: a single sample could coincide by luck.
    for _ in range(8):
        await tb.step()
        word = tb.data_out()
        assert is_frame(word), f"landing {LANDING}: lost alignment at cycle {tb.cycle}"
        assert tag_of(word) == expected_tag_at(tb.cycle), (
            f"landing {LANDING}: frame tag slipped at cycle {tb.cycle}"
        )


@cocotb.test()
async def reset_mode_rejects_odd_landings(dut):
    """RESET mode's legacy contract, pinned against regression."""
    if ODD_ALIGN_MODE != "RESET":
        return

    tb = await run_landing(dut, LANDING)

    if LANDING % 2 == 1:
        assert tb.saw_reset, (
            f"landing {LANDING} is odd: RESET mode must demand a fresh CDR lock"
        )
    else:
        assert not tb.saw_reset, (
            f"landing {LANDING} is even: RESET mode must not reset"
        )
        assert tb.aligned(), f"landing {LANDING}: never reached alignment"
        assert tb.offset == 0, (
            f"landing {LANDING}: RESET mode must settle at offset 0, "
            f"got {tb.offset}"
        )
        assert tb.slides == LANDING, (
            f"landing {LANDING}: expected {LANDING} slides, got {tb.slides}"
        )
        # RESET mode must keep the fabric path out of the way entirely, so
        # Gtx7Core's RX_DATA_OUT_RESET_GEN branch stays bit-identical.
        assert dut.rxDataAlignedSel.value == 0, (
            "rxDataAlignedSel asserted under RESET mode"
        )
        assert is_frame(int(dut.rxData.value)), (
            f"landing {LANDING}: GT word is not comma-aligned after sliding"
        )
        # The other end of EXPECTED_TRAIL. RESET adds no stage, so the delta
        # against BITSLIP is one rxUsrClk; see EXPECTED_TRAIL for what that
        # costs a caller. Stated as a trail rather than left implicit in
        # offset == 0 so both modes are pinned in the same terms.
        assert tag_of(int(dut.rxData.value)) == expected_tag_at(tb.cycle), (
            f"landing {LANDING}: RESET mode presented frame tag "
            f"{tag_of(int(dut.rxData.value))} at cycle {tb.cycle}, expected "
            f"{expected_tag_at(tb.cycle)}. RESET's fiber-to-rxDataOut latency "
            f"moved, so the BITSLIP delta is no longer one rxUsrClk."
        )


PARAMETER_SWEEP = [
    parameter_case(f"{mode.lower()}_landing{landing:02d}",
                   RX_ODD_ALIGN_MODE_G=mode,
                   LANDING=str(landing))
    for mode in ("BITSLIP", "RESET")
    for landing in range(WORD_SIZE)
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Gtx7RxFixedLatPhaseAligner(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.gtx7rxfixedlatphasealigner",
        parameters={"RX_ODD_ALIGN_MODE_G": parameters["RX_ODD_ALIGN_MODE_G"]},
        extra_env=parameters,
    )
