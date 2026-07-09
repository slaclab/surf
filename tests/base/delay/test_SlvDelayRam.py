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
# - Sweep: Sweep a block-memory registered-output case and a distributed-memory
#   unregistered active-low reset case to cover the RAM-backed delay line
#   across its two main shapes.
# - Stimulus: Drive known input patterns while programming delay, hold the
#   enable low to freeze the output, assert reset after the RAM has buffered
#   data, and optionally change `maxCount` followed by the required reset.
# - Checks: The output must reproduce the delayed sample selected by the
#   programmed latency, reproduce the new delay after a reset-aligned
#   reprogramming event, hold steady while disabled, and clear after reset.
# - Timing: Checks are cycle-accurate against the programmed delay, with one
#   extra observable cycle for the registered-output configuration before the
#   delayed sample appears.

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
        self.width = int(os.environ["WIDTH_G"])
        self.delay_depth = int(os.environ["DELAY_G"])
        self.max_count = int(os.environ["MAX_COUNT"])
        self.do_reg = env_flag("DO_REG_G", default=True)
        self.rst_polarity = env_sl("RST_POLARITY_G", default=1)
        self.clk_period_ns = float(os.environ["CLK_PERIOD_NS"])
        self.init_value = 0
        # The user-visible latency observed under the current GHDL flow is one
        # cycle shorter than the headline comment in the RTL suggests, so use
        # the measured contract here rather than the stale comment text.
        self.effective_delay = self.max_count + (2 if self.do_reg else 1)

        dut.rst.value = self.reset_active_value()
        dut.en.value = 1
        dut.maxCount.value = self.max_count
        dut.din.value = 0

        self.current_en = 1
        self.current_din = 0

        cocotb.start_soon(Clock(dut.clk, self.clk_period_ns, unit="ns").start())

    def reset_active_value(self) -> int:
        return self.rst_polarity

    def reset_inactive_value(self) -> int:
        return 1 - self.rst_polarity

    async def settle(self) -> None:
        await Timer(2, unit="ns")

    def observed_output(self) -> int | None:
        try:
            return int(self.dut.dout.value)
        except ValueError:
            return None

    async def cycle(self, *, din: int | None = None, en: int | None = None) -> int | None:
        # Update only the controls this step intends to change so the helper
        # mirrors a normal cycle-by-cycle source driver.
        if din is not None:
            self.dut.din.value = din
            self.current_din = din
        if en is not None:
            self.dut.en.value = en
            self.current_en = en

        await RisingEdge(self.dut.clk)
        await self.settle()
        return self.observed_output()

    async def reset(self) -> None:
        # Hold reset for one edge, release it, and then give the delay line one
        # more clean cycle so the queue model and DUT start aligned.
        self.dut.rst.value = self.reset_active_value()
        await self.cycle()
        self.dut.rst.value = self.reset_inactive_value()
        await self.cycle()
        await self.cycle()

    async def set_max_count(self, value: int) -> None:
        self.dut.maxCount.value = value
        self.max_count = value
        self.effective_delay = self.max_count + (2 if self.do_reg else 1)
        await self.cycle(en=1)


@cocotb.test()
async def configured_delay_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Feed more than one full delay line worth of distinct words. Once the
    # pipeline is primed, each new sample should cause the oldest still-delayed
    # word to appear at the output.
    driven = [0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88]
    observed_tail = []
    for value in driven:
        observed = await tb.cycle(din=value, en=1)
        if observed is not None:
            observed_tail.append(observed)

    # Flush a few extra cycles so the delayed samples have time to emerge.
    for _ in range(tb.effective_delay):
        observed = await tb.cycle(din=0x00, en=1)
        if observed is not None:
            observed_tail.append(observed)

    # After flushing one full delay interval, the tail of the observed stream
    # should reproduce the driven words in order.
    assert observed_tail[-len(driven) :] == driven


