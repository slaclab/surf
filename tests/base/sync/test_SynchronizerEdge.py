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
        self.rst_polarity = env_sl("RST_POLARITY_G", default=1)
        self.out_polarity = env_sl("OUT_POLARITY_G", default=1)
        self.async_reset = env_flag("RST_ASYNC_G", default=False)
        self.bypass_sync = env_flag("BYPASS_SYNC_G", default=False)
        self.stages = int(os.environ["STAGES_G"])
        self.clk_period_ns = float(os.environ["CLK_PERIOD_NS"])

        dut.rst.value = self.reset_active_value()
        dut.dataIn.value = 0

        cocotb.start_soon(Clock(dut.clk, self.clk_period_ns, unit="ns").start())

    def reset_active_value(self) -> int:
        return self.rst_polarity

    def reset_inactive_value(self) -> int:
        return 1 - self.rst_polarity

    def pulse_active_value(self) -> int:
        return self.out_polarity

    def pulse_inactive_value(self) -> int:
        return 1 - self.out_polarity

    def expected_latency(self) -> int:
        # Bypass mode removes the multi-stage synchronizer and leaves only the
        # edge-detection register stage. Normal mode adds the configured sync
        # chain in front of that edge detector.
        return 1 if self.bypass_sync else self.stages

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


@cocotb.test()
async def edge_detection_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Drive the input high and wait until the synchronized path should expose
    # that transition at the outputs.
    dut.dataIn.value = 1
    for _ in range(tb.expected_latency() - 1):
        await tb.cycle(1)
        assert int(dut.dataOut.value) == tb.pulse_inactive_value()
        assert int(dut.risingEdge.value) == tb.pulse_inactive_value()
        assert int(dut.fallingEdge.value) == tb.pulse_inactive_value()

    await tb.cycle(1)
    assert int(dut.dataOut.value) == tb.pulse_active_value()
    assert int(dut.risingEdge.value) == tb.pulse_active_value()
    assert int(dut.fallingEdge.value) == tb.pulse_inactive_value()

    # Edge strobes are one-cycle pulses, so only the synchronized data level
    # should remain active on the following cycle.
    await tb.cycle(1)
    assert int(dut.dataOut.value) == tb.pulse_active_value()
    assert int(dut.risingEdge.value) == tb.pulse_inactive_value()

    # Now drive the input back low and check the falling-edge pulse.
    dut.dataIn.value = 0
    for _ in range(tb.expected_latency() - 1):
        await tb.cycle(1)
        assert int(dut.fallingEdge.value) == tb.pulse_inactive_value()

    await tb.cycle(1)
    assert int(dut.dataOut.value) == tb.pulse_inactive_value()
    assert int(dut.risingEdge.value) == tb.pulse_inactive_value()
    assert int(dut.fallingEdge.value) == tb.pulse_active_value()


@cocotb.test()
async def reset_behavior_test(dut):
    tb = TB(dut)
    await tb.reset()

    dut.dataIn.value = 1
    await tb.cycle(tb.expected_latency() + 1)
    assert int(dut.dataOut.value) == tb.pulse_active_value()

    # Assert reset between clock edges to distinguish synchronous and
    # asynchronous reset operation.
    await FallingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.rst.value = tb.reset_active_value()
    await tb.settle()

    if tb.async_reset:
        assert int(dut.dataOut.value) == tb.pulse_inactive_value()
    else:
        assert int(dut.dataOut.value) == tb.pulse_active_value()
        await tb.cycle(1)
        assert int(dut.dataOut.value) == tb.pulse_inactive_value()


PARAMETER_SWEEP = [
    parameter_case(
        "stage3_baseline",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        OUT_POLARITY_G="'1'",
        BYPASS_SYNC_G="false",
        STAGES_G="3",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "stage4_async_reset",
        RST_ASYNC_G="true",
        RST_POLARITY_G="'1'",
        OUT_POLARITY_G="'1'",
        BYPASS_SYNC_G="false",
        STAGES_G="4",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "active_low_output",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        OUT_POLARITY_G="'0'",
        BYPASS_SYNC_G="false",
        STAGES_G="3",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "bypass_sync",
        RST_ASYNC_G="false",
        RST_POLARITY_G="'1'",
        OUT_POLARITY_G="'1'",
        BYPASS_SYNC_G="true",
        STAGES_G="3",
        CLK_PERIOD_NS="5",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_SynchronizerEdge(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.synchronizeredge",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )

