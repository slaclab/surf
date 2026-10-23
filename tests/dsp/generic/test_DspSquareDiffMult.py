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
# - Sweep: Cover one direct-output case and one pipelined active-low reset
#   case so both reset styles and output paths are exercised.
# - Stimulus: Drive signed input pairs through the square-of-difference path,
#   then stall the sink so one squared result must remain parked.
# - Checks: The output must equal `(a-b)^2` with the DUT's signed difference
#   width, held output data must remain stable while backpressured, and reset
#   must clear a pending result.
# - Timing: The test waits on `obValid` and then samples several extra cycles
#   during stall so the bench proves state retention rather than one-edge
#   coincidence.

import os

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import FallingEdge, Timer

from tests.common.regression_utils import sample_after_tpd

from tests.common.regression_utils import env_flag, env_sl, hdl_parameters_from, parameter_case, run_surf_vhdl_test
from tests.dsp.generic.dsp_test_utils import signed_samples, to_unsigned, truncate_signed


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.width = int(os.environ["WIDTH_G"])
        self.out_width = 2 * self.width + 2
        self.async_reset = env_flag("RST_ASYNC_G", default=False)
        self.rst_polarity = env_sl("RST_POLARITY_G", default=1)

        cocotb.start_soon(Clock(dut.clk, 5.0, unit="ns").start())
        dut.rst.value = self.reset_active_value()
        dut.ibValid.value = 0
        dut.ain.value = 0
        dut.bin.value = 0
        dut.obReady.value = 1

    def reset_active_value(self) -> int:
        return self.rst_polarity

    def reset_inactive_value(self) -> int:
        return 1 - self.rst_polarity

    async def cycle(self, count=1):
        for _ in range(count):
            await sample_after_tpd(self.dut.clk)

    async def reset(self):
        self.dut.rst.value = self.reset_active_value()
        if self.async_reset:
            await Timer(1, unit="ns")
        await self.cycle(3)
        self.dut.rst.value = self.reset_inactive_value()
        await self.cycle(2)

    async def submit(self, a: int, b: int):
        self.dut.ain.value = to_unsigned(a, self.width)
        self.dut.bin.value = to_unsigned(b, self.width)
        self.dut.ibValid.value = 1
        await Timer(1, unit="ns")
        while int(self.dut.ibReady.value) == 0:
            await self.cycle(1)
        await self.cycle(1)
        self.dut.ibValid.value = 0

    async def wait_for_result(self):
        while int(self.dut.obValid.value) == 0:
            await self.cycle(1)

    def observed(self) -> int:
        return truncate_signed(int(self.dut.pOut.value), self.out_width)

    async def wait_for_output_clear(self, timeout_cycles=8):
        for _ in range(timeout_cycles):
            await Timer(1, unit="ns")
            if int(self.dut.obValid.value) == 0:
                return
            await self.cycle(1)
        raise AssertionError("Timed out waiting for DspSquareDiffMult output clear")


@cocotb.test()
async def squared_difference_truth_test(dut):
    tb = TB(dut)
    await tb.reset()

    for a in signed_samples(tb.width):
        for b in signed_samples(tb.width):
            await tb.submit(a, b)
            await tb.wait_for_result()
            diff = a - b
            assert tb.observed() == truncate_signed(diff * diff, tb.out_width)
            await tb.cycle(1)


@cocotb.test()
async def hold_and_reset_test(dut):
    tb = TB(dut)
    await tb.reset()

    tb.dut.obReady.value = 0
    await tb.submit(-4, 3)
    await tb.wait_for_result()
    held = int(dut.pOut.value)
    await tb.cycle(3)
    assert int(dut.obValid.value) == 1
    assert int(dut.pOut.value) == held

    await FallingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.rst.value = tb.reset_active_value()
    await tb.wait_for_output_clear()


@pytest.mark.parametrize(
    "parameters",
    [
        parameter_case(
            "baseline",
            WIDTH_G="5",
            PIPE_STAGES_G="0",
            RST_POLARITY_G="'1'",
            RST_ASYNC_G="false",
        ),
        parameter_case(
            "minimum_width",
            WIDTH_G="2",
            PIPE_STAGES_G="0",
            RST_POLARITY_G="'1'",
            RST_ASYNC_G="false",
        ),
        parameter_case(
            "pipelined_active_low_reset",
            WIDTH_G="6",
            PIPE_STAGES_G="1",
            RST_POLARITY_G="'0'",
            RST_ASYNC_G="true",
        ),
    ],
)
def test_DspSquareDiffMult(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.dspsquarediffmult",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
