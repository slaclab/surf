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
# - Sweep: Sweep a synchronized single-pulse case, a bypass stretched-pulse
#   case, an active-low output case, and an asynchronous-reset active-low input
#   case.
# - Stimulus: Issue one trigger pulse, hold or re-drive the input around it,
#   and then assert reset so the one-shot state is exercised from idle and from
#   active conditions.
# - Checks: The destination pulse width must match the configured one-shot
#   length, output polarity must match configuration, bypass must remove the
#   normal CDC latency, and reset must clear the pulse state.
# - Timing: The bench checks the pulse start after synchronizer latency in the
#   normal path and counts the number of destination cycles that the one-shot
#   output remains asserted.

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
    lengths: list[int] = []
    current = 0
    for sample in samples:
        if sample == active_value:
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
        self.rst_polarity = env_sl("RST_POLARITY_G", default=1)
        self.in_polarity = env_sl("IN_POLARITY_G", default=1)
        self.out_polarity = env_sl("OUT_POLARITY_G", default=1)
        self.async_reset = env_flag("RST_ASYNC_G", default=False)
        self.bypass_sync = env_flag("BYPASS_SYNC_G", default=False)
        self.pulse_width = int(os.environ["PULSE_WIDTH_G"])
        self.clk_period_ns = float(os.environ["CLK_PERIOD_NS"])

        dut.rst.value = self.reset_active_value()
        dut.dataIn.value = self.input_inactive_value()

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

    async def trigger_input(self) -> None:
        # Holding the trigger active for two cycles makes the crossing easy to
        # observe in both bypassed and synchronized configurations.
        self.dut.dataIn.value = self.input_active_value()
        await self.cycle(2)
        self.dut.dataIn.value = self.input_inactive_value()

    async def sample_output(self, cycles: int) -> list[int]:
        samples: list[int] = []
        for _ in range(cycles):
            await self.cycle(1)
            samples.append(int(self.dut.dataOut.value))
        return samples


@cocotb.test()
async def pulse_width_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Start sampling before the trigger is released so short pulses are not
    # missed simply because the observation window started too late.
    tb.dut.dataIn.value = tb.input_active_value()
    samples = await tb.sample_output(2)
    tb.dut.dataIn.value = tb.input_inactive_value()
    samples.extend(await tb.sample_output(12))
    runs = _active_run_lengths(samples, tb.output_active_value())

    # The output should contain exactly one pulse, and that pulse should be the
    # configured width in destination-clock cycles.
    assert runs == [tb.pulse_width]


@cocotb.test()
async def reset_behavior_test(dut):
    tb = TB(dut)
    await tb.reset()
    await tb.trigger_input()

    # Give the design time to start producing the output pulse before reset is
    # asserted.
    observed_active = False
    for _ in range(10):
        await tb.cycle(1)
        if int(dut.dataOut.value) == tb.output_active_value():
            observed_active = True
            break

    assert observed_active

    await FallingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.rst.value = tb.reset_active_value()
    await tb.settle()

    if tb.async_reset:
        assert int(dut.dataOut.value) == tb.output_inactive_value()
    else:
        assert int(dut.dataOut.value) == tb.output_active_value()
        await tb.cycle(1)
        assert int(dut.dataOut.value) == tb.output_inactive_value()


PARAMETER_SWEEP = [
    parameter_case(
        "sync_single_pulse",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        BYPASS_SYNC_G="false",
        IN_POLARITY_G="'1'",
        OUT_POLARITY_G="'1'",
        OUT_DELAY_G="3",
        PULSE_WIDTH_G="1",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "bypass_stretched_pulse",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        BYPASS_SYNC_G="true",
        IN_POLARITY_G="'1'",
        OUT_POLARITY_G="'1'",
        OUT_DELAY_G="3",
        PULSE_WIDTH_G="3",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "active_low_output",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        BYPASS_SYNC_G="false",
        IN_POLARITY_G="'1'",
        OUT_POLARITY_G="'0'",
        OUT_DELAY_G="3",
        PULSE_WIDTH_G="1",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "async_reset_active_low_input",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'0'",
        BYPASS_SYNC_G="true",
        IN_POLARITY_G="'0'",
        OUT_POLARITY_G="'1'",
        OUT_DELAY_G="3",
        PULSE_WIDTH_G="2",
        CLK_PERIOD_NS="5",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_SynchronizerOneShot(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.synchronizeroneshot",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
