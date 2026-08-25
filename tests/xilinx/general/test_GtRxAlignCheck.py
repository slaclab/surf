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
# - Sweep: Three elaborations. A GTHE3 case with a zero DRP base proves the
#   0x540 COMMA_ALIGN_LATENCY offset, a GTHE4 case with a non-zero base proves
#   the 0x940 offset and the base-address addition, and a SIMULATION_G case
#   proves the override generic defaults set so the checker locks on its first
#   read. GT_TYPE_G and SIMULATION_G change elaboration, so they cannot be
#   varied inside one build.
# - Stimulus: A scripted AXI-Lite slave answers the master-side DRP read with
#   chosen COMMA_ALIGN_LATENCY phase values, and an RX-clock-domain model
#   reproduces gtwiz_buffbypass_rx_done_out and gtwiz_buffbypass_rx_error_out
#   reacting to resetOut, the way TimingGtCoreWrapper wires a GTHE3 core. The
#   register map is driven over the flattened slave port with cocotbext.axi.
# - Checks: Lock on a masked phase match, retry-and-count on mismatch, phase
#   histogram accumulation and its clear-on-config-write side effect, target
#   and mask reprogramming, the override register and generic, retry counter
#   clearing, programmable reset length, asynchronous resetIn restart, and
#   axilRst returning the map to its reset values. Two checks are explicit
#   regression tests: an out-of-range 7-bit phase must not disturb the 40-bin
#   histogram, and an error asserted well before resetDone must still produce
#   exactly one reset.
# - Timing: axilClk, rxClk, txClk and refClk all run at distinct periods so the
#   GT status crossings are genuinely asynchronous, and resetIn is driven off
#   the clock edge to exercise its synchronizer. resetOut assertions are counted
#   and width-measured by a sampling monitor rather than inferred from register
#   state, because the pulse count is the contract for the error path.
# - Does not prove: The TxClkFreq, RxClkFreq and RefClkFreq registers read zero
#   throughout. The RTL fixes SyncClockFreq at REFRESH_RATE_G => 1.0, so a
#   measurement window is AXI_CLK_FREQ_G axilClk cycles, one second of sim time
#   at the real 156.25 MHz. That measurement is covered by
#   tests/base/sync/test_SyncClockFreq.py. The retryCnt saturation at 0xFFFF is
#   also out of reach, since it needs 65535 reset-and-reread cycles.

import os

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotbext.axi import AxiLiteBus, AxiLiteMaster, AxiResp

from tests.axi.utils import axil_read_u32, axil_write_u32
from tests.common.regression_utils import (
    env_flag,
    env_int,
    parameter_case,
    run_surf_vhdl_test,
)
from tests.xilinx.general.gt_rx_align_check_test_utils import (
    CONFIG_ADDR,
    LAST_PHASE_ADDR,
    LOCKED_ADDR,
    OVERRIDE_ADDR,
    PHASE_HIST_BINS,
    REF_CLK_FREQ_ADDR,
    RETRY_CNT_ADDR,
    RST_RETRY_CNT_ADDR,
    RX_CLK_FREQ_ADDR,
    TX_CLK_FREQ_ADDR,
    DrpAxiLiteSlave,
    GtBuffBypassModel,
    ResetOutMonitor,
    comma_align_latency_addr,
    config_word,
    phase_hist_bin,
)


# SIMULATION_G forces the override flag set at reset, which defeats every
# retry-based check, so those tests are skipped in that elaboration.
SIM_OVERRIDE = env_flag("SIMULATION_G", default=False)

AXIL_PERIOD_NS = 6.4
RX_PERIOD_NS = 8.4
TX_PERIOD_NS = 7.1
REF_PERIOD_NS = 5.3

# Mid-period offset used to move resetIn away from an axilClk edge. Keep this a
# value the simulator can represent exactly; a computed fraction of the period
# such as AXIL_PERIOD_NS/3 is not representable at 1 fs precision.
RESET_IN_SKEW_NS = 2.1

# Matches the entity defaults that the wrapper leaves alone.
DEFAULT_TARGET = 16
DEFAULT_MASK = 126
DEFAULT_RST_LEN = 3

