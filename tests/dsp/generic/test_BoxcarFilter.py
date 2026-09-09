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
#   outputs, plus an async-reset case so the meaningful storage and reset
#   branches are exercised.
# - Stimulus: Feed a short sample stream through the fixed full-window filter
#   and sample each visible output beat.
# - Checks: The truncated output word, `obFull`, and `obPeriod` pulse must
#   match a Python boxcar reference model derived from the integrator behavior.
# - Timing: The bench waits for each `obValid` pulse instead of assuming a
#   constant latency, so it stays aligned across both `DOB_REG_G` branches.

import os

import cocotb
import pytest
from cocotb.clock import Clock
from cocotb.triggers import Timer

from tests.common.regression_utils import sample_after_tpd

from tests.common.regression_utils import env_flag, hdl_parameters_from, parameter_case, run_surf_vhdl_test
from tests.dsp.generic.dsp_test_utils import boxcar_filter_reference, to_unsigned, truncate_signed


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.data_width = int(os.environ["DATA_WIDTH_G"])
        self.addr_width = int(os.environ["ADDR_WIDTH_G"])
        self.signed = env_flag("SIGNED_G", default=False)
        self.window_size = 1 << self.addr_width

        cocotb.start_soon(Clock(dut.clk, 5.0, unit="ns").start())
        dut.rst.setimmediatevalue(1)
        dut.ibValid.setimmediatevalue(0)
        dut.ibData.setimmediatevalue(0)

    async def cycle(self, count=1):
        for _ in range(count):
            await sample_after_tpd(self.dut.clk)

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
        raise AssertionError("Timed out waiting for BoxcarFilter output")

    def observed(self) -> int:
        return truncate_signed(int(self.dut.obData.value), self.data_width)


@cocotb.test()
async def filter_output_test(dut):
    tb = TB(dut)
    await tb.reset()

    samples = [1, 2, 3, 4, 5, 6] if not tb.signed else [-2, 3, -1, 4, -3, 2]
    refs = boxcar_filter_reference(
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


@cocotb.test()
async def reset_flush_test(dut):
    tb = TB(dut)
    await tb.reset()

    priming_samples = [2, 4, 6] if not tb.signed else [-3, 2, -1]
    for sample in priming_samples:
        await tb.send_sample(sample)
        await tb.wait_for_output()
        await tb.cycle(1)

    tb.dut.rst.value = 1
    if env_flag("RST_ASYNC_G", default=False):
        await Timer(1, unit="ns")
    await tb.cycle(2)
    tb.dut.rst.value = 0
    await tb.cycle(2)

    restart_samples = [1, 3, 5] if not tb.signed else [1, -2, 3]
    refs = boxcar_filter_reference(
        restart_samples,
        window_size=tb.window_size,
        signed=tb.signed,
        data_width=tb.data_width,
        addr_width=tb.addr_width,
    )

    for sample, (expected, full, period) in zip(restart_samples, refs):
        await tb.send_sample(sample)
        await tb.wait_for_output()
        assert tb.observed() == expected
        assert int(dut.obFull.value) == full
        assert int(dut.obPeriod.value) == period
        await tb.cycle(1)


@pytest.mark.parametrize(
    "parameters",
    [
        parameter_case(
            "unsigned_direct_short_window",
            DATA_WIDTH_G="8",
            RST_ASYNC_G="false",
            ADDR_WIDTH_G="1",
            SIGNED_G="false",
            DOB_REG_G="false",
        ),
        parameter_case(
            "signed_registered",
            DATA_WIDTH_G="8",
            RST_ASYNC_G="false",
            ADDR_WIDTH_G="2",
            SIGNED_G="true",
            DOB_REG_G="true",
        ),
        parameter_case(
            "unsigned_async_registered_large_window",
            DATA_WIDTH_G="8",
            RST_ASYNC_G="true",
            ADDR_WIDTH_G="3",
            SIGNED_G="false",
            DOB_REG_G="true",
        ),
    ],
)
def test_BoxcarFilter(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.boxcarfilter",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
