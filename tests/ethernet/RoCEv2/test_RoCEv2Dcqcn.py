##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

# Test methodology
# ----------------
# DCQCN CNP-driven egress-collapse bench for RoCEv2Dcqcn (via RoCEv2DcqcnWrapper).
# The bench substitutes the RoCEv2Engine.cnp_received source with a TB-driven flat
# `cnp` port and proves the congestion-control collapse with a DUAL PREDICATE:
#   (1) the Rc rate register (AXI-Lite RO @ 0x018), and
#   (2) the observed M_AXIS egress beat-rate at a counting sink.
# Data path: TB pushes 32-byte beats full-rate into S_AXIS -> RoCEv2Dcqcn's
# TokenBucket paces the egress by Rc bytes/clk -> the counting sink tallies
# accepted (valid&ready) beats per fixed clock window. A `cnp` rising edge passes
# through the DUT's internal 3-stage SynchronizerEdge, triggering the DCQCN rate
# state machine (RateDecProc halving, RateIncProc slow recovery, AlphaUpdate),
# which retunes Rc and therefore the egress rate.
#
# Rate math (default LINE_RATE_G=1.25e9 B/s, CLK_FREQ_G=156.25e6 Hz, 32-byte beats):
#   credit = 1.25e9 / 156.25e6 = 8 bytes/clk = 0.25 beats/clk at full line rate.
#   baseline ~0.25 b/clk; after one CNP ~0.125 b/clk (Rc halved); collapse Rc->Rmin
#   (10 MB/s) ~0.002 b/clk. NEVER ~1 beat/clk (token-bucket-paced, not wire-rate).
#
# Sim time is compressed by reprogramming the three DCQCN interval registers at
# setup (the real 1.5ms/4us/55us intervals would need millions of clocks); the
# ~375:1 inc:dec ratio is preserved so the sustained_cnp_collapse ratchet is faithful.
#
# baseline_no_cnp:        GREEN -- Rc pinned at LINE_RATE, egress ~0.25 b/clk.
# single_cnp_halves:      GREEN -- one CNP -> Rc ~ LINE_RATE/2, egress halves.
# sustained_cnp_collapse: RED on the current unmodified RTL -- the deliverable.
#         The sustained-CNP pulse train ratchets Rc toward Rmin with collapsed egress;
#         that collapse assertion is EXPECTED TO FAIL on the current DUT and goes GREEN
#         only in a future phase that adds a runtime dcqcnBypass. Do NOT modify
#         RoCEv2Dcqcn.vhd or weaken the sustained_cnp_collapse assertion to force it green.

from __future__ import annotations

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, with_timeout
from cocotbext.axi import AxiLiteBus, AxiLiteMaster

from tests.axi.utils import axil_read_u32, axil_write_u32
from tests.common.regression_utils import run_surf_vhdl_test
from tests.ethernet.RoCEv2.roce_test_utils import roce_rtl_sources

WRAPPER_PATH = "ethernet/RoCEv2/wrappers/RoCEv2DcqcnWrapper.vhd"
# RoCEv2Dcqcn's full transitive RTL closure. RoCEv2TokenBucket instantiates
# RoCEv2AxisBucket + RoCEv2TokenCalc (NOT in the standard surf build set), so they
# MUST be listed here or GHDL elaboration fails with "unit not found". The two
# Synchronizers (SynchronizerEdge / SynchronizerOneShotCnt) are deliberately NOT
# listed -- they come from build_vhdl_sources(); double-listing -> redefinition error.
RTL_SOURCES = roce_rtl_sources(
    "RoCEv2RateDecProc.vhd",
    "RoCEv2RateIncProc.vhd",
    "RoCEv2AlphaUpdate.vhd",
    "RoCEv2AxisBucket.vhd",
    "RoCEv2TokenCalc.vhd",
    "RoCEv2TokenBucket.vhd",
    "RoCEv2Dcqcn.vhd",
)

# AXI-Lite register map (must match RoCEv2Dcqcn.vhd:290-304)
REG_RAI = 0x004           # RW 32b
REG_RHAI = 0x008          # RW 32b
REG_RMIN = 0x00C          # RW 32b (default 10 MB/s = 0x00989680)
REG_RATE_INC_INT = 0x010  # RW 32b           (time-compress target)
REG_DEC_ALPHA_INT = 0x014  # RW [15:0]=rateDecInterval, [31:16]=alphaUpdInterval
REG_RC = 0x018            # RO 32b  <-- primary predicate (B/s)
REG_RT = 0x01C            # RO 32b  (target rate, B/s)
REG_ALPHA_CNPCNT = 0x020  # RO alpha=r&0x3FF; RW cnpCntRst=bit10; RO cnpCnt=(r>>11)&0xFFFF
REG_DCQCN_BYPASS = 0x024  # RW bit0: 1 = bypass DCQCN (gate CNP + clamp Rc/Rt to LINE_RATE)

BEAT_BYTES = 32
CLK_NS = 6.4
LINE_RATE = 1_250_000_000  # B/s, RoCEv2Dcqcn default LINE_RATE_G
RMIN = 0x00989680          # 10 MB/s, RoCEv2Dcqcn default Rmin

# Compressed DCQCN intervals. Real defaults are 234375 / 625 / 8594 clk.
# Two interval regimes:
#  - "hold" regime: a fast decrease (4 clk) but a deliberately huge
#    rateIncInterval so Rc HOLDS at its post-event value for the whole measurement
#    window -- this isolates the steady-state baseline and the single-CNP 50% cut from
#    the slow rate-increase recovery, giving a clean dual-predicate measurement.
#  - "ratchet" regime: the realistic ~375:1 rateInc:rateDec ratio so each CNP
#    decrease lands before one increase tick, ratcheting Rc monotonically toward Rmin.
RATE_DEC_INTERVAL = 4       # 0x014[15:0]
ALPHA_UPD_INTERVAL = 8      # 0x014[31:16]
RATE_INC_INTERVAL_HOLD = 1_000_000  # 0x010: effectively no recovery within a test window
RATE_INC_INTERVAL_RATCHET = 1500    # 0x010: 1500/4 = ~375:1 (faithful down-fast/up-slow)

COUNT_WINDOW = 4000        # beat-count window (>= 2000 clk so burst-avg is stable)

# --- Drain-variant constants --------------------------
# MTU-sized multi-beat framing: a ~4 KB frame is 4096/32 = 128 beats. The
# RoCEv2AxisBucket releases one WHOLE frame per `count >= packet_size`, where
# packet_size = AxiStreamMon-measured frameSize. So this tLast cadence sets MTU.
MTU_BYTES = 4096
BEATS_PER_FRAME = MTU_BYTES // BEAT_BYTES   # = 128
#
# Drain-window derivation (derived from RTL constants, NOT guessed):
#   byte_per_clk = (Rc * K_C) >> N_C  (RoCEv2TokenCalc.vhd:64-65; N_C=48-16=32,
#   K_C=round(2^48/156.25e6)). At Rc=Rmin=10 MB/s -> byte_per_clk(Rmin) ~ 0.064 B/clk.
#   BUCKET_SIZE_G = x"00100000" = 1 MB = 1_048_576 B (RoCEv2TokenBucket.vhd:147),
#   hardcoded on the RoCEv2AxisBucket instance -- NOT shrunk.
#
#   While the bucket count >= packet_size it releases frames back-to-back, so the
#   reservoir empties at ~(egress - fill). With fill ~0.064 B/clk negligible vs the
#   back-to-back frame egress, draining 1 MB ~ 1_048_576/MTU_BYTES = 256 frames, each
#   spanning BEATS_PER_FRAME=128 clk in READ_S -> ~256*128 = 32_768 clk of active drain.
#   After the reservoir is empty, releases are REFILL-GATED: one MTU frame accumulates
#   credit at byte_per_clk(Rmin), so a frame releases every MTU_BYTES/0.064 ~ 64_000 clk.
#   The refill-gated egress floor is therefore:
#     beats/clk = byte_per_clk(Rmin) / MTU_BYTES * BEATS_PER_FRAME
#              = byte_per_clk(Rmin) / BEAT_BYTES ~ 0.064/32 ~ 0.002 b/clk
#   (orders of magnitude below the ~0.25 b/clk baseline -> egress tracks Rc).
BYTE_PER_CLK_RMIN = (RMIN * round(2**48 / 156_250_000)) / 2**32 / 2**16  # ~0.064 B/clk
EGRESS_FLOOR_BPC = BYTE_PER_CLK_RMIN / BEAT_BYTES                        # ~0.002 b/clk
#
# Settle window must outlast the active drain (~33k clk) with margin so the measurement
# window observes the refill-gated steady state. Measurement window must span several
# refill-gated frame periods (~64k clk each) so a non-zero, stable beat-rate is seen.
DRAIN_SETTLE_CLK = 40_000   # > ~33k active-drain clk: empties the 1 MB reservoir
DRAIN_WINDOW = 200_000      # ~3 refill-gated frame periods: stable post-drain rate


def beat_data(counter: int) -> int:
    """32-byte beat payload as an int: low 4 bytes = little-endian counter."""
    b = bytearray(BEAT_BYTES)
    b[0:4] = (counter & 0xFFFFFFFF).to_bytes(4, "little")
    return int.from_bytes(b, "little")


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.axil = None
        cocotb.start_soon(Clock(dut.clk, CLK_NS, unit="ns").start())
        dut.rst.value = 1
        # TB-driven inputs to a known idle state
        dut.cnp.value = 0
        dut.S_AXIS_TVALID.value = 0
        dut.S_AXIS_TDATA.value = 0
        dut.S_AXIS_TKEEP.value = 0
        dut.S_AXIS_TLAST.value = 0
        # Counting sink: default always-ready so the TokenBucket Rc is the sole throttle.
        dut.M_AXIS_TREADY.value = 1

    async def _edge(self):
        await RisingEdge(self.dut.clk)
        await Timer(1, unit="ns")

    async def reset(self):
        self.dut.rst.value = 1
        for _ in range(8):
            await RisingEdge(self.dut.clk)
        self.dut.rst.value = 0
        for _ in range(4):
            await RisingEdge(self.dut.clk)
        self.axil = AxiLiteMaster(AxiLiteBus.from_prefix(self.dut, "S_AXIL"), self.dut.clk, self.dut.rst)

    async def configure_intervals(self, rate_inc_interval):
        # Reprogram the three DCQCN intervals to compressed values. The packed
        # 0x014 word carries rateDecInterval[15:0] and alphaUpdInterval[31:16].
        await axil_write_u32(self.axil, REG_RATE_INC_INT, rate_inc_interval)
        await axil_write_u32(self.axil, REG_DEC_ALPHA_INT,
                             (ALPHA_UPD_INTERVAL << 16) | (RATE_DEC_INTERVAL & 0xFFFF))

    # --- ingress source: 32-byte beats full-rate, honoring S_AXIS_TREADY -----
    async def drive_beats(self):
        dut = self.dut
        ctr = 0
        while True:
            dut.S_AXIS_TDATA.value = beat_data(ctr)
            dut.S_AXIS_TKEEP.value = (1 << BEAT_BYTES) - 1
            dut.S_AXIS_TLAST.value = 1   # 1-beat frames so the FIFO never stalls on framing
            dut.S_AXIS_TVALID.value = 1
            await self._edge()
            while int(dut.S_AXIS_TREADY.value) == 0:
                await self._edge()
            ctr += 1

    # --- counting sink: tally M_AXIS accepted beats over a fixed clock window
    async def count_beats(self, window_clk):
        dut = self.dut
        n = 0
        for _ in range(window_clk):
            await RisingEdge(dut.clk)
            await Timer(1, unit="ns")
            if int(dut.M_AXIS_TVALID.value) and int(dut.M_AXIS_TREADY.value):
                n += 1
        return n

    # --- CNP injection: 1-clk pulse through the 3-stage SynchronizerEdge ------
    async def cnp_pulse(self):
        self.dut.cnp.value = 1
        await RisingEdge(self.dut.clk)
        self.dut.cnp.value = 0
        await RisingEdge(self.dut.clk)

    async def read_rc(self):
        return int(await axil_read_u32(self.axil, REG_RC))

    async def read_cnp_cnt(self):
        return (int(await axil_read_u32(self.axil, REG_ALPHA_CNPCNT)) >> 11) & 0xFFFF


@cocotb.test()
async def baseline_no_cnp(dut):
    # baseline_no_cnp: with NO cnp, Rc stays pinned at LINE_RATE (REG_INIT_C) and the TokenBucket
    # paces egress at the line-rate-permitted token rate: 8 bytes/clk = 0.25 beats/clk
    # (NOT ~1 beat/clk -- the wire is 32 bytes wide but the credit is 8 bytes/clk). The
    # rate is burst-averaged over a >=2000-clk window.
    tb = TB(dut)
    await tb.reset()
    await tb.configure_intervals(RATE_INC_INTERVAL_HOLD)

    cocotb.start_soon(tb.drive_beats())

    async def body():
        # Let the FIFO prime and the TokenBucket reach steady state.
        for _ in range(500):
            await RisingEdge(dut.clk)
        rc = await tb.read_rc()
        beats = await tb.count_beats(COUNT_WINDOW)
        rate = beats / COUNT_WINDOW

        assert rc == LINE_RATE, f"baseline Rc {rc} != LINE_RATE {LINE_RATE}"
        # Token-bucket baseline band ~0.25 b/clk (burst-averaged). Never ~1 b/clk.
        assert 0.20 <= rate <= 0.30, \
            f"baseline egress {rate:.4f} b/clk outside the ~0.25 token-bucket band ({beats}/{COUNT_WINDOW})"

    await with_timeout(body(), 200_000, "ns")


@cocotb.test()
async def single_cnp_halves(dut):
    # single_cnp_halves: one 1-clk cnp pulse (a single rising edge through the 3-stage
    # SynchronizerEdge) forces the firstCnp path -> alpha all-1s -> RateDecProc
    # cuts Rc by ~50% (newRc = curRc - (curRc*alpha >> (dec_gain+10)); alpha=0x3FF,
    # dec_gain=1 -> shift 11 -> delta ~= 0.4995*curRc -> newRc ~= LINE_RATE/2).
    # Dual predicate: Rc ~ LINE_RATE/2 AND egress beat-rate halves vs the
    # baseline_no_cnp baseline window; cnpCnt cross-checks the edge registered exactly once.
    tb = TB(dut)
    await tb.reset()
    # "hold" regime: huge rateIncInterval so Rc stays at the post-cut value across the
    # measurement window, isolating the single 50% cut from the slow recovery.
    await tb.configure_intervals(RATE_INC_INTERVAL_HOLD)

    cocotb.start_soon(tb.drive_beats())

    async def body():
        # Establish the LINE_RATE baseline.
        for _ in range(500):
            await RisingEdge(dut.clk)
        rc0 = await tb.read_rc()
        assert rc0 == LINE_RATE, f"pre-CNP Rc {rc0} != LINE_RATE {LINE_RATE}"
        base = await tb.count_beats(COUNT_WINDOW)

        # Fire exactly one CNP and let the 3-stage synchronizer + RateDecProc settle.
        await tb.cnp_pulse()
        for _ in range(200):
            await RisingEdge(dut.clk)

        rc1 = await tb.read_rc()
        cnp_cnt = await tb.read_cnp_cnt()
        # Measure egress immediately after the cut, before the slow (1500-clk) increase
        # recovers Rc.
        after = await tb.count_beats(COUNT_WINDOW)

        half = LINE_RATE // 2
        # +-3% band absorbs the alpha>>(dec_gain+10) rounding (~0.50049*LINE_RATE).
        assert abs(rc1 - half) <= half * 0.03, \
            f"post-CNP Rc {rc1} not ~ LINE_RATE/2 ({half}) -- single 50% cut failed"
        assert cnp_cnt == 1, f"cnpCnt {cnp_cnt} != 1 (CNP edge did not register exactly once)"
        # Egress beat-rate must roughly halve vs the baseline window.
        assert after <= base * 0.65, \
            f"post-CNP egress {after} not ~half of baseline {base} (token-bucket did not throttle)"
        assert after >= base * 0.35, \
            f"post-CNP egress {after} collapsed below the expected half-rate {base} (over-throttled)"

    await with_timeout(body(), 300_000, "ns")


