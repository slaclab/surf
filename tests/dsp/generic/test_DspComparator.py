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


def _sample_values(width: int) -> list[int]:
    max_value = (1 << width) - 1
    candidates = {
        0,
        1,
        2,
        max_value // 2,
        max(0, (max_value // 2) - 1),
        max(0, max_value - 2),
        max_value - 1,
        max_value,
    }
    return sorted(value for value in candidates if 0 <= value <= max_value)


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.width = int(os.environ["WIDTH_G"])
        self.async_reset = env_flag("RST_ASYNC_G", default=False)
        self.rst_polarity = env_sl("RST_POLARITY_G", default=1)
        self.clk_period_ns = float(os.environ["CLK_PERIOD_NS"])

        dut.rst.value = self.reset_active_value()
        dut.ibValid.value = 0
        dut.ain.value = 0
        dut.bin.value = 0
        dut.obReady.value = 1

        # Start the shared processing clock before any handshake activity so
        # the helper methods can talk in terms of whole compare transactions.
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
        # Hold reset long enough for both the subtract/compare stage and the
        # optional output pipeline stage to come up from a known state.
        self.dut.rst.value = self.reset_active_value()
        if self.async_reset:
            await Timer(2, unit="ns")
        await self.cycle(3)
        self.dut.rst.value = self.reset_inactive_value()
        await self.cycle(2)

    async def submit(self, ain: int, bin: int) -> None:
        # Present one compare request for exactly one clock edge. The tests only
        # submit new work after the prior result has drained, so one-cycle valid
        # pulses are enough to exercise the input handshake.
        self.dut.ain.value = ain
        self.dut.bin.value = bin
        self.dut.ibValid.value = 1
        await self.cycle(1)
        self.dut.ibValid.value = 0

    async def wait_for_result(self) -> None:
        while int(self.dut.obValid.value) == 0:
            await self.cycle(1)

    def check_result(self, ain: int, bin: int) -> None:
        assert int(self.dut.aout.value) == ain
        assert int(self.dut.bout.value) == bin
        assert int(self.dut.eq.value) == int(ain == bin)
        assert int(self.dut.gt.value) == int(ain > bin)
        assert int(self.dut.gtEq.value) == int(ain >= bin)
        assert int(self.dut.ls.value) == int(ain < bin)
        assert int(self.dut.lsEq.value) == int(ain <= bin)


@cocotb.test()
async def comparison_truth_table_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Sweep a curated set of low, middle, and high values so the comparator is
    # checked around equality, sign, and carry-boundary cases without turning
    # the test into a huge Cartesian runtime spike for wider configurations.
    for ain in _sample_values(tb.width):
        for bin in _sample_values(tb.width):
            await tb.submit(ain, bin)
            await tb.wait_for_result()
            tb.check_result(ain, bin)
            await tb.cycle(1)


@cocotb.test()
async def backpressure_hold_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Hold obReady low after the comparison is submitted so the result has to
    # sit on the output interface instead of draining immediately.
    tb.dut.obReady.value = 0
    await tb.submit(0x12 & ((1 << tb.width) - 1), 0x03 & ((1 << tb.width) - 1))
    await tb.wait_for_result()

    held = (
        int(dut.aout.value),
        int(dut.bout.value),
        int(dut.eq.value),
        int(dut.gt.value),
        int(dut.gtEq.value),
        int(dut.ls.value),
        int(dut.lsEq.value),
    )

    # While the downstream side is stalled, every result bit should remain
    # stable rather than bubbling to an idle value.
    await tb.cycle(2)
    assert int(dut.obValid.value) == 1
    assert held == (
        int(dut.aout.value),
        int(dut.bout.value),
        int(dut.eq.value),
        int(dut.gt.value),
        int(dut.gtEq.value),
        int(dut.ls.value),
        int(dut.lsEq.value),
    )

    tb.dut.obReady.value = 1
    await tb.cycle(1)
    assert int(dut.obValid.value) == 0


@cocotb.test()
async def reset_behavior_test(dut):
    tb = TB(dut)
    await tb.reset()

    tb.dut.obReady.value = 0
    await tb.submit(3, 1)
    await tb.wait_for_result()

    # Assert reset while a valid comparison result is being held so the test
    # proves reset clears pending output state instead of only clearing idle logic.
    await FallingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.rst.value = tb.reset_active_value()
    await tb.settle()

    if tb.async_reset:
        assert int(dut.obValid.value) == 0
    else:
        await tb.cycle(1)
        assert int(dut.obValid.value) == 0


PARAMETER_SWEEP = [
    parameter_case(
        "baseline",
        RST_POLARITY_G="'1'",
        RST_ASYNC_G="false",
        PIPE_STAGES_G="0",
        WIDTH_G="4",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "pipelined_active_low_reset",
        RST_POLARITY_G="'0'",
        RST_ASYNC_G="true",
        PIPE_STAGES_G="1",
        WIDTH_G="8",
        CLK_PERIOD_NS="7",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_DspComparator(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.dspcomparator",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )

