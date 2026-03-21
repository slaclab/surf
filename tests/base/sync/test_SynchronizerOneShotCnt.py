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
        self.in_polarity = env_sl("IN_POLARITY_G", default=1)
        self.out_polarity = env_sl("OUT_POLARITY_G", default=1)
        self.rollover_enabled = env_flag("ROLL_OVER_EN", default=False)
        self.clk_period_ns = float(os.environ["WR_CLK_PERIOD_NS"])
        self.rd_clk_period_ns = float(os.environ["RD_CLK_PERIOD_NS"])
        self.counter_width = int(os.environ["CNT_WIDTH_G"])
        self.max_count = (1 << self.counter_width) - 1

        dut.wrRst.value = self.reset_active_value()
        dut.rdRst.value = self.reset_active_value()
        dut.dataIn.value = self.input_inactive_value()
        dut.rollOverEn.value = 1 if self.rollover_enabled else 0
        dut.cntRst.value = self.reset_inactive_value()

        # Start the write and read domains before any pulses are issued so the
        # helpers can speak in terms of source-side and destination-side cycles.
        cocotb.start_soon(Clock(dut.wrClk, self.clk_period_ns, unit="ns").start())
        if self.common_clk:
            cocotb.start_soon(Clock(dut.rdClk, self.clk_period_ns, unit="ns").start())
        else:
            cocotb.start_soon(Clock(dut.rdClk, self.rd_clk_period_ns, unit="ns").start())

    def reset_active_value(self) -> int:
        return self.rst_polarity

    def reset_inactive_value(self) -> int:
        return 1 - self.rst_polarity

    def input_active_value(self) -> int:
        return self.in_polarity

    def input_inactive_value(self) -> int:
        return 1 - self.in_polarity

    def output_active_value(self) -> int:
        return self.out_polarity

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
        # Reset both domains together, then leave a couple of post-reset cycles
        # for the synchronized pulse/counter state to settle before testing.
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

    async def pulse_input(self) -> None:
        # Generate a one-cycle source-domain pulse. The DUT should convert this
        # into exactly one count increment after synchronization.
        self.dut.dataIn.value = self.input_active_value()
        await self.cycle_wr(1)
        self.dut.dataIn.value = self.input_inactive_value()
        await self.cycle_wr(1)

    async def wait_for_count(self, value: int) -> None:
        # The count update can arrive several destination-clock edges later, so
        # poll with a bounded wait instead of assuming a fixed CDC latency.
        for _ in range(20):
            await self.cycle_rd(1)
            if int(self.dut.cntOut.value) == value:
                return
        assert int(self.dut.cntOut.value) == value


@cocotb.test()
async def count_increment_test(dut):
    tb = TB(dut)
    await tb.reset()

    # One source pulse should become one destination-side count increment.
    await tb.pulse_input()
    await tb.wait_for_count(1)


@cocotb.test()
async def saturation_and_reset_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Drive enough pulses to hit either the saturating limit or the rollover
    # boundary, depending on the active generic configuration.
    pulse_count = tb.max_count + (1 if tb.rollover_enabled else 0)
    for _ in range(pulse_count + 1):
        await tb.pulse_input()

    expected = 1 if tb.rollover_enabled else tb.max_count
    await tb.wait_for_count(expected)

    # Then assert the dedicated counter reset and confirm the synchronized
    # count returns to zero without needing a full module reset.
    tb.dut.cntRst.value = tb.reset_active_value()
    await tb.cycle_wr(1)
    tb.dut.cntRst.value = tb.reset_inactive_value()
    await tb.wait_for_count(0)


PARAMETER_SWEEP = [
    parameter_case(
        "common_clock_baseline",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        COMMON_CLK_G="true",
        IN_POLARITY_G="'1'",
        OUT_POLARITY_G="'1'",
        CNT_RST_EDGE_G="true",
        CNT_WIDTH_G="3",
        ROLL_OVER_EN="false",
        WR_CLK_PERIOD_NS="5",
        RD_CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "async_clock_rollover",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        COMMON_CLK_G="false",
        IN_POLARITY_G="'1'",
        OUT_POLARITY_G="'1'",
        CNT_RST_EDGE_G="true",
        CNT_WIDTH_G="2",
        ROLL_OVER_EN="true",
        WR_CLK_PERIOD_NS="5",
        RD_CLK_PERIOD_NS="7",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_SynchronizerOneShotCnt(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.synchronizeroneshotcnt",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
