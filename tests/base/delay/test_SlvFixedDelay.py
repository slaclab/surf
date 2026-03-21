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
    hdl_parameters_from,
    parameter_case,
    run_surf_vhdl_test,
)


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.width = int(os.environ["WIDTH_G"])
        self.delay = int(os.environ["DELAY_G"])
        self.clk_period_ns = float(os.environ["CLK_PERIOD_NS"])

        dut.din.value = 0
        cocotb.start_soon(Clock(dut.clk, self.clk_period_ns, unit="ns").start())

    async def settle(self) -> None:
        await Timer(2, unit="ns")

    async def push(self, value: int) -> int:
        self.dut.din.value = value
        await RisingEdge(self.dut.clk)
        await self.settle()
        return int(self.dut.dout.value)


@cocotb.test()
async def fixed_latency_test(dut):
    tb = TB(dut)
    for _ in range(tb.delay + 2):
        assert await tb.push(0) == 0

    # Once the line is filled with a constant value, the delayed output should
    # eventually converge to that same value and remain there.
    for _ in range(tb.delay + 2):
        await tb.push(0x5A)
    for _ in range(3):
        assert await tb.push(0x5A) == 0x5A


@cocotb.test()
async def ordering_test(dut):
    tb = TB(dut)
    # A second burst of constant data should eventually replace the first one
    # after the same fixed latency rather than getting stuck on stale samples.
    for _ in range(tb.delay + 3):
        await tb.push(0x11)
    for _ in range(3):
        assert await tb.push(0x11) == 0x11

    for _ in range(tb.delay + 3):
        await tb.push(0x22)
    for _ in range(3):
        assert await tb.push(0x22) == 0x22


PARAMETER_SWEEP = [
    parameter_case(
        "delay4",
        DELAY_STYLE_G="block",
        DELAY_G="4",
        WIDTH_G="8",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "delay6",
        DELAY_STYLE_G="block",
        DELAY_G="6",
        WIDTH_G="8",
        CLK_PERIOD_NS="7",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_SlvFixedDelay(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.slvfixeddelay",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
