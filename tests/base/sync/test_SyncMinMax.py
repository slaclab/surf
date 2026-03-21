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
from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import (
    env_flag,
    hdl_parameters_from,
    parameter_case,
    run_surf_vhdl_test,
    start_lockstep_clocks,
)


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.common_clk = env_flag("COMMON_CLK_G", default=False)
        self.async_reset = env_flag("RST_ASYNC_G", default=False)
        self.wr_clk_period_ns = float(os.environ["WR_CLK_PERIOD_NS"])
        self.rd_clk_period_ns = float(os.environ["RD_CLK_PERIOD_NS"])

        dut.rstStat.value = 0
        dut.wrRst.value = 1
        dut.wrEn.value = 0
        dut.dataIn.value = 0
        dut.rdEn.value = 1

        if self.common_clk:
            # COMMON_CLK_G assumes both ports see the same edge at the same
            # instant, so drive them from one shared coroutine here.
            start_lockstep_clocks(dut.wrClk, dut.rdClk, period_ns=self.wr_clk_period_ns)
        else:
            cocotb.start_soon(Clock(dut.wrClk, self.wr_clk_period_ns, unit="ns").start())
            cocotb.start_soon(Clock(dut.rdClk, self.rd_clk_period_ns, unit="ns").start())

    async def settle(self) -> None:
        await Timer(2, unit="ns")

    async def reset(self) -> None:
        # The DUT only exposes a write-domain reset, but it still needs an
        # explicit startup pulse so the internal comparator/FIFO chain does not
        # drop the first sample while coming out of its initialized reset state.
        self.dut.wrRst.value = 1
        if self.async_reset:
            await Timer(2, unit="ns")
        await self.cycle_wr(3)
        self.dut.wrRst.value = 0
        await self.cycle_wr(2)
        await self.cycle_rd(2)

    async def cycle_wr(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.wrClk)
            await self.settle()

    async def cycle_rd(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.rdClk)
            await self.settle()

    async def write_sample(self, value: int) -> None:
        # Present one write pulse for a single wrClk edge, then drop wrEn so
        # each update corresponds to exactly one statistics sample.
        self.dut.dataIn.value = value
        self.dut.wrEn.value = 1
        await self.cycle_wr(1)
        self.dut.wrEn.value = 0

    async def wait_updated(self) -> None:
        for _ in range(40):
            await self.cycle_rd(1)
            if int(self.dut.updated.value) == 1:
                return
        assert int(self.dut.updated.value) == 1

    async def wait_for_snapshot(self, *, value: int, minimum: int, maximum: int) -> None:
        # `updated` is the contract that says a fresh snapshot is present in the
        # read domain. Sample all three outputs on that event instead of
        # assuming `dataOut` is held indefinitely after the transfer.
        await self.wait_updated()
        assert int(self.dut.dataOut.value) == value
        assert int(self.dut.dataMin.value) == minimum
        assert int(self.dut.dataMax.value) == maximum


@cocotb.test()
async def min_max_tracking_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Feed three samples and check that the read-domain copy tracks the latest
    # value while min/max track the observed extrema.
    for value, expected_min, expected_max in [(7, 7, 7), (3, 3, 7), (9, 3, 9)]:
        await tb.write_sample(value)
        await tb.wait_for_snapshot(value=value, minimum=expected_min, maximum=expected_max)


@cocotb.test()
async def statistics_reset_test(dut):
    tb = TB(dut)
    await tb.reset()

    await tb.write_sample(6)
    await tb.wait_for_snapshot(value=6, minimum=6, maximum=6)
    await tb.write_sample(2)
    await tb.wait_for_snapshot(value=2, minimum=2, maximum=6)

    # rstStat is a separate asynchronous statistics reset path. After it fires,
    # the next accepted sample should seed dataOut/dataMin/dataMax anew.
    tb.dut.rstStat.value = 1
    await tb.cycle_wr(1)
    tb.dut.rstStat.value = 0
    # The statistics reset reloads the same internal reset state as power-up,
    # so leave two write-domain cycles for the internal `reset` flag to clear
    # before presenting the first post-reset sample.
    await tb.cycle_wr(2)

    await tb.write_sample(4)
    await tb.wait_for_snapshot(value=4, minimum=4, maximum=4)


PARAMETER_SWEEP = [
    parameter_case(
        "common_clock",
        RST_ASYNC_G="false",
        COMMON_CLK_G="true",
        WIDTH_G="8",
        WR_CLK_PERIOD_NS="5",
        RD_CLK_PERIOD_NS="5",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_SyncMinMax(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.syncminmax",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
