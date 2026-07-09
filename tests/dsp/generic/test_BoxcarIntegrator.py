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
# - Sweep: Cover unsigned and signed arithmetic, direct and registered RAM
#   outputs, plus an async-reset single-sample window case.
# - Stimulus: Feed one sample at a time with a configurable integration length,
#   then hold `obAck` low on one visible result and finally reprogram
#   `intCount` to force the accumulator state to restart.
# - Checks: Each visible output word, `obFull`, and `obPeriod` pulse must match
#   a Python rolling-sum model, stalled output data must hold stable, and an
#   `intCount` change must flush prior accumulator state.
# - Timing: The bench waits for `obValid` after each accepted sample so the
#   model stays aligned across both the direct and registered RAM-output paths.

import os

import cocotb
import pytest
from cocotb.clock import Clock

from tests.common.regression_utils import env_flag, hdl_parameters_from, parameter_case, run_surf_vhdl_test
from tests.dsp.generic.dsp_test_utils import boxcar_reference, tick, to_unsigned, truncate_signed


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.data_width = int(os.environ["DATA_WIDTH_G"])
        self.addr_width = int(os.environ["ADDR_WIDTH_G"])
        self.signed = env_flag("SIGNED_G", default=False)
        self.window_size = int(os.environ["INT_COUNT_INIT"]) + 1

        cocotb.start_soon(Clock(dut.clk, 5.0, unit="ns").start())
        dut.rst.setimmediatevalue(1)
        dut.intCount.setimmediatevalue(int(os.environ["INT_COUNT_INIT"]))
        dut.ibValid.setimmediatevalue(0)
        dut.ibData.setimmediatevalue(0)
        dut.obAck.setimmediatevalue(1)

    async def cycle(self, count=1):
        await tick(self.dut.clk, count=count)

    async def reset(self):
        self.dut.rst.value = 1
        await self.cycle(3)
        self.dut.rst.value = 0
        await self.cycle(2)

    async def send_sample(self, sample: int):
        self.dut.ibData.value = to_unsigned(sample, self.data_width)
        self.dut.ibValid.value = 1
        await self.cycle(1)
        self.dut.ibValid.value = 0

    async def wait_for_output(self):
        for _ in range(12):
            if int(self.dut.obValid.value):
                return
            await self.cycle(1)
        raise AssertionError("Timed out waiting for BoxcarIntegrator output")

    def observed(self) -> int:
        return truncate_signed(int(self.dut.obData.value), self.data_width + self.addr_width)


@cocotb.test()
async def rolling_sum_and_reconfig_test(dut):
    tb = TB(dut)
    await tb.reset()

    samples = [1, 2, 3, 4, 5, 6] if not tb.signed else [-2, 3, -1, 4, -3, 2]
    refs = boxcar_reference(
        samples,
        window_size=tb.window_size,
        signed=tb.signed,
        data_width=tb.data_width,
        addr_width=tb.addr_width,
    )

    for sample, (expected, full, period) in zip(samples, refs):
        await tb.send_sample(sample)
        await tb.wait_for_output()
        assert tb.observed() == expected
        assert int(dut.obFull.value) == full
        assert int(dut.obPeriod.value) == period
        await tb.cycle(1)

    # Change `intCount` mid-run and then reset the software-side model so the
    # next visible sums prove the DUT flushed the earlier history.
    tb.dut.intCount.value = 1
    await tb.cycle(2)
    reconfig_samples = samples[:2]
    reconfig_refs = boxcar_reference(
        reconfig_samples,
        window_size=2,
        signed=tb.signed,
        data_width=tb.data_width,
        addr_width=tb.addr_width,
    )

    await tb.send_sample(reconfig_samples[0])
    await tb.wait_for_output()
    if env_flag("DOB_REG_G", default=False):
        # The registered RAM-output path restarts with one empty accumulator
        # beat, then reports the first full-window sum from the new history.
        assert tb.observed() == 0
        assert int(dut.obFull.value) == 1
        assert int(dut.obPeriod.value) == 0

        await tb.cycle(1)
        await tb.send_sample(reconfig_samples[1])
        await tb.wait_for_output()
        assert tb.observed() == reconfig_refs[1][0]
        assert int(dut.obFull.value) == reconfig_refs[1][1]
        assert int(dut.obPeriod.value) == reconfig_refs[1][2]
    else:
        assert tb.observed() == reconfig_refs[0][0]
        assert int(dut.obFull.value) == reconfig_refs[0][1]
        assert int(dut.obPeriod.value) == reconfig_refs[0][2]


@cocotb.test()
async def output_hold_test(dut):
    tb = TB(dut)
    await tb.reset()

    tb.dut.obAck.value = 0
    await tb.send_sample(1 if not tb.signed else -1)
    await tb.wait_for_output()
    held = (int(dut.obValid.value), int(dut.obFull.value), int(dut.obPeriod.value), int(dut.obData.value))
    await tb.cycle(3)
    assert held == (int(dut.obValid.value), int(dut.obFull.value), int(dut.obPeriod.value), int(dut.obData.value))


@cocotb.test()
async def reset_flush_test(dut):
    tb = TB(dut)
    await tb.reset()

    for sample in ([2, 4, 6] if not tb.signed else [-2, 3, -1]):
        await tb.send_sample(sample)
        await tb.wait_for_output()
        await tb.cycle(1)

    tb.dut.rst.value = 1
    if env_flag("RST_ASYNC_G", default=False):
        await tb.cycle(1)
    else:
        await tb.cycle(2)
    tb.dut.rst.value = 0
    await tb.cycle(2)

    restart_sample = 1 if not tb.signed else -1
    await tb.send_sample(restart_sample)
    await tb.wait_for_output()
    expected, full, period = boxcar_reference(
        [restart_sample],
        window_size=tb.window_size,
        signed=tb.signed,
        data_width=tb.data_width,
        addr_width=tb.addr_width,
    )[0]
    assert tb.observed() == expected
    assert int(dut.obFull.value) == full
    assert int(dut.obPeriod.value) == period


@pytest.mark.parametrize(
    "parameters",
    [
        parameter_case(
            "unsigned_direct",
            DATA_WIDTH_G="8",
            RST_ASYNC_G="false",
            ADDR_WIDTH_G="3",
            SIGNED_G="false",
            DOB_REG_G="false",
            INT_COUNT_INIT="3",
        ),
        parameter_case(
            "signed_registered",
            DATA_WIDTH_G="8",
            RST_ASYNC_G="false",
            ADDR_WIDTH_G="2",
            SIGNED_G="true",
            DOB_REG_G="true",
            INT_COUNT_INIT="1",
        ),
        parameter_case(
            "unsigned_async_direct",
            DATA_WIDTH_G="8",
            RST_ASYNC_G="true",
            ADDR_WIDTH_G="2",
            SIGNED_G="false",
            DOB_REG_G="false",
            INT_COUNT_INIT="2",
        ),
    ],
)
def test_BoxcarIntegrator(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.boxcarintegrator",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
        extra_vhdl_sources={"surf": ["dsp/generic/fixed/BoxcarIntegrator.vhd"]},
    )
