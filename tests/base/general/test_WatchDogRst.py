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
        self.duration = int(os.environ["DURATION_G"])
        self.clk_period_ns = float(os.environ["CLK_PERIOD_NS"])

        # Keep the monitor input in its non-timeout state at startup so the
        # tests can decide explicitly when the watchdog should begin counting.
        dut.monIn.value = self.input_active_value()
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
async def timeout_pulse_test(dut):
    tb = TB(dut)
    await tb.cycle(4)

    # Keeping the monitor input inactive long enough should trigger a single
    # reset pulse and then automatically clear again on the following cycle.
    dut.monIn.value = tb.input_inactive_value()
    await tb.cycle(tb.duration + 3)
    assert int(dut.rstOut.value) == tb.output_active_value()
    await tb.cycle(1)
    assert int(dut.rstOut.value) == tb.output_inactive_value()


@cocotb.test()
async def keepalive_prevents_timeout_test(dut):
    tb = TB(dut)
    await tb.cycle(4)

    # A short inactive window should start the watchdog timer, but reasserting
    # the keepalive input before the duration expires must cancel the timeout.
    dut.monIn.value = tb.input_inactive_value()
    await tb.cycle(max(tb.duration - 1, 1))
    dut.monIn.value = tb.input_active_value()
    await tb.cycle(3)
    assert int(dut.rstOut.value) == tb.output_inactive_value()


PARAMETER_SWEEP = [
    parameter_case(
        "active_high_baseline",
        IN_POLARITY_G="'1'",
        OUT_POLARITY_G="'1'",
        DURATION_G="4",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "active_low_monitor",
        IN_POLARITY_G="'0'",
        OUT_POLARITY_G="'1'",
        DURATION_G="3",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "active_low_output",
        IN_POLARITY_G="'1'",
        OUT_POLARITY_G="'0'",
        DURATION_G="4",
        CLK_PERIOD_NS="7",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_WatchDogRst(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.watchdogrst",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
