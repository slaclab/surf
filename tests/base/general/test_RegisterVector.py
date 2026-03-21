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
        self.width = int(os.environ["WIDTH_G"])
        self.mask = (1 << self.width) - 1
        self.init_value = 0
        self.async_reset = env_flag("RST_ASYNC_G", default=False)
        self.rst_polarity = env_sl("RST_POLARITY_G", default=1)
        self.clk_period_ns = float(os.environ["CLK_PERIOD_NS"])

        dut.rst.value = self.reset_active_value()
        dut.en.value = 0
        dut.sig_i.value = 0

        # Start the free-running source clock once during TB setup so each test
        # can focus on stimulus and checking rather than clock plumbing.
        cocotb.start_soon(Clock(dut.clk, self.clk_period_ns, unit="ns").start())

    def reset_active_value(self) -> int:
        return self.rst_polarity

    def reset_inactive_value(self) -> int:
        return 1 - self.rst_polarity

    async def settle(self) -> None:
        await Timer(2, unit="ns")

    async def cycle(self, count: int = 1) -> None:
        for _ in range(count):
            # Sample one full DUT cycle and then wait past TPD_G so assertions
            # see the registered output after it has settled.
            await RisingEdge(self.dut.clk)
            await self.settle()

    async def reset(self) -> None:
        # Drive reset exactly the way the DUT expects for the active-high and
        # active-low parameter cases, then give the register one clean cycle to
        # come out of reset before tests start applying traffic.
        self.dut.rst.value = self.reset_active_value()
        if self.async_reset:
            await Timer(2, unit="ns")
        await self.cycle(2)
        self.dut.rst.value = self.reset_inactive_value()
        await self.cycle(1)


@cocotb.test()
async def capture_and_hold_test(dut):
    tb = TB(dut)
    await tb.reset()
    assert int(dut.reg_o.value) == tb.init_value

    # With `en=1`, the DUT should capture the input and present it one clock
    # later because the output is driven from the registered state.
    dut.en.value = 1
    dut.sig_i.value = 0x5A & tb.mask
    await tb.cycle(1)
    assert int(dut.reg_o.value) == (0x5A & tb.mask)

    # Dropping `en` should freeze the previous registered value even when the
    # input changes underneath it.
    dut.en.value = 0
    dut.sig_i.value = 0xC3 & tb.mask
    await tb.cycle(2)
    assert int(dut.reg_o.value) == (0x5A & tb.mask)


@cocotb.test()
async def reset_behavior_test(dut):
    tb = TB(dut)
    await tb.reset()

    # First prove the register captured a non-zero value so the reset check is
    # actually observing a state change instead of a trivial all-zero case.
    dut.en.value = 1
    dut.sig_i.value = 0xA5 & tb.mask
    await tb.cycle(1)
    assert int(dut.reg_o.value) == (0xA5 & tb.mask)

    await FallingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.rst.value = tb.reset_active_value()
    await tb.settle()

    if tb.async_reset:
        assert int(dut.reg_o.value) == tb.init_value
    else:
        assert int(dut.reg_o.value) == (0xA5 & tb.mask)
        await tb.cycle(1)
        assert int(dut.reg_o.value) == tb.init_value


PARAMETER_SWEEP = [
    parameter_case(
        "baseline_sync",
        WIDTH_G="8",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "init_pattern_sync",
        WIDTH_G="8",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "async_active_low_reset",
        WIDTH_G="4",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'0'",
        CLK_PERIOD_NS="7",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_RegisterVector(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.registervector",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
