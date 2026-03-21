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


def _active_run_lengths(samples: list[int], active_value: int) -> list[int]:
    runs: list[int] = []
    current = 0
    for sample in samples:
        if sample == active_value:
            current += 1
        elif current:
            runs.append(current)
            current = 0
    if current:
        runs.append(current)
    return runs


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.rst_polarity = env_sl("RST_POLARITY_G", default=1)
        self.in_polarity = env_sl("IN_POLARITY_G", default=1)
        self.out_polarity = env_sl("OUT_POLARITY_G", default=1)
        self.async_reset = env_flag("RST_ASYNC_G", default=False)
        self.pulse_bit_width = int(os.environ["PULSE_BIT_WIDTH_G"])
        self.pulse_width = int(os.environ["PULSE_WIDTH_VALUE"])
        self.clk_period_ns = float(os.environ["CLK_PERIOD_NS"])

        dut.rst.value = self.reset_active_value()
        dut.trigIn.value = self.input_inactive_value()
        dut.pulseWidth.value = self.pulse_width

        cocotb.start_soon(Clock(dut.clk, self.clk_period_ns, unit="ns").start())

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

    def output_inactive_value(self) -> int:
        return 1 - self.out_polarity

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
        await self.cycle(3)
        self.dut.rst.value = self.reset_inactive_value()
        await self.cycle(1)

    async def sample_output(self, cycles: int) -> list[int]:
        samples: list[int] = []
        for _ in range(cycles):
            await self.cycle(1)
            samples.append(int(self.dut.pulseOut.value))
        return samples


@cocotb.test()
async def pulse_width_test(dut):
    tb = TB(dut)
    await tb.reset()

    tb.dut.trigIn.value = tb.input_active_value()
    samples = await tb.sample_output(tb.pulse_width + 4)
    tb.dut.trigIn.value = tb.input_inactive_value()
    samples.extend(await tb.sample_output(4))

    assert _active_run_lengths(samples, tb.output_active_value()) == [tb.pulse_width + 1]


@cocotb.test()
async def retrigger_wait_state_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Holding the trigger active after the pulse expires should keep the DUT in
    # its wait state instead of emitting a second pulse immediately.
    tb.dut.trigIn.value = tb.input_active_value()
    samples = await tb.sample_output(tb.pulse_width + 6)
    tb.dut.trigIn.value = tb.input_inactive_value()
    samples.extend(await tb.sample_output(4))

    assert _active_run_lengths(samples, tb.output_active_value()) == [tb.pulse_width + 1]


@cocotb.test()
async def reset_behavior_test(dut):
    tb = TB(dut)
    await tb.reset()

    tb.dut.trigIn.value = tb.input_active_value()
    await tb.cycle(2)

    await FallingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.rst.value = tb.reset_active_value()
    await tb.settle()

    if tb.async_reset:
        assert int(dut.pulseOut.value) == tb.output_inactive_value()
    else:
        await tb.cycle(1)
        assert int(dut.pulseOut.value) == tb.output_inactive_value()


PARAMETER_SWEEP = [
    parameter_case(
        "active_high_sync",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        IN_POLARITY_G="'1'",
        OUT_POLARITY_G="'1'",
        PULSE_BIT_WIDTH_G="4",
        PULSE_WIDTH_VALUE="2",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "active_low_output",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        IN_POLARITY_G="'1'",
        OUT_POLARITY_G="'0'",
        PULSE_BIT_WIDTH_G="4",
        PULSE_WIDTH_VALUE="1",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "async_active_low_input",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'0'",
        IN_POLARITY_G="'0'",
        OUT_POLARITY_G="'1'",
        PULSE_BIT_WIDTH_G="4",
        PULSE_WIDTH_VALUE="3",
        CLK_PERIOD_NS="7",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_OneShot(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.oneshot",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
