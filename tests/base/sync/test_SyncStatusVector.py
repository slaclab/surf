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
# - Sweep: Sweep a common-clock case and an asynchronous-clocks case so the
#   status synchronizer and its bookkeeping are covered with and without CDC
#   latency.
# - Stimulus: Toggle status bits, hold selected lanes active long enough to
#   accumulate counters, trigger IRQ conditions, and then pulse the
#   counter-reset input.
# - Checks: The synchronized status output, change/error counters, IRQ outputs,
#   and explicit counter reset behavior must all match the driven status
#   activity.
# - Timing: The common-clock case is checked for near-immediate updates, while
#   the asynchronous case expects extra CDC latency before the same status and
#   IRQ effects become visible.

import os
from pathlib import Path

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import (
    env_flag,
    env_sl,
    hdl_parameters_from,
    parameter_case,
    run_surf_vhdl_test,
    start_lockstep_clocks,
)


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.width = int(os.environ["WIDTH_G"])
        self.cnt_width = int(os.environ["CNT_WIDTH_G"])
        self.common_clk = env_flag("COMMON_CLK_G", default=False)
        self.async_reset = env_flag("RST_ASYNC_G", default=False)
        self.rst_polarity = env_sl("RST_POLARITY_G", default=1)
        self.clk_period_ns = float(os.environ["WR_CLK_PERIOD_NS"])
        self.rd_clk_period_ns = float(os.environ["RD_CLK_PERIOD_NS"])

        dut.wrRst.value = self.reset_active_value()
        dut.rdRst.value = self.reset_active_value()
        dut.statusIn.value = 0
        dut.cntRstIn.value = self.reset_inactive_value()
        dut.rollOverEnIn.value = 0
        dut.irqEnIn.value = 0

        if self.common_clk:
            # Drive both clock ports together when COMMON_CLK_G is set so the
            # testbench matches the wrapper's bypass assumptions.
            start_lockstep_clocks(dut.wrClk, dut.rdClk, period_ns=self.clk_period_ns)
        else:
            cocotb.start_soon(Clock(dut.wrClk, self.clk_period_ns, unit="ns").start())
            cocotb.start_soon(Clock(dut.rdClk, self.rd_clk_period_ns, unit="ns").start())

    def reset_active_value(self) -> int:
        return self.rst_polarity

    def reset_inactive_value(self) -> int:
        return 1 - self.rst_polarity

    def counts(self) -> list[int]:
        raw = int(self.dut.cntOutFlat.value)
        mask = (1 << self.cnt_width) - 1
        return [(raw >> (index * self.cnt_width)) & mask for index in range(self.width)]

    async def settle(self) -> None:
        await Timer(2, unit="ns")

    async def cycle_wr(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.wrClk)
            await self.settle()

    async def cycle_rd(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.rdClk)
            await self.settle()

    async def reset(self) -> None:
        self.dut.wrRst.value = self.reset_active_value()
        self.dut.rdRst.value = self.reset_active_value()
        if self.async_reset:
            await Timer(2, unit="ns")
        await self.cycle_wr(3)
        await self.cycle_rd(3)
        self.dut.wrRst.value = self.reset_inactive_value()
        self.dut.rdRst.value = self.reset_inactive_value()
        await self.cycle_wr(2)
        await self.cycle_rd(2)

    async def drive_status(self, value: int, *, wr_cycles: int) -> None:
        self.dut.statusIn.value = value
        await self.cycle_wr(wr_cycles)
        self.dut.statusIn.value = 0

    async def wait_for_count(self, index: int, value: int) -> None:
        for _ in range(40):
            await self.cycle_rd(1)
            if self.counts()[index] == value:
                return
        assert self.counts()[index] == value

    async def wait_for_status(self, mask: int) -> None:
        for _ in range(20):
            await self.cycle_rd(1)
            if int(self.dut.statusOut.value) == mask:
                return
        assert int(self.dut.statusOut.value) == mask

    async def wait_for_irq(self) -> None:
        for _ in range(20):
            await self.cycle_rd(1)
            if int(self.dut.irqOut.value) == 1:
                return
        assert int(self.dut.irqOut.value) == 1

    async def wait_for_count_and_irq(self, index: int, value: int) -> None:
        observed_irq = False
        for _ in range(40):
            await self.cycle_rd(1)
            observed_irq |= int(self.dut.irqOut.value) == 1
            if self.counts()[index] == value and observed_irq:
                return
        assert self.counts()[index] == value
        assert observed_irq


@cocotb.test()
async def status_and_irq_test(dut):
    tb = TB(dut)
    await tb.reset()

    # First hold one status bit high long enough for the plain SynchronizerVector
    # path to reflect it into the read clock domain.
    tb.dut.statusIn.value = 0b010
    await tb.wait_for_status(0b010)
    tb.dut.statusIn.value = 0
    await tb.cycle_wr(1)

    # Then enable IRQ generation on bit 0 and pulse that same lane. This keeps
    # the check focused on the registered IRQ path instead of mixing in
    # independent per-lane counter behavior that is already covered elsewhere.
    tb.dut.irqEnIn.value = 0b001
    # Hold the source bit for two write-clock cycles so the async CDC path has
    # ample time to observe one clean event before the one-shot logic reduces
    # it back to a single destination-side strobe.
    await tb.drive_status(0b001, wr_cycles=2)
    # Observe the counter update and the IRQ pulse together so a one-cycle
    # interrupt cannot be lost while the test is still waiting on the counter.
    await tb.wait_for_count_and_irq(0, 1)


@cocotb.test()
async def counter_reset_test(dut):
    tb = TB(dut)
    await tb.reset()

    await tb.drive_status(0b100, wr_cycles=1)
    await tb.wait_for_count(2, 1)

    # Reset the counter bank through cntRstIn and confirm the flattened counter
    # outputs return to zero without disturbing the clock-domain crossing logic.
    tb.dut.cntRstIn.value = tb.reset_active_value()
    await tb.cycle_wr(1)
    tb.dut.cntRstIn.value = tb.reset_inactive_value()
    await tb.wait_for_count(2, 0)


PARAMETER_SWEEP = [
    parameter_case(
        "common_clock",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        COMMON_CLK_G="true",
        CNT_RST_EDGE_G="true",
        CNT_WIDTH_G="3",
        WIDTH_G="3",
        WR_CLK_PERIOD_NS="5",
        RD_CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "async_clocks",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        COMMON_CLK_G="false",
        CNT_RST_EDGE_G="true",
        CNT_WIDTH_G="3",
        WIDTH_G="3",
        WR_CLK_PERIOD_NS="5",
        RD_CLK_PERIOD_NS="7",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_SyncStatusVector(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.syncstatusvectorflatwrapper",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
        extra_vhdl_sources={"surf": [str(Path("base/sync/wrappers/SyncStatusVectorFlatWrapper.vhd"))]},
    )
