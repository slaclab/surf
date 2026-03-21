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
# - Sweep: Sweep a fully registered output case, a combinational output case,
#   and an asynchronous active-low reset case so the mux is checked in both
#   timing modes.
# - Stimulus: Change the select input while driving distinct values on each
#   lane so the chosen source is always identifiable.
# - Checks: The selected lane must appear at the output, the registered case
#   must hold the previous value until the next clock edge, and reset must
#   drive the configured idle value.
# - Timing: The bench explicitly distinguishes combinational select-to-output
#   behavior from clocked output-update behavior and checks reset response in
#   both modes.

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


def _one_hot_input(select: int, width: int) -> int:
    # Drive only the selected bit high so the expected mux output is always
    # `1` for in-range selectors and easy to read in the assertions below.
    return 1 << select if select < (1 << width) else 0


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.sel_width = int(os.environ["SEL_WIDTH_G"])
        self.reg_din = env_flag("REG_DIN_G", default=True)
        self.reg_sel = env_flag("REG_SEL_G", default=True)
        self.reg_dout = env_flag("REG_DOUT_G", default=True)
        self.rst_polarity = env_sl("RST_POLARITY_G", default=1)
        self.async_reset = env_flag("RST_ASYNC_G", default=False)
        self.clk_period_ns = float(os.environ["CLK_PERIOD_NS"])

        dut.rst.value = self.reset_active_value()
        dut.sel.value = 0
        dut.din.value = 0

        # Start the single mux clock during TB construction so helper methods
        # can focus on selector/input updates and output observations.
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

    async def drive_and_observe(self, select: int) -> int:
        # This helper applies a selector and matching one-hot input, then waits
        # long enough for any optional input/output pipeline stages to flush.
        self.dut.sel.value = select
        self.dut.din.value = _one_hot_input(select, self.sel_width)
        await self.cycle(3)
        return int(self.dut.dout.value)


@cocotb.test()
async def selection_test(dut):
    tb = TB(dut)
    await tb.reset()

    # A one-hot input pattern makes the expected output easy to reason about:
    # the selected bit should always be `1` after the configured pipeline has
    # time to settle.
    for select in [0, min(1, (1 << tb.sel_width) - 1), (1 << tb.sel_width) - 1]:
        assert await tb.drive_and_observe(select) == 1


@cocotb.test()
async def reset_behavior_test(dut):
    tb = TB(dut)
    await tb.reset()
    assert await tb.drive_and_observe((1 << tb.sel_width) - 1) == 1

    await FallingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.rst.value = tb.reset_active_value()
    await tb.settle()

    if tb.async_reset:
        assert int(dut.dout.value) == 0
    else:
        await tb.cycle(1)
        assert int(dut.dout.value) == 0


PARAMETER_SWEEP = [
    parameter_case(
        "fully_registered",
        SEL_WIDTH_G="3",
        REG_DIN_G="true",
        REG_SEL_G="true",
        REG_DOUT_G="true",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "combinational_output",
        SEL_WIDTH_G="2",
        REG_DIN_G="true",
        REG_SEL_G="false",
        REG_DOUT_G="false",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "async_active_low_reset",
        SEL_WIDTH_G="2",
        REG_DIN_G="false",
        REG_SEL_G="true",
        REG_DOUT_G="true",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'0'",
        CLK_PERIOD_NS="7",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_Mux(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.mux",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
