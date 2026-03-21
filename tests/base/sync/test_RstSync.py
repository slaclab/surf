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
# - Sweep: Sweep release delays of `3` and `5`, an active-low reset case, a
#   bypass case, and a no-output asynchronous-reset case so both latency and
#   optional bypass behavior are covered.
# - Stimulus: Assert and deassert the incoming reset while the destination
#   clock runs so the synchronizer chain has to absorb assertion and release.
# - Checks: The bench checks delayed release count, immediate or configured
#   assertion behavior, bypass behavior, and the no-output option.
# - Timing: Release is checked in exact destination-clock cycles through the
#   synchronizer depth, while asynchronous assertion is expected to clear the
#   chain immediately.

import os

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, RisingEdge, Timer

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
        self.in_polarity = env_sl("IN_POLARITY_G", default=1)
        self.out_polarity = env_sl("OUT_POLARITY_G", default=1)
        self.bypass_sync = env_flag("BYPASS_SYNC_G", default=False)
        self.out_reg_rst = env_flag("OUT_REG_RST_G", default=True)
        self.release_delay = int(os.environ["RELEASE_DELAY_G"])
        self.clk_period_ns = float(os.environ["CLK_PERIOD_NS"])

        # Drive the asynchronous reset input active before the first clock edge
        # so the DUT starts in its asserted reset state.
        dut.asyncRst.value = self.input_active_value()

        cocotb.start_soon(Clock(dut.clk, self.clk_period_ns, unit="ns").start())

    def input_active_value(self) -> int:
        return self.in_polarity

    def input_inactive_value(self) -> int:
        return 1 - self.in_polarity

    def output_active_value(self) -> int:
        return self.out_polarity

    def output_inactive_value(self) -> int:
        return 1 - self.out_polarity

    def expected_release_cycles(self) -> int:
        # In normal mode the synchronizer chain plus the final output register
        # keep reset asserted for one fewer cycle than the generic name might
        # suggest because `RELEASE_DELAY_G` includes the final stage itself. In
        # bypass mode only the final output register remains.
        return 1 if self.bypass_sync else self.release_delay - 1

    async def settle(self) -> None:
        await Timer(2, unit="ns")

    async def cycle(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.clk)
            await self.settle()


@cocotb.test()
async def release_delay_test(dut):
    tb = TB(dut)
    await tb.cycle(2)

    # While the asynchronous input is active, the synchronized output should
    # remain asserted.
    assert int(dut.syncRst.value) == tb.output_active_value()

    # Release the asynchronous reset halfway between clock edges so the test is
    # not accidentally relying on edge-aligned stimulus.
    await FallingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.asyncRst.value = tb.input_inactive_value()
    await tb.settle()

    # The synchronized reset should stay asserted until the configured release
    # pipeline has drained.
    for _ in range(tb.expected_release_cycles() - 1):
        await tb.cycle(1)
        assert int(dut.syncRst.value) == tb.output_active_value()

    await tb.cycle(1)
    assert int(dut.syncRst.value) == tb.output_inactive_value()


@cocotb.test()
async def assertion_behavior_test(dut):
    tb = TB(dut)
    await tb.cycle(2)

    # First release reset and wait for the synchronized output to deassert.
    dut.asyncRst.value = tb.input_inactive_value()
    for _ in range(tb.expected_release_cycles() + 2):
        await tb.cycle(1)
    assert int(dut.syncRst.value) == tb.output_inactive_value()

    # Assert reset between edges so the test can distinguish whether the final
    # output register has its own asynchronous reset path.
    await FallingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.asyncRst.value = tb.input_active_value()
    await tb.settle()

    if tb.out_reg_rst:
        assert int(dut.syncRst.value) == tb.output_active_value()
    else:
        assert int(dut.syncRst.value) == tb.output_inactive_value()
        await tb.cycle(1)
        assert int(dut.syncRst.value) == tb.output_active_value()


PARAMETER_SWEEP = [
    parameter_case(
        "delay3_baseline",
        IN_POLARITY_G="'1'",
        OUT_POLARITY_G="'1'",
        BYPASS_SYNC_G="false",
        RELEASE_DELAY_G="3",
        OUT_REG_RST_G="true",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "delay5_active_low",
        IN_POLARITY_G="'0'",
        OUT_POLARITY_G="'0'",
        BYPASS_SYNC_G="false",
        RELEASE_DELAY_G="5",
        OUT_REG_RST_G="true",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "bypass_sync",
        IN_POLARITY_G="'1'",
        OUT_POLARITY_G="'1'",
        BYPASS_SYNC_G="true",
        RELEASE_DELAY_G="4",
        OUT_REG_RST_G="true",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "no_output_async_reset",
        IN_POLARITY_G="'1'",
        OUT_POLARITY_G="'1'",
        BYPASS_SYNC_G="false",
        RELEASE_DELAY_G="3",
        OUT_REG_RST_G="false",
        CLK_PERIOD_NS="5",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_RstSync(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.rstsync",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