# 126 masks off bit 0, so 16 and 17 both satisfy the lock comparison.
MATCHING_PHASE = DEFAULT_TARGET
MISMATCH_PHASES = (20, 21)


class TB:
    def __init__(self, dut, *, phases=(MATCHING_PHASE,)):
        self.dut = dut
        self.gt_type = os.environ.get("GT_TYPE_G", "GTHE3")
        self.drp_base = env_int("DRP_ADDR_INT_G", default=0)
        self.expected_drp_addr = comma_align_latency_addr(self.gt_type, self.drp_base)

        # Distinct periods on every clock so the GT status crossings and the
        # frequency monitors all see truly asynchronous relationships.
        cocotb.start_soon(Clock(dut.axilClk, AXIL_PERIOD_NS, unit="ns").start())
        cocotb.start_soon(Clock(dut.rxClk, RX_PERIOD_NS, unit="ns").start())
        cocotb.start_soon(Clock(dut.txClk, TX_PERIOD_NS, unit="ns").start())
        cocotb.start_soon(Clock(dut.refClk, REF_PERIOD_NS, unit="ns").start())

        dut.axilRst.setimmediatevalue(1)
        dut.resetIn.setimmediatevalue(0)

        self.axil = AxiLiteMaster(
            bus=AxiLiteBus.from_prefix(dut, "S_AXI"),
            clock=dut.axilClk,
            reset=dut.axilRst,
            reset_active_level=True,
        )
        self.drp = DrpAxiLiteSlave(dut, phases=phases)
        self.gt = GtBuffBypassModel(dut, rx_clk=dut.rxClk)
        self.monitor = ResetOutMonitor(dut)

    async def cycle(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.axilClk)
            await Timer(1, unit="ns")

    async def reset(self) -> None:
        # Hold axilRst so the checker restarts from REG_INIT_C, then let the GT
        # model run its first alignment pass before any register access.
        self.dut.axilRst.setimmediatevalue(1)
        self.dut.resetIn.value = 0
        await self.cycle(5)
        self.dut.axilRst.value = 0
        await self.cycle(5)
        self.monitor.reset_counts()

    async def wait_for_lock(self, *, timeout_cycles: int = 4000) -> None:
        for _ in range(timeout_cycles):
            await self.cycle(1)
            if int(self.dut.locked.value) == 1:
                return
        raise AssertionError("Timed out waiting for GtRxAlignCheck to lock")

    async def wait_for_unlock(self, *, timeout_cycles: int = 2000) -> None:
        for _ in range(timeout_cycles):
            await self.cycle(1)
            if int(self.dut.locked.value) == 0:
                return
        raise AssertionError("Timed out waiting for GtRxAlignCheck to unlock")

    async def wait_for_drp_reads(self, count: int, *, timeout_cycles: int = 4000) -> None:
        for _ in range(timeout_cycles):
            await self.cycle(1)
            if self.drp.read_count >= count:
                return
        raise AssertionError(
            f"Timed out waiting for {count} DRP reads, saw {self.drp.read_count}"
        )

    async def wait_for_gt_error(self, *, timeout_cycles: int = 2000) -> None:
        # The GT model reports the error on its own clock, so wait for it rather
        # than assuming a fixed number of axilClk cycles have gone by.
        for _ in range(timeout_cycles):
            await self.cycle(1)
            if self.gt.err_assert_count >= 1:
                return
        raise AssertionError("Timed out waiting for the GT model to assert resetErr")

    async def wait_for_reset_pulses(self, count: int, *, timeout_cycles: int = 2000) -> None:
        for _ in range(timeout_cycles):
            await self.cycle(1)
            if self.monitor.pulses >= count:
                return
        raise AssertionError(
            f"Timed out waiting for {count} resetOut pulses, saw {self.monitor.pulses}"
        )

    async def read_hist_bin(self, index: int) -> int:
        offset, shift = phase_hist_bin(index)
        word = await axil_read_u32(self.axil, offset)
        return (word >> shift) & 0xFF

    async def read_all_hist_bins(self) -> list[int]:
        return [await self.read_hist_bin(index) for index in range(PHASE_HIST_BINS)]

    async def write_config(self, *, target: int, mask: int, rst_len: int) -> None:
        await axil_write_u32(
            self.axil, CONFIG_ADDR, config_word(target=target, mask=mask, rst_len=rst_len)
        )

    async def pulse_reset_in(self, *, hold_cycles: int = 4) -> None:
        # resetIn is documented ASYNC to axilClk, so move it mid-period rather
        # than on an edge to exercise the synchronizer instead of a clean setup.
        await RisingEdge(self.dut.axilClk)
        await Timer(RESET_IN_SKEW_NS, unit="ns")
        self.dut.resetIn.value = 1
        await self.cycle(hold_cycles)
        await Timer(RESET_IN_SKEW_NS, unit="ns")
        self.dut.resetIn.value = 0


