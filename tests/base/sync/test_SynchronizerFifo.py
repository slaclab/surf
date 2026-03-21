##############################################################################
## This file is part of 'SLAC Firmware Standard Library'.
## It is subject to the license terms in the LICENSE.txt file found in the
## top-level directory of this distribution and at:
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html.
## No part of 'SLAC Firmware Standard Library', including this file,
## may be copied, modified, propagated, or distributed except according to
## the terms contained in the LICENSE.txt file.
##############################################################################

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
)


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.common_clk = env_flag("COMMON_CLK_G", default=False)
        self.async_reset = env_flag("RST_ASYNC_G", default=False)
        self.rst_polarity = env_sl("RST_POLARITY_G", default=1)
        self.init_value = 0
        self.wr_clk_period_ns = float(os.environ["WR_CLK_PERIOD_NS"])
        self.rd_clk_period_ns = float(os.environ["RD_CLK_PERIOD_NS"])

        dut.rst.value = self.reset_active_value()
        dut.wr_en.value = 0
        dut.rd_en.value = 1 if not self.common_clk else 0
        dut.din.value = 0

        cocotb.start_soon(Clock(dut.wr_clk, self.wr_clk_period_ns, unit="ns").start())
        if self.common_clk:
            cocotb.start_soon(Clock(dut.rd_clk, self.wr_clk_period_ns, unit="ns").start())
        else:
            cocotb.start_soon(Clock(dut.rd_clk, self.rd_clk_period_ns, unit="ns").start())

    def observed_dout(self) -> int | None:
        try:
            return int(self.dut.dout.value)
        except ValueError:
            return None

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
        # Hold reset long enough for both domains to come out cleanly before the
        # wrapper starts forwarding FIFO status.
        self.dut.rst.value = self.reset_active_value()
        if self.async_reset:
            await Timer(2, unit="ns")
        await self.cycle_wr(6)
        await self.cycle_rd(6)
        self.dut.rst.value = self.reset_inactive_value()
        await self.cycle_wr(6)
        await self.cycle_rd(6)

    async def write(self, value: int) -> None:
        self.dut.din.value = value
        self.dut.wr_en.value = 1
        await self.cycle_wr(1)
        self.dut.wr_en.value = 0
        await self.cycle_wr(1)
        await self.settle()

    async def expect_common_clock_passthrough(self, value: int) -> None:
        self.dut.din.value = value
        self.dut.wr_en.value = 1
        # COMMON_CLK_G bypasses the FIFO entirely, so sample the combinational
        # pass-through before advancing the clock.
        await self.settle()
        assert int(self.dut.valid.value) == 1
        assert int(self.dut.dout.value) == value
        await self.cycle_wr(1)
        self.dut.wr_en.value = 0
        await self.settle()
        assert int(self.dut.valid.value) == 0

    async def read(self) -> int:
        assert not self.common_clk

        # The async wrapper hardwires FifoAsync into FWFT mode, so valid can
        # assert before rd_en. Sample the word first, then pulse rd_en to
        # consume it and advance to the next entry.
        self.dut.rd_en.value = 1
        await with_timeout(self._wait_valid(), 5, "us")
        value = int(self.dut.dout.value)
        await self.cycle_rd(1)
        return value

    async def _wait_valid(self) -> None:
        while int(self.dut.valid.value) == 0:
            await RisingEdge(self.dut.rd_clk)
            await self.settle()


@cocotb.test()
async def data_order_test(dut):
    tb = TB(dut)
    await tb.reset()

    values = [0x11, 0x22, 0x33]
    if tb.common_clk:
        for value in values:
            await tb.expect_common_clock_passthrough(value)
        return

    for value in values:
        await tb.write(value)

    observed = []
    for _ in values:
        observed.append(await tb.read())

    assert observed == values


@cocotb.test()
async def common_clock_bypass_test(dut):
    tb = TB(dut)
    if not tb.common_clk:
        return

    await tb.reset()
    await tb.expect_common_clock_passthrough(0x5A)


@cocotb.test()
async def reset_value_test(dut):
    tb = TB(dut)
    await tb.reset()
    assert int(dut.valid.value) == 0
    observed = tb.observed_dout()
    # The wrapper only qualifies dout with valid. Once valid is low, the async
    # path can legally retain stale RAM contents on dout.
    if tb.common_clk and observed is not None:
        assert observed == tb.init_value


PARAMETER_SWEEP = [
    parameter_case(
        "common_clock_bypass",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        COMMON_CLK_G="true",
        MEMORY_TYPE_G="distributed",
        DATA_WIDTH_G="8",
        ADDR_WIDTH_G="3",
        WR_CLK_PERIOD_NS="5",
        RD_CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "async_active_low_reset",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'0'",
        COMMON_CLK_G="false",
        MEMORY_TYPE_G="distributed",
        DATA_WIDTH_G="8",
        ADDR_WIDTH_G="3",
        WR_CLK_PERIOD_NS="5",
        RD_CLK_PERIOD_NS="9",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_SynchronizerFifo(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.synchronizerfifo",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