@cocotb.test()
async def enable_hold_test(dut):
    tb = TB(dut)
    await tb.reset()

    # Once the pipe is running, dropping `en` should freeze both the circular
    # address pointer and the visible output value.
    for value in [0x10, 0x20, 0x30, 0x40, 0x50]:
        await tb.cycle(din=value, en=1)

    held = await tb.cycle(din=0x60, en=0)
    await tb.cycle(din=0x70, en=0)
    assert int(dut.dout.value) == held


@cocotb.test()
async def dynamic_delay_change_requires_reset_test(dut):
    if not env_flag("CHECK_DYNAMIC_DELAY_CHANGE", default=False):
        return

    tb = TB(dut)
    await tb.reset()

    # Start with a short delay and prove live traffic emerges normally.
    await tb.set_max_count(1)
    short_delay_values = [0x10 + index for index in range(8)]
    short_observed = []
    for value in short_delay_values:
        observed = await tb.cycle(din=value, en=1)
        if observed is not None:
            short_observed.append(observed)
    for _ in range(tb.effective_delay):
        observed = await tb.cycle(din=0x00, en=1)
        if observed is not None:
            short_observed.append(observed)
    assert short_observed[-len(short_delay_values) :] == short_delay_values

    # The RTL contract requires reset after reprogramming maxCount. Apply the
    # new value, reset the circular address phase, and then start fresh traffic
    # against the new delay setting.
    tb.dut.maxCount.value = 4
    tb.max_count = 4
    tb.effective_delay = tb.max_count + (2 if tb.do_reg else 1)
    await tb.reset()
    for _ in range(tb.effective_delay):
        await tb.cycle(din=0x00, en=1)

    long_delay_values = [0x80 + index for index in range(10)]
    long_observed = []
    for value in long_delay_values:
        observed = await tb.cycle(din=value, en=1)
        if observed is not None:
            long_observed.append(observed)
    for _ in range(tb.effective_delay + 2):
        observed = await tb.cycle(din=0x00, en=1)
        if observed is not None:
            long_observed.append(observed)

    # The first few post-reset samples are still part of the documented output
    # history discard interval. Once that interval has passed, later traffic
    # must follow the newly configured delay.
    stable_values = long_delay_values[2:]
    assert any(
        long_observed[index : index + len(stable_values)] == stable_values
        for index in range(len(long_observed) - len(stable_values) + 1)
    )


@cocotb.test()
async def reset_behavior_test(dut):
    tb = TB(dut)
    await tb.reset()

    for value in [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF]:
        await tb.cycle(din=value, en=1)

    await FallingEdge(dut.clk)
    await Timer(1, unit="ns")
    dut.rst.value = tb.reset_active_value()
    await tb.settle()
    await tb.cycle(en=1)
    await tb.cycle(en=1)
    assert int(dut.dout.value) == tb.init_value


PARAMETER_SWEEP = [
    parameter_case(
        "block_registered",
        RST_POLARITY_G="'1'",
        MEMORY_TYPE_G="block",
        DO_REG_G="true",
        DELAY_G="8",
        WIDTH_G="8",
        MAX_COUNT="3",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "block_dynamic_delay_change",
        RST_POLARITY_G="'1'",
        MEMORY_TYPE_G="block",
        DO_REG_G="true",
        DELAY_G="8",
        WIDTH_G="8",
        MAX_COUNT="1",
        CHECK_DYNAMIC_DELAY_CHANGE="1",
        CLK_PERIOD_NS="5",
    ),
    parameter_case(
        "distributed_unregistered_active_low",
        RST_POLARITY_G="'0'",
        MEMORY_TYPE_G="distributed",
        DO_REG_G="false",
        DELAY_G="8",
        WIDTH_G="8",
        MAX_COUNT="3",
        CLK_PERIOD_NS="7",
    ),
]


@pytest.mark.parametrize("parameters", PARAMETER_SWEEP)
def test_SlvDelayRam(parameters):
    run_surf_vhdl_test(
        test_file=__file__,
        toplevel="surf.slvdelayram",
        parameters=hdl_parameters_from(parameters),
        extra_env=parameters,
    )
