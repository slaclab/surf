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
# - Sweep: Sweep the wrapper across the inferred synchronous and inferred
#   asynchronous backends with `FWFT` enabled so this file proves wrapper
#   selection rather than re-testing every leaf FIFO feature.
# - Stimulus: Write an ordered burst into the wrapper and read it back, then in
#   the synchronous case inspect the mirrored write and read count outputs
#   while occupancy changes.
# - Checks: The wrapper must preserve ordering through both backend branches
#   and, in common-clock mode, expose the same internal count on both
#   `wr_data_count` and `rd_data_count` aliases.
# - Timing: The asynchronous branch is checked with independent write and read
#   clocks, while the synchronous branch checks that count updates track
#   occupancy on the same clock without extra wrapper skew.

import os

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, with_timeout

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
        self.sync_fifo = env_flag("GEN_SYNC_FIFO_G", default=False)
        self.async_reset = env_flag("RST_ASYNC_G", default=False)
        self.rst_polarity = env_sl("RST_POLARITY_G", default=1)
        self.wr_clk_period_ns = float(os.environ["WR_CLK_PERIOD_NS"])
        self.rd_clk_period_ns = float(os.environ["RD_CLK_PERIOD_NS"])

        dut.rst.value = self.reset_active_value()
        dut.wr_en.value = 0
        dut.rd_en.value = 0
        dut.din.value = 0

        # The sync wrapper path assumes the two FIFO clocks are actually the
        # same clock, so drive them in lockstep there instead of relying on
        # two independent same-period clock coroutines.
        if self.sync_fifo:
            start_lockstep_clocks(dut.wr_clk, dut.rd_clk, period_ns=self.wr_clk_period_ns)
        else:
            cocotb.start_soon(Clock(dut.wr_clk, self.wr_clk_period_ns, unit="ns").start())
            cocotb.start_soon(Clock(dut.rd_clk, self.rd_clk_period_ns, unit="ns").start())

    def reset_active_value(self) -> int:
        return self.rst_polarity

    def reset_inactive_value(self) -> int:
        return 1 - self.rst_polarity

    async def settle(self) -> None:
        await Timer(2, unit="ns")

    async def cycle_wr(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.wr_clk)
            await self.settle()

    async def cycle_rd(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.rd_clk)
            await self.settle()

    async def reset(self) -> None:
        # Give the selected FIFO backend several clean cycles in each visible
        # domain before and after reset deassertion so wrapper status outputs
        # start from a known state.
        self.dut.rst.value = self.reset_active_value()
        if self.async_reset:
            await Timer(2, unit="ns")
        await self.cycle_wr(6)
        await self.cycle_rd(6)
        self.dut.rst.value = self.reset_inactive_value()
        await self.cycle_wr(6)
        await self.cycle_rd(6)

    async def write_word(self, value: int) -> None:
        await with_timeout(self._wait_not_full(), 5, "us")
        self.dut.din.value = value
        self.dut.wr_en.value = 1
        await self.cycle_wr(1)
        self.dut.wr_en.value = 0
        await self.cycle_wr(1)

    async def read_word(self) -> int:
        # This curated wrapper matrix keeps FWFT enabled in both branches so
        # the read side can always wait for `valid`, sample `dout`, then
        # consume the entry with one explicit `rd_en` pulse.
        await with_timeout(self._wait_valid(), 5, "us")
        value = int(self.dut.dout.value)
        self.dut.rd_en.value = 1
        await self.cycle_rd(1)
        self.dut.rd_en.value = 0
        await self.cycle_rd(1)
        return value

    async def _wait_not_full(self) -> None:
        while int(self.dut.not_full.value) == 0:
            await RisingEdge(self.dut.wr_clk)

    async def _wait_valid(self) -> None:
        while int(self.dut.valid.value) == 0:
            await RisingEdge(self.dut.rd_clk)


@cocotb.test()
async def wrapper_branch_ordering_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Drive a short sequence through the wrapper and require the selected
    # branch to preserve ordering end to end.
    expected = [0x11, 0x22, 0x33]
    for value in expected:
        await tb.write_word(value)

    observed = []
    for _ in expected:
        observed.append(await tb.read_word())

    assert observed == expected


@cocotb.test(skip=not env_flag("GEN_SYNC_FIFO_G", default=False))
async def sync_count_alias_test(dut):
    tb = TB(dut)
    await tb.reset()

    # The sync wrapper aliases both public count ports to the same internal
    # `data_count` signal. Check that alias explicitly instead of re-testing
    # every deep FifoSync flag behavior here.
    await tb.write_word(0x41)
    await tb.write_word(0x42)
    await tb.cycle_wr(2)
    assert int(dut.wr_data_count.value) == int(dut.rd_data_count.value)
    assert int(dut.wr_data_count.value) > 0

    assert await tb.read_word() == 0x41
    assert await tb.read_word() == 0x42
    await tb.cycle_wr(1)
    assert int(dut.wr_data_count.value) == 0
    assert int(dut.rd_data_count.value) == 0


PARAMETER_SWEEP = [
    parameter_case(
        "sync_inferred_fwft",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        GEN_SYNC_FIFO_G="true",
        FWFT_EN_G="true",
        SYNTH_MODE_G="inferred",
        MEMORY_TYPE_G="distributed",
        DATA_WIDTH_G="8",
        ADDR_WIDTH_G="4",
        WR_CLK_PERIOD_NS="5",
        RD_CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "async_inferred_fwft",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'0'",
        GEN_SYNC_FIFO_G="false",
        FWFT_EN_G="true",
        SYNTH_MODE_G="inferred",
        MEMORY_TYPE_G="distributed",
        DATA_WIDTH_G="8",
        ADDR_WIDTH_G="4",
        WR_CLK_PERIOD_NS="5",
        RD_CLK_PERIOD_NS="9",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Fifo(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.fifo",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
