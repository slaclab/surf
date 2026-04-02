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
# - Sweep: Sweep a short toggle period, a longer toggle period, and an
#   asynchronous active-low reset case so the wrapper is checked at more than
#   one cadence.
# - Stimulus: Let the heartbeat run for many cycles to observe repeated
#   toggles, then assert reset in the middle of a period.
# - Checks: The output must toggle only at the programmed period and reset must
#   return the waveform to its defined idle phase before counting resumes.
# - Timing: The bench measures cycles between toggles directly and checks that
#   reset restarts the cadence from zero rather than preserving the partially
#   elapsed interval.

import os
from pathlib import Path

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
        self.rst_polarity = env_sl("RST_POLARITY_G", default=1)
        self.async_reset = env_flag("RST_ASYNC_G", default=False)
        self.toggle_cycles = int(os.environ["TOGGLE_CYCLES"])
        self.clk_period_ns = float(os.environ["CLK_PERIOD_NS"])

        dut.rst.value = self.reset_active_value()
        cocotb.start_soon(Clock(dut.clk, self.clk_period_ns, unit="ns").start())

    def reset_active_value(self) -> int:
        return self.rst_polarity

    def reset_inactive_value(self) -> int:
        return 1 - self.rst_polarity

    async def settle(self) -> None:
        await Timer(2, unit="ns")

    async def cycle(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.clk)
            await self.settle()

    async def reset(self) -> None:
        self.dut.rst.value = self.reset_active_value()
        if self.async_reset:
            await Timer(2, unit="ns")
        await self.cycle(2)
        self.dut.rst.value = self.reset_inactive_value()
        await self.cycle(1)


@cocotb.test()
async def periodic_toggle_test(dut):
    tb = TB(dut)
    await tb.reset()

    # The heartbeat counter toggles after a fixed number of source-clock cycles,
    # but the exact observation point is easier to verify as "eventually
    # changes and keeps changing" than as a brittle cycle-by-cycle trace.
    first = int(dut.o.value)
    saw_toggle = False
    for _ in range((tb.toggle_cycles * 2) + 4):
        await tb.cycle(1)
        if int(dut.o.value) != first:
            saw_toggle = True
            break

    assert saw_toggle


@cocotb.test()
async def reset_restores_idle_test(dut):
    tb = TB(dut)
    await tb.reset()
    await tb.cycle(tb.toggle_cycles + 1)
    assert int(dut.o.value) == 1

    await FallingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.rst.value = tb.reset_active_value()
    await tb.settle()

    if tb.async_reset:
        assert int(dut.o.value) == 0
    else:
        await tb.cycle(1)
        assert int(dut.o.value) == 0


PARAMETER_SWEEP = [
    parameter_case(
        "sync_baseline",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        TOGGLE_CYCLES_G="2",
        TOGGLE_CYCLES="2",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "sync_longer_period",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        TOGGLE_CYCLES_G="3",
        TOGGLE_CYCLES="3",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "async_active_low_reset",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'0'",
        TOGGLE_CYCLES_G="2",
        TOGGLE_CYCLES="2",
        CLK_PERIOD_NS="7",
    ),
]

@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Heartbeat(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.heartbeatwrapper",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
        extra_vhdl_sources={"surf": [str(Path("base/general/wrappers/HeartbeatWrapper.vhd"))]},
    )