@cocotb.test()
async def lock_on_matching_phase_test(dut):
    tb = TB(dut, phases=(MATCHING_PHASE,))
    await tb.reset()

    # A phase that satisfies (phase xor target) and mask == 0 should lock on the
    # first DRP read without any reset retry.
    await tb.wait_for_lock()

    assert int(dut.locked.value) == 1
    assert await axil_read_u32(tb.axil, LOCKED_ADDR) & 0x1 == 1
    assert await axil_read_u32(tb.axil, LAST_PHASE_ADDR) & 0x7F == MATCHING_PHASE
    assert await axil_read_u32(tb.axil, RETRY_CNT_ADDR) == 0
    assert await tb.read_hist_bin(MATCHING_PHASE) == 1

    # resetOut must be released once locked, so the GT datapath is not held.
    assert int(dut.resetOut.value) == 0

    # The DRP read has to target DRP_ADDR_G plus the family-specific
    # COMMA_ALIGN_LATENCY offset.
    assert tb.drp.read_addresses
    assert tb.drp.read_addresses[0] == tb.expected_drp_addr

    # Frequency monitors need a full one-second measurement window, so they are
    # expected to still read zero here. See the methodology block.
    assert await axil_read_u32(tb.axil, TX_CLK_FREQ_ADDR) == 0
    assert await axil_read_u32(tb.axil, RX_CLK_FREQ_ADDR) == 0
    assert await axil_read_u32(tb.axil, REF_CLK_FREQ_ADDR) == 0


@cocotb.test(skip=SIM_OVERRIDE)
async def retry_until_match_test(dut):
    phases = (MISMATCH_PHASES[0], MISMATCH_PHASES[1], MATCHING_PHASE)
    tb = TB(dut, phases=phases)
    await tb.reset()

    # Two mismatching phases must each trigger a reset retry before the third
    # read lands on the target.
    await tb.wait_for_lock()

    assert await axil_read_u32(tb.axil, RETRY_CNT_ADDR) == 2
    assert await axil_read_u32(tb.axil, LAST_PHASE_ADDR) & 0x7F == MATCHING_PHASE

    # Every read, matching or not, bumps its own histogram bin.
    for phase in phases:
        assert await tb.read_hist_bin(phase) == 1

    # Each mismatch drives one resetOut assertion.
    assert tb.monitor.pulses == 2


@cocotb.test(skip=SIM_OVERRIDE)
async def mask_and_target_programming_test(dut):
    tb = TB(dut, phases=(MISMATCH_PHASES[0],))
    await tb.reset()

    # Retarget the comparison at the phase the DRP is returning, so what was a
    # permanent mismatch becomes an immediate match.
    await tb.write_config(target=MISMATCH_PHASES[0], mask=0x7F, rst_len=DEFAULT_RST_LEN)

    readback = await axil_read_u32(tb.axil, CONFIG_ADDR)
    assert readback & 0x7F == MISMATCH_PHASES[0]
    assert (readback >> 8) & 0x7F == 0x7F
    assert (readback >> 16) & 0xF == DEFAULT_RST_LEN

    await tb.wait_for_lock()
    assert await axil_read_u32(tb.axil, LAST_PHASE_ADDR) & 0x7F == MISMATCH_PHASES[0]


