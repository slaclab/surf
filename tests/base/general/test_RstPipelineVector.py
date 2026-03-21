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
    env_flag,
    hdl_parameters_from,
    parameter_case,
    run_surf_vhdl_test,
)


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.width = int(os.environ["WIDTH_G"])
        self.mask = (1 << self.width) - 1
        self.pipe_stages = int(os.environ["PIPE_STAGES_G"])
        self.invert_reset = env_flag("INV_RST_G", default=False)
        self.init_value = self.mask
        self.clk_period_ns = float(os.environ["CLK_PERIOD_NS"])
        self.pipeline = [self.init_value for _ in range(self.pipe_stages)]

        # Seed the vector input to the same value the DUT powers up with so the
        # software pipeline model and the RTL start from identical history.
        dut.rstIn.value = self.init_value
        cocotb.start_soon(Clock(dut.clk, self.clk_period_ns, unit="ns").start())

    def expected_output(self, rst_in: int) -> int:
        # INV_RST_G flips each bit before it enters the per-bit reset pipeline.
        return (~rst_in) & self.mask if self.invert_reset else rst_in

    async def settle(self) -> None:
        await Timer(2, unit="ns")

    async def cycle(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.clk)
            await self.settle()

    def sampled_input(self) -> int:
        # Sample the currently driven input in the same transformed polarity the
        # scalar RstPipeline instances see internally.
        return self.expected_output(int(self.dut.rstIn.value))

    async def cycle_and_check(self, count: int = 1) -> None:
        for _ in range(count):
            await self.cycle(1)
            # The vector wrapper is just a bank of independent RstPipeline
            # instances, so a simple software shift register mirrors the DUT.
            self.pipeline = [self.sampled_input()] + self.pipeline[:-1]
            assert int(self.dut.rstOut.value) == self.pipeline[-1]

    async def drive_and_expect_after_latency(self, value: int) -> None:
        self.dut.rstIn.value = value
        await self.settle()
        await self.cycle_and_check(self.pipe_stages)


@cocotb.test()
async def vector_pipeline_latency_test(dut):
    tb = TB(dut)
    # First let the model and DUT march forward together for a couple cycles,
    # then push distinct values through the whole pipeline latency.
    await tb.cycle_and_check(2)
    await tb.drive_and_expect_after_latency(0)
    await tb.drive_and_expect_after_latency(tb.mask)


@cocotb.test()
async def per_bit_independence_test(dut):
    tb = TB(dut)
    await tb.cycle_and_check(2)

    for value in [1, 1 << max(tb.width - 1, 0), (tb.mask ^ 0x3) & tb.mask]:
        await tb.drive_and_expect_after_latency(value)


PARAMETER_SWEEP = [
    parameter_case(
        "width4_stage2",
        WIDTH_G="4",
        PIPE_STAGES_G="2",
        INV_RST_G="false",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "width2_stage1",
        WIDTH_G="2",
        PIPE_STAGES_G="1",
        INV_RST_G="false",
        CLK_PERIOD_NS="7",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_RstPipelineVector(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.rstpipelinevector",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