@cocotb.test()
async def sustained_cnp_collapse(dut):
    # sustained_cnp_collapse (HEADLINE DELIVERABLE -- EXPECTED RED ON CURRENT, UNMODIFIED RTL).
    #
    # A periodic 1-clk cnp pulse train at period N (rateDecInterval < N < rateIncInterval,
    # >=4 clk spacing so each is a distinct rising edge through the 3-stage synchronizer)
    # drives the DCQCN ratchet: every CNP resets the slow rate-increase timer
    # and fires another decrease before Rc can recover, so Rc monotonically ratchets toward
    # Rmin (10 MB/s) and the TokenBucket collapses the egress far below baseline.
    #
    # The cnpCnt>1 sub-check below PASSES (it proves the pulse train registered). The
    # COLLAPSE dual predicate (Rc -> Rmin AND egress collapsed) is asserted and is
    # EXPECTED TO FAIL (RED) on the current RTL -- that RED is the deliverable: it proves
    # the DCQCN egress throttle is the real, deterministic collapse mechanism. sustained_cnp_collapse goes
    # GREEN only in a future phase that adds a runtime dcqcnBypass. DO NOT modify
    # RoCEv2Dcqcn.vhd and DO NOT weaken this collapse assertion to force it green.
    tb = TB(dut)
    await tb.reset()
    # "ratchet" regime: realistic ~375:1 inc:dec so each CNP lands before recovery.
    await tb.configure_intervals(RATE_INC_INTERVAL_RATCHET)

    cocotb.start_soon(tb.drive_beats())

    # period N: rateDecInterval(4) < N(8) < rateIncInterval(1500); spacing >= 4 clk.
    N = 8
    PULSES = 600  # enough decreases to drive a full ratchet to Rmin in compressed time

    async def cnp_train():
        for _ in range(PULSES):
            tb.dut.cnp.value = 1
            await RisingEdge(tb.dut.clk)
            tb.dut.cnp.value = 0
            for _ in range(N - 1):
                await RisingEdge(tb.dut.clk)

    async def body():
        # Baseline before the train.
        for _ in range(500):
            await RisingEdge(dut.clk)
        base = await tb.count_beats(COUNT_WINDOW)

        # Run the sustained CNP train to completion.
        await cnp_train()
        for _ in range(500):
            await RisingEdge(dut.clk)

        rc = await tb.read_rc()
        cnp_cnt = await tb.read_cnp_cnt()
        collapsed = await tb.count_beats(COUNT_WINDOW)

        dut._log.info(
            f"sustained_cnp_collapse evidence: cnpCnt={cnp_cnt} Rc={rc} (Rmin={RMIN}, LINE_RATE={LINE_RATE}) "
            f"baseline_beats={base} collapsed_beats={collapsed} "
            f"(Rc->Rmin predicate: {rc} <= {RMIN * 4}; egress-collapse predicate: {collapsed} <= {int(base * 0.10)})"
        )

        # Sub-check (PASSES): the pulse train registered as many distinct rising edges.
        assert cnp_cnt > 1, \
            f"cnpCnt {cnp_cnt} <= 1 -- the pulse train did not register (spacing/synchronizer issue)"

        # COLLAPSE dual predicate -- the bench REQUIRES BOTH halves to agree:
        #   (1) the DCQCN rate register Rc has ratcheted toward Rmin, AND
        #   (2) the OBSERVED egress beat-rate has collapsed to match (the TokenBucket
        #       actually throttles the wire to the collapsed Rc).
        # On the current, unmodified RTL these DIVERGE: Rc reaches Rmin but the egress
        # does NOT collapse (the egress throttle does not honor the collapsed Rc), so the
        # combined predicate is RED. That divergence IS the deliverable -- it pinpoints
        # the DCQCN egress-throttle disconnect as the deterministic collapse mechanism.
        # sustained_cnp_collapse goes GREEN only in a future phase that adds a runtime dcqcnBypass.
        # DO NOT modify RoCEv2Dcqcn.vhd and DO NOT weaken this assertion to force green.
        rc_at_floor = rc <= RMIN * 4
        egress_collapsed = collapsed <= base * 0.10
        assert rc_at_floor and egress_collapsed, (
            "sustained_cnp_collapse dual-predicate RED (EXPECTED on current RTL): "
            f"Rc->Rmin={rc_at_floor} (Rc={rc}, Rmin={RMIN}), "
            f"egress-collapsed={egress_collapsed} (collapsed={collapsed} beats vs baseline={base}). "
            "The current RTL ratchets Rc to Rmin but the egress beat-rate does NOT collapse to "
            "match -- the egress throttle does not honor the collapsed Rc. This RED is the "
            "headline deliverable; it goes GREEN only with a future dcqcnBypass. Do NOT 'fix' it here."
        )

    await with_timeout(body(), 600_000, "ns")