@cocotb.test(skip=SIM_OVERRIDE)
async def zero_mask_matches_any_phase_test(dut):
    tb = TB(dut, phases=(MISMATCH_PHASES[1],))
    await tb.reset()

    # With the mask cleared, the masked comparison is always zero, so any phase
    # satisfies the lock condition regardless of the target.
    await tb.write_config(target=0, mask=0x00, rst_len=DEFAULT_RST_LEN)

    await tb.wait_for_lock()
    assert await axil_read_u32(tb.axil, LAST_PHASE_ADDR) & 0x7F == MISMATCH_PHASES[1]


@cocotb.test()
async def config_write_clears_histogram_test(dut):
    tb = TB(dut, phases=(MATCHING_PHASE,))
    await tb.reset()
    await tb.wait_for_lock()

    # Confirm there is histogram content to lose before exercising the clear.
    assert await tb.read_hist_bin(MATCHING_PHASE) >= 1

    # Any write to 0x100 clears the sampler. Use a distinct config value so the
    # test also proves the configuration fields keep their newly written values
    # and are not themselves reset by the side effect.
    await tb.write_config(target=33, mask=0x55, rst_len=9)

    assert await tb.read_all_hist_bins() == [0] * PHASE_HIST_BINS

    readback = await axil_read_u32(tb.axil, CONFIG_ADDR)
    assert readback & 0x7F == 33
    assert (readback >> 8) & 0x7F == 0x55
    assert (readback >> 16) & 0xF == 9


@cocotb.test(skip=SIM_OVERRIDE)
async def override_register_forces_lock_test(dut):
    tb = TB(dut, phases=(MISMATCH_PHASES[0],))
    await tb.reset()

    # A permanently mismatching phase should keep retrying, never locking.
    await tb.wait_for_drp_reads(2)
    assert int(dut.locked.value) == 0

    # Setting the override register makes the checker accept whatever phase it
    # reads and stop resetting the transceiver.
    await axil_write_u32(tb.axil, OVERRIDE_ADDR, 1)
    await tb.wait_for_lock()

    assert await axil_read_u32(tb.axil, OVERRIDE_ADDR) & 0x1 == 1
    assert await axil_read_u32(tb.axil, LOCKED_ADDR) & 0x1 == 1


@cocotb.test(skip=not SIM_OVERRIDE)
async def simulation_generic_locks_immediately_test(dut):
    tb = TB(dut, phases=(MISMATCH_PHASES[0],))
    await tb.reset()

    # SIMULATION_G seeds the override flag, so a mismatching phase still locks
    # on the first read and the register reads back already set.
    assert await axil_read_u32(tb.axil, OVERRIDE_ADDR) & 0x1 == 1

    await tb.wait_for_lock()
    assert await axil_read_u32(tb.axil, RETRY_CNT_ADDR) == 0
    assert await axil_read_u32(tb.axil, LAST_PHASE_ADDR) & 0x7F == MISMATCH_PHASES[0]


@cocotb.test(skip=SIM_OVERRIDE)
async def retry_counter_clear_test(dut):
    tb = TB(dut, phases=(MISMATCH_PHASES[0],))
    await tb.reset()

    # Let a few retries accumulate on a phase that never matches.
    await tb.wait_for_drp_reads(3)
    assert await axil_read_u32(tb.axil, RETRY_CNT_ADDR) > 0

    # The 0x118 strobe clears the counter. It is a one-shot in the RTL, so read
    # back promptly while the DUT is still retrying.
    await axil_write_u32(tb.axil, RST_RETRY_CNT_ADDR, 1)
    await tb.cycle(2)
    assert await axil_read_u32(tb.axil, RETRY_CNT_ADDR) == 0


@cocotb.test()
async def reset_in_restarts_test(dut):
    tb = TB(dut, phases=(MATCHING_PHASE,))
    await tb.reset()
    await tb.wait_for_lock()

    retry_before = await axil_read_u32(tb.axil, RETRY_CNT_ADDR)
    tb.monitor.reset_counts()

    # resetIn is asynchronous to axilClk, so assert it off the clock edge.
    await tb.pulse_reset_in()

    await tb.wait_for_unlock()
    assert tb.monitor.pulses >= 1

    # The checker must recover on its own once resetIn is released.
    await tb.wait_for_lock()

    # Resets requested through resetIn are excluded from the retry counter,
    # which only counts internally triggered alignment retries.
    assert await axil_read_u32(tb.axil, RETRY_CNT_ADDR) == retry_before


