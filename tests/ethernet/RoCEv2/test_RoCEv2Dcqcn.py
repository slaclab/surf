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
# - Sweep: Compare the no-congestion baseline with one CNP event while holding
#   rate recovery outside the observation window.
# - Stimulus: Drive full-rate one-beat frames, compress the DCQCN update
#   intervals through AXI-Lite, and inject one synchronized CNP pulse.
# - Checks: Use both the AXI-Lite Rc/cnpCnt state and accepted M_AXIS beat rate;
#   require the baseline token rate and the expected approximately 50-percent
#   reduction after one CNP.
# - Timing: Count accepted beats over fixed 4000-clock windows. Each scenario is
#   enclosed by a simulated-time watchdog and cancels its lifetime source on
#   both success and failure.
#
# DCQCN CNP rate-control bench for RoCEv2Dcqcn (via RoCEv2DcqcnWrapper). The bench
# substitutes the RoCEv2Engine.cnp_received source with a TB-driven flat `cnp` port
# and proves the congestion-control behavior with a DUAL PREDICATE:
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
#   baseline ~0.25 b/clk; after one CNP ~0.125 b/clk (Rc halved). NEVER ~1 beat/clk
#   (token-bucket-paced, not wire-rate).
#
# Sim time is compressed by reprogramming the DCQCN interval registers at setup
# (the real 1.5ms/4us/55us intervals would need millions of clocks).
#
# baseline_no_cnp:   GREEN -- Rc pinned at LINE_RATE, egress ~0.25 b/clk.
# single_cnp_halves: GREEN -- one CNP -> Rc ~ LINE_RATE/2, egress halves.

from __future__ import annotations

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, with_timeout

from tests.common.regression_utils import sample_after_tpd
from cocotbext.axi import AxiLiteBus, AxiLiteMaster

from tests.axi.utils import axil_read_u32, axil_write_u32
from tests.common.regression_utils import run_surf_vhdl_test

# The cocotb wrapper is the only source this bench has to name. RoCEv2Dcqcn's
# whole transitive closure -- the rate/alpha/bucket helpers under
# ethernet/RoCEv2/rtl as well as the SynchronizerEdge and SynchronizerOneShotCnt
# it pulls from base/ -- already reaches GHDL through build_vhdl_sources(),
# because ethernet/ruckus.tcl loads ethernet/RoCEv2 in the non-Vivado branch.
# Listing any of those files again here would hand GHDL a second design file for
# an entity the imported farm already provides.
WRAPPER_PATH = "ethernet/RoCEv2/wrappers/RoCEv2DcqcnWrapper.vhd"

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

# Compressed DCQCN intervals. Real defaults are 234375 / 625 / 8594 clk.
# "hold" regime: a fast decrease (4 clk) but a deliberately huge rateIncInterval so
# Rc HOLDS at its post-event value for the whole measurement window -- this isolates
# the steady-state baseline and the single-CNP 50% cut from the slow rate-increase
# recovery, giving a clean dual-predicate measurement.
RATE_DEC_INTERVAL = 4       # 0x014[15:0]
ALPHA_UPD_INTERVAL = 8      # 0x014[31:16]
RATE_INC_INTERVAL_HOLD = 1_000_000  # 0x010: effectively no recovery within a test window

COUNT_WINDOW = 4000        # beat-count window (>= 2000 clk so burst-avg is stable)


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
        await sample_after_tpd(self.dut.clk)

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
        """Lifetime agent: drive full-rate ingress until its test cancels it."""
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
            await sample_after_tpd(dut.clk)
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

    # The full-rate source is a lifetime agent for this measurement window.
    source_task = cocotb.start_soon(tb.drive_beats())

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

    try:
        await with_timeout(body(), 200_000, "ns")
    finally:
        source_task.cancel()


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

    # The full-rate source is a lifetime agent for this measurement window.
    source_task = cocotb.start_soon(tb.drive_beats())

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

    try:
        await with_timeout(body(), 300_000, "ns")
    finally:
        source_task.cancel()


@pytest.mark.parametrize("parameters", [pytest.param({}, id="rocev2_dcqcn")])
def test_RoCEv2Dcqcn(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.rocev2dcqcnwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={"surf": [WRAPPER_PATH]},
    )
