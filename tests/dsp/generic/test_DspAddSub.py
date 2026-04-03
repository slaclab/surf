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
# - Sweep: Cover a narrow direct-output configuration and a wider pipelined
#   active-low reset configuration so both output paths and reset styles are
#   exercised.
# - Stimulus: Drive signed input pairs through both add and subtract
#   operations, then hold the sink unready so one computed result must remain
#   parked on the output interface.
# - Checks: The emitted result must match the width-truncated signed
#   arithmetic model, stall cycles must not corrupt the held output word, and
#   reset must clear any pending result.
# - Timing: The bench waits on the DUT handshake rather than assuming a fixed
#   latency, then proves that a visible result remains stable for every cycle
#   that `obReady` stays low.

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


def _signed_samples(width: int) -> list[int]:
    minimum = -(1 << (width - 1))
    maximum = (1 << (width - 1)) - 1
    candidates = {
        minimum,
        minimum + 1,
        -3,
        -2,
        -1,
        0,
        1,
        2,
        3,
        maximum - 1,
        maximum,
    }
    return sorted(value for value in candidates if minimum <= value <= maximum)


def _to_unsigned(value: int, width: int) -> int:
    return value & ((1 << width) - 1)


def _truncate_signed(value: int, width: int) -> int:
    mask = (1 << width) - 1
    wrapped = value & mask
    sign_bit = 1 << (width - 1)
    if wrapped & sign_bit:
        return wrapped - (1 << width)
    return wrapped


class TB:
    def __init__(self, dut):
        self.dut = dut
        self.width = int(os.environ["WIDTH_G"])
        self.async_reset = env_flag("RST_ASYNC_G", default=False)
        self.rst_polarity = env_sl("RST_POLARITY_G", default=1)
        self.clk_period_ns = float(os.environ["CLK_PERIOD_NS"])

        dut.rst.value = self.reset_active_value()
        dut.ibValid.value = 0
        dut.ain.value = 0
        dut.bin.value = 0
        dut.add.value = 1
        dut.obReady.value = 1

        # Start the shared arithmetic clock before any requests so the helper
        # methods can talk in whole accepted transactions.
        cocotb.start_soon(Clock(dut.clk, self.clk_period_ns, unit="ns").start())

    def reset_active_value(self) -> int:
        return self.rst_polarity

    def reset_inactive_value(self) -> int:
        return 1 - self.rst_polarity

    async def settle(self) -> None:
        await Timer(2, unit="ns")

    async def cycle(self, count: int = 1) -> None:
        for _ in range(count):
            await RisingEdge(self.dut.clk)
            await self.settle()

    async def reset(self) -> None:
        # Hold reset long enough for the input register and optional output
        # pipeline stage to return to a known idle state.
        self.dut.rst.value = self.reset_active_value()
        if self.async_reset:
            await Timer(2, unit="ns")
        await self.cycle(3)
        self.dut.rst.value = self.reset_inactive_value()
        await self.cycle(2)

    async def submit(self, ain: int, bin_value: int, *, add_mode: bool) -> None:
        # Present one signed arithmetic request for exactly one accepted clock.
        self.dut.ain.value = _to_unsigned(ain, self.width)
        self.dut.bin.value = _to_unsigned(bin_value, self.width)
        self.dut.add.value = int(add_mode)
        self.dut.ibValid.value = 1
        await self.settle()

        while int(self.dut.ibReady.value) == 0:
            await self.cycle(1)

        await self.cycle(1)
        self.dut.ibValid.value = 0

    async def wait_for_result(self) -> None:
        while int(self.dut.obValid.value) == 0:
            await self.cycle(1)

    def observed_result(self) -> int:
        return _truncate_signed(int(self.dut.pOut.value), self.width)


@cocotb.test()
async def signed_arithmetic_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Sweep representative negative, zero, and positive values so the test
    # proves the DUT is operating on signed math rather than unsigned vectors.
    for add_mode in (True, False):
        for ain in _signed_samples(tb.width):
            for bin_value in _signed_samples(tb.width):
                await tb.submit(ain, bin_value, add_mode=add_mode)
                await tb.wait_for_result()
                expected = _truncate_signed(ain + bin_value if add_mode else ain - bin_value, tb.width)
                assert tb.observed_result() == expected
                await tb.cycle(1)


@cocotb.test()
async def backpressure_hold_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Hold the downstream side unready so one completed arithmetic result has
    # to remain parked on the output interface.
    tb.dut.obReady.value = 0
    await tb.submit(3, -2, add_mode=False)
    await tb.wait_for_result()

    held_word = int(dut.pOut.value)

    # While the result is stalled, the output word and valid flag must stay
    # stable instead of dropping back to an idle-looking value.
    await tb.cycle(3)
    assert int(dut.obValid.value) == 1
    assert int(dut.pOut.value) == held_word
    assert tb.observed_result() == _truncate_signed(3 - (-2), tb.width)

    tb.dut.obReady.value = 1
    await tb.cycle(1)
    assert int(dut.obValid.value) == 0


@cocotb.test()
async def reset_behavior_test(dut):
    tb = TB(dut)
    await tb.reset()

    tb.dut.obReady.value = 0
    await tb.submit(-4, 1, add_mode=True)
    await tb.wait_for_result()

    # Assert reset while a result is pending so the test proves reset clears
    # active pipeline state, not just idle registers.
    await FallingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.rst.value = tb.reset_active_value()
    await tb.settle()

    if tb.async_reset:
        assert int(dut.obValid.value) == 0
    else:
        await tb.cycle(1)
        assert int(dut.obValid.value) == 0


PARAMETER_SWEEP = [
    parameter_case(
        "baseline",
        RST_POLARITY_G="'1'",
        RST_ASYNC_G="false",
        PIPE_STAGES_G="0",
        WIDTH_G="4",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "pipelined_active_low_reset",
        RST_POLARITY_G="'0'",
        RST_ASYNC_G="true",
        PIPE_STAGES_G="1",
        WIDTH_G="8",
        CLK_PERIOD_NS="7",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_DspAddSub(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.dspaddsub",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