@cocotb.test()
async def reset_err_after_done_restarts_test(dut):
    tb = TB(dut, phases=(MATCHING_PHASE,))

    # Arm the failure before releasing axilRst so the very first alignment
    # attempt reports an error. Driving the error from the initial attempt keeps
    # the error path the only thing that can assert resetOut, so the pulse count
    # below is unambiguous.
    tb.gt.arm_error(lead_cycles=0)
    await tb.reset()
    assert tb.monitor.pulses == 0

    # Nominal helper-block ordering: done and error rise together.
    await tb.wait_for_gt_error()
    await tb.wait_for_reset_pulses(1)

    # The error is a sticky RX-domain level, so the checker must issue exactly
    # one reset for it rather than re-triggering while it stays asserted.
    await tb.wait_for_lock()
    assert tb.gt.err_assert_count == 1
    assert tb.monitor.pulses == 1

    # Error-triggered resets are excluded from the retry counter, which only
    # counts phase-mismatch retries.
    assert await axil_read_u32(tb.axil, RETRY_CNT_ADDR) == 0


@cocotb.test()
async def reset_err_before_done_restarts_test(dut):
    tb = TB(dut, phases=(MATCHING_PHASE,))

    # Regression test for the pre-CDC gate. resetErr rises 12 rxClk ahead of
    # resetDone here. Synchronizing the two levels separately and combining them
    # in axilClk makes the result depend on relative synchronizer latency, and a
    # one-shot on the error is silently dropped at this skew. Gating the two in
    # the RX clock domain makes the reset happen regardless of the ordering.
    tb.gt.arm_error(lead_cycles=12)
    await tb.reset()
    assert tb.monitor.pulses == 0

    await tb.wait_for_gt_error()
    await tb.wait_for_reset_pulses(1)

    assert tb.gt.err_assert_count == 1
    assert tb.monitor.pulses == 1

    # And the checker still recovers afterwards.
    await tb.wait_for_lock()


@cocotb.test()
async def reset_err_without_done_no_restart_test(dut):
    tb = TB(dut, phases=(MATCHING_PHASE,))

    # The RTL gates resetErr with resetDone, so an error raised while done stays
    # low cannot reach the reset logic. That is deliberate: the checker only acts
    # on errors reported by a completed alignment procedure.
    tb.gt.arm_error_without_done()
    await tb.reset()

    await tb.wait_for_gt_error()
    tb.monitor.reset_counts()

    # With done held low the checker parks waiting: no reset, no DRP read, and
    # no lock.
    await tb.cycle(400)
    assert int(dut.resetDone.value) == 0
    assert int(dut.resetErr.value) == 1
    assert int(dut.locked.value) == 0
    assert tb.monitor.pulses == 0
    assert tb.drp.read_count == 0


@cocotb.test(skip=SIM_OVERRIDE)
async def out_of_range_phase_test(dut):
    # 0x7F and 40 are both outside the 40-entry sample array. The RTL reads a
    # 7-bit COMMA_ALIGN_LATENCY field, so values up to 127 are possible from a
    # garbage or in-reset DRP read.
    out_of_range = (0x7F, PHASE_HIST_BINS)
    tb = TB(dut, phases=(out_of_range[0], out_of_range[1], MATCHING_PHASE))
    await tb.reset()

    # Regression test for the sample index bound check. Without it these reads
    # index past the end of the array, which is a GHDL bound-check failure and
    # a lost increment in hardware.
    await tb.wait_for_lock()

    # LastPhase still reports the out-of-range value, and the mismatch still
    # drives a retry, so only the histogram increment is suppressed.
    assert await axil_read_u32(tb.axil, RETRY_CNT_ADDR) == 2
    assert await axil_read_u32(tb.axil, LAST_PHASE_ADDR) & 0x7F == MATCHING_PHASE

    bins = await tb.read_all_hist_bins()
    assert bins[MATCHING_PHASE] == 1
    # No in-range bin may have absorbed an out-of-range read, so the matching
    # phase is the only bin that moved.
    assert sum(bins) == 1


