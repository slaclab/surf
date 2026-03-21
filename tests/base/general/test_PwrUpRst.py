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
        self.async_reset = env_flag("RST_ASYNC_G", default=False)
        self.in_polarity = env_sl("IN_POLARITY_G", default=1)
        self.out_polarity = env_sl("OUT_POLARITY_G", default=1)
        self.duration = int(os.environ["DURATION_G"])
        self.clk_period_ns = float(os.environ["CLK_PERIOD_NS"])

        # Hold the external reset active initially so the test can control when
        # the internal power-up timer begins counting down.
        dut.arst.value = self.input_active_value()

        cocotb.start_soon(Clock(dut.clk, self.clk_period_ns, unit="ns").start())

    def input_active_value(self) -> int:
        return self.in_polarity

    def input_inactive_value(self) -> int:
        return 1 - self.in_polarity

    def output_active_value(self) -> int:
        return self.out_polarity

    def output_inactive_value(self) -> int:
        return 1 - self.out_polarity

    async def settle(self) -> None:
        await Timer(2, unit="ns")

    async def cycle(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.clk)
            await self.settle()


@cocotb.test()
async def duration_hold_test(dut):
    tb = TB(dut)
    await tb.cycle(2)
    assert int(dut.rstOut.value) == tb.output_active_value()

    # Release the external reset off-edge so the internal synchronizer and
    # counter logic have to handle a realistic asynchronous transition.
    await FallingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.arst.value = tb.input_inactive_value()
    await tb.settle()

    # The module should hold reset for at least the programmed duration and
    # then eventually release it.
    released_after = 0
    while int(dut.rstOut.value) == tb.output_active_value() and released_after < tb.duration + 10:
        await tb.cycle(1)
        released_after += 1

    assert released_after > tb.duration
    assert int(dut.rstOut.value) == tb.output_inactive_value()


@cocotb.test()
async def reassert_behavior_test(dut):
    tb = TB(dut)
    await tb.cycle(2)
    dut.arst.value = tb.input_inactive_value()

    # Wait until the timer-based reset has finished and the output reset is no
    # longer asserted.
    for _ in range(tb.duration + 10):
        await tb.cycle(1)
        if int(dut.rstOut.value) == tb.output_inactive_value():
            break

    assert int(dut.rstOut.value) == tb.output_inactive_value()

    # Assert the upstream reset between edges to distinguish the synchronous
    # and asynchronous counter-reset options.
    await FallingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.arst.value = tb.input_active_value()
    await tb.settle()

    if tb.async_reset:
        # In the async-counter-reset configuration, the reassertion can happen
        # immediately or within the next destination clock depending on when the
        # internal synchronized reset settles relative to this sample point.
        if int(dut.rstOut.value) != tb.output_active_value():
            await tb.cycle(1)
        assert int(dut.rstOut.value) == tb.output_active_value()
    else:
        assert int(dut.rstOut.value) == tb.output_inactive_value()
        await tb.cycle(1)
        assert int(dut.rstOut.value) == tb.output_active_value()


PARAMETER_SWEEP = [
    parameter_case(
        "sync_baseline",
        RST_ASYNC_G="false",
        IN_POLARITY_G="'1'",
        OUT_POLARITY_G="'1'",
        DURATION_G="4",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "async_counter_reset",
        RST_ASYNC_G="true",
        IN_POLARITY_G="'1'",
        OUT_POLARITY_G="'1'",
        DURATION_G="3",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "active_low_reset",
        RST_ASYNC_G="false",
        IN_POLARITY_G="'0'",
        OUT_POLARITY_G="'0'",
        DURATION_G="2",
        CLK_PERIOD_NS="5",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_PwrUpRst(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.pwruprst",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
