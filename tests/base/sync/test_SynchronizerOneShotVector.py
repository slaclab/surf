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


def _active_run_lengths(samples: list[int]) -> list[int]:
    lengths: list[int] = []
    current = 0
    for sample in samples:
        if sample:
            current += 1
        elif current:
            lengths.append(current)
            current = 0
    if current:
        lengths.append(current)
    return lengths


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.width = int(os.environ["WIDTH_G"])
        self.pulse_width = int(os.environ["PULSE_WIDTH_G"])
        self.rst_polarity = env_sl("RST_POLARITY_G", default=1)
        self.in_polarity = env_sl("IN_POLARITY_G", default=1)
        self.out_polarity = env_sl("OUT_POLARITY_G", default=1)
        self.async_reset = env_flag("RST_ASYNC_G", default=False)
        self.clk_period_ns = float(os.environ["CLK_PERIOD_NS"])

        dut.rst.value = self.reset_active_value()
        dut.dataIn.value = self.input_inactive_mask()

        # The vector wrapper shares one destination clock across all lanes, so
        # start it once here and let the tests reason in clock cycles.
        cocotb.start_soon(Clock(dut.clk, self.clk_period_ns, unit="ns").start())

    def reset_active_value(self) -> int:
        return self.rst_polarity

    def reset_inactive_value(self) -> int:
        return 1 - self.rst_polarity

    def input_active_mask(self, mask: int) -> int:
        return mask if self.in_polarity else 0

    def input_inactive_mask(self) -> int:
        return 0 if self.in_polarity else (1 << self.width) - 1

    def output_active_value(self) -> int:
        return self.out_polarity

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

    async def pulse_bits(self, mask: int) -> None:
        # Hold the selected source bits active for two cycles so the pulse is
        # visible in both bypassed and synchronized configurations.
        self.dut.dataIn.value = self.input_active_mask(mask)
        await self.cycle(2)
        self.dut.dataIn.value = self.input_inactive_mask()

    async def sample_output(self, cycles: int) -> list[int]:
        samples: list[int] = []
        for _ in range(cycles):
            await self.cycle(1)
            samples.append(int(self.dut.dataOut.value))
        return samples


@cocotb.test()
async def vector_pulse_width_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Start with a single active lane so this test can focus on pulse width for
    # one generated instance. Lane-to-lane isolation is checked separately in
    # `sequential_lane_independence_test`.
    active_mask = 0b001
    tb.dut.dataIn.value = tb.input_active_mask(active_mask)
    samples = await tb.sample_output(2)
    tb.dut.dataIn.value = tb.input_inactive_mask()
    samples.extend(await tb.sample_output(12))

    lane0_samples = [((sample >> 0) & 1) == tb.output_active_value() for sample in samples]
    assert _active_run_lengths(lane0_samples) == [tb.pulse_width]


@cocotb.test()
async def sequential_lane_independence_test(dut):
    tb = TB(dut)
    await tb.reset()

    samples = await tb.sample_output(2)
    # Sample through each pulse while it is being driven so the async/bypass
    # configuration cannot hide the leading active cycles inside a helper call.
    tb.dut.dataIn.value = tb.input_active_mask(0b001)
    samples.extend(await tb.sample_output(2))
    tb.dut.dataIn.value = tb.input_inactive_mask()
    samples.extend(await tb.sample_output(8))

    tb.dut.dataIn.value = tb.input_active_mask(0b010)
    samples.extend(await tb.sample_output(2))
    tb.dut.dataIn.value = tb.input_inactive_mask()
    samples.extend(await tb.sample_output(8))

    # Two different lane strobes should create two independent one-shot pulses
    # instead of coupling all bits together inside the vector wrapper.
    lane0 = [((sample >> 0) & 1) == tb.output_active_value() for sample in samples]
    lane1 = [((sample >> 1) & 1) == tb.output_active_value() for sample in samples]
    lane2 = [((sample >> 2) & 1) == tb.output_active_value() for sample in samples]
    assert _active_run_lengths(lane0) == [tb.pulse_width]
    assert _active_run_lengths(lane1) == [tb.pulse_width]
    assert _active_run_lengths(lane2) == []


@cocotb.test()
async def reset_behavior_test(dut):
    tb = TB(dut)
    await tb.reset()
    await tb.pulse_bits(0b001)

    observed_active = False
    for _ in range(10):
        await tb.cycle(1)
        if ((int(dut.dataOut.value) >> 0) & 1) == tb.output_active_value():
            observed_active = True
            break

    assert observed_active

    # Reset while one of the vector lanes is still producing its pulse so the
    # test proves the wrapper clears every generated instance together.
    await FallingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.rst.value = tb.reset_active_value()
    await tb.settle()

    if tb.async_reset:
        assert int(dut.dataOut.value) == tb.input_inactive_mask()
    else:
        await tb.cycle(1)
        assert int(dut.dataOut.value) == tb.input_inactive_mask()


PARAMETER_SWEEP = [
    parameter_case(
        "baseline",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        BYPASS_SYNC_G="false",
        PULSE_WIDTH_G="2",
        WIDTH_G="3",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "bypass_async_reset",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'1'",
        BYPASS_SYNC_G="true",
        PULSE_WIDTH_G="3",
        WIDTH_G="3",
        CLK_PERIOD_NS="7",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_SynchronizerOneShotVector(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.synchronizeroneshotvector",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