@cocotb.test(skip=SIM_OVERRIDE)
async def rstlen_programmable_test(dut):
    tb = TB(dut, phases=(MISMATCH_PHASES[0],))
    await tb.reset()

    # RESET_S holds resetOut while rstcnt counts up to rstlen, so a longer
    # rstlen must widen the measured assertion.
    long_rst_len = 12
    await tb.write_config(target=DEFAULT_TARGET, mask=DEFAULT_MASK, rst_len=long_rst_len)

    tb.monitor.reset_counts()
    await tb.wait_for_drp_reads(tb.drp.read_count + 2)

    assert tb.monitor.pulses >= 1
    assert tb.monitor.max_width >= long_rst_len + 1


@cocotb.test()
async def axil_reset_returns_to_init_test(dut):
    tb = TB(dut, phases=(MATCHING_PHASE,))
    await tb.reset()
    await tb.wait_for_lock()

    # Dirty the writable state so the reset has something to undo.
    await tb.write_config(target=33, mask=0x55, rst_len=9)
    await axil_write_u32(tb.axil, OVERRIDE_ADDR, 1)
    await tb.cycle(4)

    # REG_INIT_C holds rst asserted and locked cleared, so axilRst must show up
    # immediately on both outputs.
    dut.axilRst.value = 1
    await tb.cycle(3)
    assert int(dut.locked.value) == 0
    assert int(dut.resetOut.value) == 1

    dut.axilRst.value = 0
    await tb.cycle(3)

    # The configuration fields must be back at their generic-derived defaults
    # and the counters and histogram cleared.
    readback = await axil_read_u32(tb.axil, CONFIG_ADDR)
    assert readback & 0x7F == DEFAULT_TARGET
    assert (readback >> 8) & 0x7F == DEFAULT_MASK
    assert (readback >> 16) & 0xF == DEFAULT_RST_LEN
    assert await axil_read_u32(tb.axil, RETRY_CNT_ADDR) == 0
    assert await axil_read_u32(tb.axil, OVERRIDE_ADDR) & 0x1 == int(SIM_OVERRIDE)


@cocotb.test()
async def unmapped_access_returns_ok_test(dut):
    tb = TB(dut, phases=(MATCHING_PHASE,))
    await tb.reset()
    await tb.wait_for_lock()

    # The RTL closes the endpoint with axiSlaveDefault(..., AXI_RESP_OK_C), so
    # unmapped offsets answer OKAY rather than DECERR. Pin that, because the
    # response code is part of the register-map contract that software sees.
    txn = await tb.axil.read(0x200, 4)
    assert txn.resp == AxiResp.OKAY

    txn = await tb.axil.write(0x204, (0).to_bytes(4, "little"))
    assert txn.resp == AxiResp.OKAY


PARAMETER_SWEEP = [
    parameter_case(
        "gthe3_base0",
        GT_TYPE_G="GTHE3",
        SIMULATION_G="false",
        LOCK_VALUE_G="16",
        MASK_VALUE_G="126",
        DRP_ADDR_INT_G="0",
    ),
    parameter_case(
        "gthe4_offset",
        GT_TYPE_G="GTHE4",
        SIMULATION_G="false",
        LOCK_VALUE_G="16",
        MASK_VALUE_G="126",
        DRP_ADDR_INT_G="4194304",
    ),
    parameter_case(
        "simulation_override",
        GT_TYPE_G="GTHE3",
        SIMULATION_G="true",
        LOCK_VALUE_G="16",
        MASK_VALUE_G="126",
        DRP_ADDR_INT_G="0",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_GtRxAlignCheck(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.gtrxaligncheckwrapper",
        parameters=parameters,
        extra_env=parameters,
        extra_vhdl_sources={
            "surf": ["xilinx/general/wrappers/GtRxAlignCheckWrapper.vhd"],
        },
    )
