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
# - Sweep: Sweep one-stage and four-stage pipelines plus inverted-input/output
#   variants so both latency depth and polarity handling are covered.
# - Stimulus: Toggle the reset input repeatedly and with short spacing so the
#   pipeline has to propagate multiple events without collapsing state.
# - Checks: The output reset must emerge after the configured number of stages
#   and respect the inversion settings in each case.
# - Timing: The test counts stage latency exactly and confirms that successive
#   toggles move through the pipeline in order rather than skipping or merging
#   cycles.

import os

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

from tests.common.regression_utils import (
    env_flag,
    hdl_parameters_from,
    parameter_case,
    run_surf_vhdl_test,
)


class TB:
    def __init__(self, dut):
        self.dut = dut
        # Pull the selected pytest case values back out of the environment so
        # the cocotb testbench can compute matching expectations.
        self.clk_period_ns = float(os.environ["CLK_PERIOD_NS"])
        self.pipe_stages = int(os.environ["PIPE_STAGES_G"])
        self.invert_reset = env_flag("INV_RST_G", default=False)

        # Start `rstIn` at the value that should already be visible on `rstOut`
        # after initialization, so the first transition is easy to reason about.
        dut.rstIn.value = 1 if not self.invert_reset else 0

        # Launch a free-running HDL clock in the background.
        cocotb.start_soon(Clock(dut.clk, self.clk_period_ns, unit="ns").start())

    async def settle(self) -> None:
        # Wait past `TPD_G` before checking outputs.
        await Timer(2, unit="ns")

    async def cycle(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.clk)
            await self.settle()

    def expected_output(self, rst_in: int) -> int:
        return rst_in if not self.invert_reset else 1 - rst_in

    async def drive_and_expect_after_latency(self, rst_in: int) -> None:
        # Remember the previous output so the test can prove the pipeline has
        # not updated too early.
        previous_output = int(self.dut.rstOut.value)
        self.dut.rstIn.value = rst_in
        await self.settle()

        # Intermediate stages should keep showing the old value.
        for _ in range(self.pipe_stages - 1):
            await RisingEdge(self.dut.clk)
            await self.settle()
            assert int(self.dut.rstOut.value) == previous_output

        # After the full configured latency, the new value should appear.
        await RisingEdge(self.dut.clk)
        await self.settle()
        assert int(self.dut.rstOut.value) == self.expected_output(rst_in)


@cocotb.test()
async def pipeline_latency_test(dut):
    tb = TB(dut)
    # Give the generated clock a couple cycles before starting assertions.
    await tb.cycle(2)

    initial_input = int(dut.rstIn.value)
    assert int(dut.rstOut.value) == tb.expected_output(initial_input)

    # Toggle away from the initial value and then back again.
    await tb.drive_and_expect_after_latency(1 - initial_input)
    await tb.drive_and_expect_after_latency(initial_input)


@cocotb.test()
async def repeated_toggle_test(dut):
    tb = TB(dut)
    await tb.cycle(2)

    # Run several transitions in a row to make sure the pipeline does not only
    # work for a single isolated toggle.
    values = [1 - int(dut.rstIn.value), int(dut.rstIn.value), 1 - int(dut.rstIn.value)]
    for value in values:
        await tb.drive_and_expect_after_latency(value)


PARAMETER_SWEEP = [
    parameter_case(
        "stage1_baseline",
        PIPE_STAGES_G="1",
        INV_RST_G="false",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "stage4_baseline",
        PIPE_STAGES_G="4",
        INV_RST_G="false",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "stage3_inverted",
        PIPE_STAGES_G="3",
        INV_RST_G="true",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "stage2_inverted",
        PIPE_STAGES_G="2",
        INV_RST_G="true",
        CLK_PERIOD_NS="7",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_RstPipeline(parameters):
    # Split HDL generics from runtime-only values in the standard project way.
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.rstpipeline",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