@cocotb.test()
async def sustained_cnp_egress_drains(dut):
    # sustained_cnp_egress_drains (GREEN) -- the egress half of the sustained_cnp_collapse dual predicate,
    # turned GREEN by DRAINING the 1 MB reservoir. This is ADDITIVE: the original
    # sustained_cnp_collapse coroutine above is UNCHANGED and still RED (it documents the
    # reservoir-masking artifact). This variant proves the cause->effect link entirely in
    # sim: once the 1 MB RoCEv2AxisBucket reservoir drains, the observed egress beat-rate
    # converges to byte_per_clk(Rmin) -- egress DOES track the collapsed Rc.
    #
    # Two TEST-SIDE deltas vs sustained_cnp_collapse (zero RTL/wrapper edits):
    #   (a) MTU-sized multi-beat ingress framing (BEATS_PER_FRAME=128 -> AxiStreamMon
    #       packet_size = 4 KB), so the bucket releases one whole MTU frame per
    #       count >= packet_size.
    #   (b) a drain window sized from the RTL rate-math (DRAIN_SETTLE_CLK + DRAIN_WINDOW;
    #       see derivation at the module constants) -- long enough to exhaust the reservoir
    #       at the collapsed Rc, then measure the refill-gated egress floor.
    tb = TB(dut)
    await tb.reset()
    # "ratchet" regime: realistic ~375:1 inc:dec so each CNP lands before recovery.
    await tb.configure_intervals(RATE_INC_INTERVAL_RATCHET)

    # --- MTU-sized ingress source: a localized drive_beats variant that asserts
    # S_AXIS_TLAST only on the final beat of each BEATS_PER_FRAME-beat frame. TKEEP full
    # and the TREADY backpressure handling are EXACTLY as in TB.drive_beats.
    async def drive_mtu_frames():
        ctr = 0
        beat_in_frame = 0
        while True:
            dut.S_AXIS_TDATA.value = beat_data(ctr)
            dut.S_AXIS_TKEEP.value = (1 << BEAT_BYTES) - 1
            dut.S_AXIS_TLAST.value = 1 if (beat_in_frame == BEATS_PER_FRAME - 1) else 0
            dut.S_AXIS_TVALID.value = 1
            await tb._edge()
            while int(dut.S_AXIS_TREADY.value) == 0:
                await tb._edge()
            ctr += 1
            beat_in_frame = 0 if (beat_in_frame == BEATS_PER_FRAME - 1) else beat_in_frame + 1

    cocotb.start_soon(drive_mtu_frames())

    # period N: rateDecInterval(4) < N(8) < rateIncInterval(1500); spacing >= 4 clk
    # (identical cadence to sustained_cnp_collapse -- ratchets Rc to Rmin). The train
    # runs CONTINUOUSLY as a background coroutine: it must HOLD the CNP floor through the
    # entire reservoir-drain + measurement window, otherwise the slow rate-increase
    # recovery (rateIncInterval=1500) would ratchet Rc back up to LINE_RATE during the
    # long drain settle. Each CNP resets that increase timer, pinning Rc at Rmin.
    N = 8

    async def cnp_train_forever():
        while True:
            tb.dut.cnp.value = 1
            await RisingEdge(tb.dut.clk)
            tb.dut.cnp.value = 0
            for _ in range(N - 1):
                await RisingEdge(tb.dut.clk)

    async def body():
        # Baseline before the train (MTU framing).
        for _ in range(500):
            await RisingEdge(dut.clk)
        base = await tb.count_beats(COUNT_WINDOW)

        # Start the sustained CNP train and KEEP it running for the whole drain so Rc
        # ratchets to Rmin and STAYS there while the 1 MB reservoir drains.
        cocotb.start_soon(cnp_train_forever())

        # Let the train ratchet Rc to Rmin, then hold the CNP floor and let the 1 MB
        # reservoir DRAIN at the collapsed Rc. DRAIN_SETTLE_CLK > ~33k active-drain clk
        # (see derivation) so the reservoir is empty before the measurement window opens.
        for _ in range(DRAIN_SETTLE_CLK):
            await RisingEdge(dut.clk)

        rc = await tb.read_rc()
        cnp_cnt = await tb.read_cnp_cnt()

        # Measure the post-drain (refill-gated) egress beat-rate over a long window.
        drained = await tb.count_beats(DRAIN_WINDOW)
        drained_bpc = drained / DRAIN_WINDOW
        base_bpc = base / COUNT_WINDOW

        # Convergence band around the analytic refill-gated floor EGRESS_FLOOR_BPC.
        # Tolerance absorbs boundary effects (partial frame straddling the window edge).
        band_lo = EGRESS_FLOOR_BPC * 0.40
        band_hi = EGRESS_FLOOR_BPC * 2.50

        dut._log.info(
            f"sustained_cnp_egress_drains drain evidence: cnpCnt={cnp_cnt} Rc={rc} (Rmin={RMIN}, "
            f"LINE_RATE={LINE_RATE}) baseline_beats={base} ({base_bpc:.4f} b/clk) "
            f"drained_beats={drained} over {DRAIN_WINDOW} clk ({drained_bpc:.6f} b/clk) "
            f"byte_per_clk(Rmin)={BYTE_PER_CLK_RMIN:.4f} B/clk -> "
            f"egress floor={EGRESS_FLOOR_BPC:.6f} b/clk "
            f"band=[{band_lo:.6f},{band_hi:.6f}] b/clk"
        )

        # Dual predicate, egress half now GREEN:
        #   (1) Rc has ratcheted to Rmin (reuse the tolerance idiom).
        assert rc <= RMIN * 4, \
            f"Rc {rc} did not ratchet toward Rmin {RMIN} (train failed)"
        #   (1b) the pulse train registered (sanity, mirrors sub-check).
        assert cnp_cnt > 1, \
            f"cnpCnt {cnp_cnt} <= 1 -- the pulse train did not register"
        #   (2) the OBSERVED post-drain egress converges to the byte_per_clk(Rmin) floor,
        #       well below the ~0.25 b/clk baseline -> egress tracks Rc.
        assert drained_bpc <= base_bpc * 0.10, (
            f"post-drain egress {drained_bpc:.6f} b/clk not collapsed vs baseline "
            f"{base_bpc:.4f} b/clk -- egress did not track the collapsed Rc"
        )
        assert band_lo <= drained_bpc <= band_hi, (
            f"post-drain egress {drained_bpc:.6f} b/clk outside the byte_per_clk(Rmin) "
            f"convergence band [{band_lo:.6f},{band_hi:.6f}] -- egress did NOT converge to "
            f"the refill-gated floor {EGRESS_FLOOR_BPC:.6f} b/clk"
        )

    await with_timeout(body(), 2_500_000, "ns")


@cocotb.test()
async def bypass_holds_line_rate_under_drain(dut):
    # Bypass-GREEN drain proof -- the INVERSE of the sustained_cnp_egress_drains
    # sustained_cnp_egress_drains coroutine above. Writing dcqcnBypass=1 @0x024
    # gates the CNP-effect FSM and clamps Rc/Rt to LINE_RATE every
    # cycle, so the SAME sustained-CNP + reservoir-drain scenario that collapses
    # without bypass instead HOLDS the line-rate band: Rc stays pinned at LINE_RATE
    # and the 1 MB RoCEv2AxisBucket reservoir never net-drains, so the observed
    # egress holds the baseline_no_cnp baseline band (~0.25 b/clk) rather than converging to
    # the byte_per_clk(Rmin) floor. This closes the cause->fix loop in sim: the
    # bypass neutralizes the proven CNP-driven collapse.
    #
    # Scenario is IDENTICAL to sustained_cnp_egress_drains (MTU-framed ingress,
    # continuous CNP train, the same DRAIN_SETTLE_CLK + DRAIN_WINDOW timing); the
    # only deltas are the 0x024 bypass write at setup and the inverted assertions.
    tb = TB(dut)
    await tb.reset()
    # Enable the DCQCN bypass BEFORE any traffic: gate CNP + clamp Rc/Rt to LINE_RATE.
    await axil_write_u32(tb.axil, REG_DCQCN_BYPASS, 1)
    # Same "ratchet" regime as the RED drain test -- under bypass the CNP train has
    # no rate-control effect, so the regime choice is immaterial but kept identical.
    await tb.configure_intervals(RATE_INC_INTERVAL_RATCHET)

    # MTU-sized ingress framing, identical to sustained_cnp_egress_drains.
    async def drive_mtu_frames():
        ctr = 0
        beat_in_frame = 0
        while True:
            dut.S_AXIS_TDATA.value = beat_data(ctr)
            dut.S_AXIS_TKEEP.value = (1 << BEAT_BYTES) - 1
            dut.S_AXIS_TLAST.value = 1 if (beat_in_frame == BEATS_PER_FRAME - 1) else 0
            dut.S_AXIS_TVALID.value = 1
            await tb._edge()
            while int(dut.S_AXIS_TREADY.value) == 0:
                await tb._edge()
            ctr += 1
            beat_in_frame = 0 if (beat_in_frame == BEATS_PER_FRAME - 1) else beat_in_frame + 1

    cocotb.start_soon(drive_mtu_frames())

    N = 8

    async def cnp_train_forever():
        while True:
            tb.dut.cnp.value = 1
            await RisingEdge(tb.dut.clk)
            tb.dut.cnp.value = 0
            for _ in range(N - 1):
                await RisingEdge(tb.dut.clk)

    async def body():
        # Baseline before the train (MTU framing).
        for _ in range(500):
            await RisingEdge(dut.clk)
        base = await tb.count_beats(COUNT_WINDOW)

        # Run the SAME sustained CNP train that collapses egress without bypass.
        # Under bypass the train has no rate effect (IDLE_S branch gated off).
        cocotb.start_soon(cnp_train_forever())

        # Hold through the full drain-settle window. Without bypass the reservoir
        # would drain and egress would collapse here; with bypass Rc stays at
        # LINE_RATE so the reservoir never net-drains.
        for _ in range(DRAIN_SETTLE_CLK):
            await RisingEdge(dut.clk)

        rc = await tb.read_rc()
        cnp_cnt = await tb.read_cnp_cnt()

        # Measure the post-"drain" egress over the same long window as the RED test.
        drained = await tb.count_beats(DRAIN_WINDOW)
        drained_bpc = drained / DRAIN_WINDOW
        base_bpc = base / COUNT_WINDOW

        dut._log.info(
            f"Bypass-GREEN evidence: cnpCnt={cnp_cnt} Rc={rc} (Rmin={RMIN}, "
            f"LINE_RATE={LINE_RATE}) baseline_beats={base} ({base_bpc:.4f} b/clk) "
            f"held_beats={drained} over {DRAIN_WINDOW} clk ({drained_bpc:.6f} b/clk) "
            f"-> Rc-pinned predicate: {rc} == {LINE_RATE}; "
            f"egress-holds-baseline-band predicate: 0.20 <= {drained_bpc:.4f} <= 0.30"
        )

        # Dual predicate, INVERSE of sustained_cnp_egress_drains:
        #   (1) Rc is PINNED at LINE_RATE (clamp wins; NOT ratcheted toward Rmin).
        assert rc == LINE_RATE, \
            f"Rc {rc} != LINE_RATE {LINE_RATE} -- bypass clamp did not hold Rc at line rate"
        #   (1b) the pulse train DID register edges (cnpCnt counts independent of bypass),
        #        proving CNPs arrived yet produced no rate effect under bypass.
        assert cnp_cnt > 1, \
            f"cnpCnt {cnp_cnt} <= 1 -- the pulse train did not register (scenario invalid)"
        #   (2) the OBSERVED egress HOLDS the baseline_no_cnp baseline band (~0.25 b/clk),
        #       NOT collapsed to the byte_per_clk(Rmin) floor -- the reservoir never
        #       net-drains because Rc stays at LINE_RATE.
        assert 0.20 <= drained_bpc <= 0.30, (
            f"egress {drained_bpc:.6f} b/clk outside the ~0.25 line-rate baseline band "
            f"[0.20,0.30] under bypass -- the bypass did not hold the line-rate egress "
            f"(EGRESS_FLOOR_BPC={EGRESS_FLOOR_BPC:.6f} b/clk would indicate a collapse)"
        )

    await with_timeout(body(), 2_500_000, "ns")


@pytest.mark.parametrize("parameters", [pytest.param({}, id="rocev2_dcqcn")])
def test_RoCEv2Dcqcn(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.rocev2dcqcnwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": RTL_SOURCES + [WRAPPER_PATH]},
    )
